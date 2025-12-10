import { v4 as uuidv4 } from 'uuid';
import { createHash } from 'crypto';
import { getItem, queryItems, putItem, updateItem, TableNames } from '../lib/dynamo';
import { User, Nugget, UserFeedSubscription, FetchedArticle, CustomDigest, FeedItem } from '../lib/models';
import { getLatestItems } from '../lib/rssParser';
import { computePriorityScore } from '../lib/priority';
import { getEffectiveTier, getMaxRSSFeeds } from '../lib/subscription';
import { scrapeUrl } from '../lib/scraper';
import { summariseContent, summariseGroupedContent } from '../lib/llm';
import { sendNuggetsReadyNotification } from '../lib/notifications';

interface AutoFetchEvent {
  userId: string;
  digestsOnly?: boolean; // If true, only process custom digests (skip RSS feed subscriptions)
}

/**
 * Generate a unique article ID from guid or URL
 */
function generateArticleId(item: FeedItem): string {
  if (item.guid) {
    return createHash('sha256').update(item.guid).digest('hex').substring(0, 32);
  }
  return createHash('sha256').update(item.link).digest('hex').substring(0, 32);
}

/**
 * Check if an article has already been fetched (deduplication)
 */
async function isArticleAlreadyFetched(userId: string, articleId: string): Promise<boolean> {
  const existing = await getItem<FetchedArticle>(TableNames.fetchedArticles, {
    userId,
    articleId,
  });
  return existing !== null;
}

/**
 * Record a fetched article for deduplication
 */
async function recordFetchedArticle(
  userId: string,
  articleId: string,
  rssFeedId: string,
  sourceUrl: string,
  guid: string | undefined,
  nuggetId?: string
): Promise<void> {
  const now = Math.floor(Date.now() / 1000);
  const ttl = now + (30 * 24 * 60 * 60); // 30 days TTL

  const record: FetchedArticle = {
    userId,
    articleId,
    rssFeedId,
    sourceUrl,
    guid,
    fetchedAt: now,
    nuggetId,
    ttl,
  };

  await putItem(TableNames.fetchedArticles, record);
}

/**
 * Auto-fetch RSS feeds for a user
 * Creates individual nuggets for each article (with processingState: 'scraped')
 * These will be grouped and AI-processed when the user starts a session or taps "Process"
 * Invoked by EventBridge Scheduler alongside auto-processing
 */
export async function handler(event: AutoFetchEvent): Promise<void> {
  try {
    console.log('Auto-fetch feeds event:', JSON.stringify(event, null, 2));

    const userId = event.userId;

    if (!userId) {
      console.error('No userId provided in event');
      return;
    }

    console.log(`Auto-fetching feeds for user: ${userId}`);

    // Get user and verify subscription
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      console.error(`User not found: ${userId}`);
      return;
    }

    // Check subscription tier
    const effectiveTier = getEffectiveTier(user);
    if (effectiveTier === 'free') {
      console.log(`User ${userId} does not have a paid subscription for RSS feeds`);
      return;
    }

    // Get user's active feed subscriptions
    const subscriptions = await queryItems<UserFeedSubscription>({
      TableName: TableNames.feeds,
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId,
      },
    });

    const activeSubscriptions = subscriptions.filter(sub => sub.isActive);

    if (activeSubscriptions.length === 0) {
      console.log(`No active feed subscriptions for user ${userId}`);
      return;
    }

    // Apply tier-based feed limit
    const maxFeeds = getMaxRSSFeeds(user);
    const limitedSubscriptions = activeSubscriptions.slice(0, maxFeeds);

    console.log(`Processing ${limitedSubscriptions.length} feeds for user ${userId} (tier: ${effectiveTier}, max: ${maxFeeds})`);

    const now = Math.floor(Date.now() / 1000);
    const createdNuggets: string[] = [];
    const digestsOnly = event.digestsOnly === true;

    // Process each feed - create individual scraped nuggets per article
    // Skip this if digestsOnly is true (e.g., when user taps "Run Digests Now")
    if (!digestsOnly) {
      for (const subscription of limitedSubscriptions) {
      try {
        console.log(`Fetching feed: ${subscription.feedName}`);

        // Get latest items from the feed
        const feedItems = await getLatestItems(
          subscription.feedUrl,
          subscription.rssFeedId,
          subscription.feedName,
          10 // Get top 10 items
        );

        if (feedItems.length === 0) {
          console.log(`No items found in feed: ${subscription.feedName}`);
          continue;
        }

        // Filter out already-fetched articles (deduplication)
        const newItems: FeedItem[] = [];
        for (const item of feedItems) {
          const articleId = generateArticleId(item);
          const alreadyFetched = await isArticleAlreadyFetched(userId, articleId);
          if (!alreadyFetched) {
            newItems.push(item);
          }
        }

        if (newItems.length === 0) {
          console.log(`No new items in feed: ${subscription.feedName} (all ${feedItems.length} items already fetched)`);
          continue;
        }

        console.log(`Found ${newItems.length} new items in ${subscription.feedName} (${feedItems.length - newItems.length} duplicates filtered)`);

        // Create individual nuggets for each article (like manual URL adding)
        // They will be grouped and AI-processed when user starts session or taps "Process"
        for (const item of newItems) {
          try {
            const nuggetId = uuidv4();
            const articleId = generateArticleId(item);

            // Try to scrape full content from the article URL
            let scrapedContent = null;
            try {
              scrapedContent = await scrapeUrl(item.link);
              console.log(`Scraped content from: ${item.link}`);
            } catch (scrapeError) {
              console.log(`Failed to scrape ${item.link}, using RSS content`);
            }

            // Create nugget with scraped state (will be AI processed when user starts session)
            const nugget: Nugget = {
              userId,
              nuggetId,
              sourceUrl: item.link,
              sourceType: 'url',
              rawTitle: scrapedContent?.title || item.title,
              rawText: scrapedContent?.content || item.contentSnippet || item.content || '',
              rawDescription: scrapedContent?.description || item.contentSnippet,
              status: 'inbox',
              processingState: 'scraped', // Will be grouped and AI processed when user starts session
              category: scrapedContent?.suggestedCategory || subscription.category,
              priorityScore: computePriorityScore(now, 0),
              createdAt: now,
              timesReviewed: 0,
            };

            await putItem(TableNames.nuggets, nugget);
            createdNuggets.push(nuggetId);

            // Record for deduplication
            await recordFetchedArticle(
              userId,
              articleId,
              subscription.rssFeedId,
              item.link,
              item.guid,
              nuggetId
            );

            console.log(`Created nugget for "${item.title}" (${nuggetId})`);
          } catch (itemError) {
            console.error(`Error creating nugget for ${item.link}:`, itemError);
            // Continue with other items
          }
        }

        // Update the subscription's lastFetchedAt
        await updateItem(
          TableNames.feeds,
          { userId, feedId: subscription.feedId },
          { lastFetchedAt: now }
        );

        console.log(`Created ${newItems.length} individual nuggets from ${subscription.feedName}`);
      } catch (error) {
        console.error(`Error fetching feed ${subscription.feedName}:`, error);
        // Continue with other feeds
      }
      }
    } else {
      console.log('Skipping RSS feed processing (digestsOnly mode)');
    }

    // For Ultimate users, process custom digests
    // This runs whether digestsOnly is true or false
    if (effectiveTier === 'ultimate') {
      const digestNuggets = await processCustomDigests(userId, limitedSubscriptions, now);
      createdNuggets.push(...digestNuggets);
    }

    console.log(`Auto-fetch complete. Created ${createdNuggets.length} nuggets for user ${userId}`);

    // Send push notification if nuggets were created
    if (createdNuggets.length > 0) {
      try {
        if (user.settings?.notificationsEnabled !== false) {
          await sendNuggetsReadyNotification(userId, createdNuggets.length);
          console.log(`Sent push notification to user ${userId} for ${createdNuggets.length} nuggets`);
        }
      } catch (notifError) {
        console.error('Failed to send push notification:', notifError);
        // Don't fail the whole operation for notification failure
      }
    }

  } catch (error) {
    console.error('Error in autoFetchFeeds handler:', error);
    throw error;
  }
}

/**
 * Process custom digests for Ultimate users
 * Immediately creates ready grouped Nuggets with individualSummaries
 * These skip the feed entirely - go straight to ready Nuggets
 * Returns array of created nugget IDs
 */
async function processCustomDigests(
  userId: string,
  subscriptions: UserFeedSubscription[],
  now: number
): Promise<string[]> {
  const createdNuggets: string[] = [];

  try {
    // Get user's custom digests
    const digests = await queryItems<CustomDigest>({
      TableName: TableNames.customDigests,
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId,
      },
    });

    const activeDigests = digests.filter(d => d.isEnabled);

    if (activeDigests.length === 0) {
      console.log('No active custom digests');
      return createdNuggets;
    }

    console.log(`Processing ${activeDigests.length} custom digests`);

    for (const digest of activeDigests) {
      try {
        // Get subscriptions for this digest's feeds
        const digestFeeds = subscriptions.filter(sub =>
          digest.feedIds.includes(sub.rssFeedId)
        );

        if (digestFeeds.length === 0) {
          console.log(`No matching feeds for digest: ${digest.name}`);
          continue;
        }

        // Collect new items from all digest feeds, keeping them separate per feed
        const articlesPerDigest = digest.articlesPerDigest || 5;
        const itemsPerFeed: Map<string, Array<FeedItem & { feedName: string; category: string }>> = new Map();

        for (const feed of digestFeeds) {
          try {
            const feedItems = await getLatestItems(
              feed.feedUrl,
              feed.rssFeedId,
              feed.feedName,
              articlesPerDigest // Get enough items from each feed
            );

            // Filter duplicates and collect per feed
            const feedNewItems: Array<FeedItem & { feedName: string; category: string }> = [];
            for (const item of feedItems) {
              const articleId = generateArticleId(item);
              const alreadyFetched = await isArticleAlreadyFetched(userId, articleId);
              if (!alreadyFetched) {
                feedNewItems.push({ ...item, feedName: feed.feedName, category: feed.category });
              }
            }

            if (feedNewItems.length > 0) {
              itemsPerFeed.set(feed.feedName, feedNewItems);
              console.log(`Found ${feedNewItems.length} new items from ${feed.feedName}`);
            }
          } catch (err) {
            console.error(`Error fetching feed ${feed.feedName} for digest:`, err);
          }
        }

        if (itemsPerFeed.size === 0) {
          console.log(`No new items for digest: ${digest.name}`);
          continue;
        }

        // Interleave articles from all feeds to ensure a balanced mix
        // Round-robin: take one from each feed until we have enough
        const itemsToProcess: Array<FeedItem & { feedName: string; category: string }> = [];
        const feedNames = Array.from(itemsPerFeed.keys());
        const feedIndices: Map<string, number> = new Map();
        feedNames.forEach(name => feedIndices.set(name, 0));

        let feedIndex = 0;
        while (itemsToProcess.length < articlesPerDigest) {
          const feedName = feedNames[feedIndex % feedNames.length];
          const feedItems = itemsPerFeed.get(feedName) || [];
          const itemIndex = feedIndices.get(feedName) || 0;

          if (itemIndex < feedItems.length) {
            itemsToProcess.push(feedItems[itemIndex]);
            feedIndices.set(feedName, itemIndex + 1);
          }

          feedIndex++;

          // Break if we've gone through all feeds and none have more items
          if (feedIndex >= feedNames.length * articlesPerDigest) {
            break;
          }
        }

        console.log(`Selected ${itemsToProcess.length} articles for digest "${digest.name}" from ${feedNames.length} feeds (balanced mix)`);

        console.log(`Processing ${itemsToProcess.length} articles for digest "${digest.name}" - creating ready Nugget`);

        // Scrape and prepare article content for AI processing
        const articleContents: Array<{
          title: string;
          text: string;
          url: string;
          item: FeedItem & { feedName: string; category: string };
        }> = [];

        for (const item of itemsToProcess) {
          try {
            // Try to scrape full content
            let scrapedContent = null;
            try {
              scrapedContent = await scrapeUrl(item.link);
              console.log(`Scraped content from: ${item.link}`);
            } catch (scrapeError) {
              console.log(`Failed to scrape ${item.link}, using RSS content`);
            }

            articleContents.push({
              title: scrapedContent?.title || item.title,
              text: scrapedContent?.content || item.contentSnippet || item.content || '',
              url: item.link,
              item,
            });

            // Record for deduplication (before creating nugget)
            const articleId = generateArticleId(item);
            await recordFetchedArticle(
              userId,
              articleId,
              'digest-' + digest.digestId,
              item.link,
              item.guid
            );
          } catch (err) {
            console.error(`Error preparing article ${item.link}:`, err);
          }
        }

        if (articleContents.length === 0) {
          console.log(`No articles could be prepared for digest: ${digest.name}`);
          continue;
        }

        // Step 1: Summarize each article individually to build individualSummaries
        console.log(`AI summarizing ${articleContents.length} individual articles for digest "${digest.name}"...`);
        const individualSummaries: Array<{
          nuggetId: string;
          title: string;
          summary: string;
          keyPoints: string[];
          sourceUrl: string;
        }> = [];

        for (const article of articleContents) {
          try {
            const result = await summariseContent(article.title, article.text, article.url);
            individualSummaries.push({
              nuggetId: uuidv4(), // Virtual ID for the individual article
              title: result.title,
              summary: result.summary,
              keyPoints: result.keyPoints,
              sourceUrl: article.url,
            });
            console.log(`Summarized article: "${result.title}"`);
          } catch (err) {
            console.error(`Error summarizing article ${article.url}:`, err);
            // Add fallback summary
            individualSummaries.push({
              nuggetId: uuidv4(),
              title: article.title || 'Untitled',
              summary: article.text?.substring(0, 200) || 'No summary available',
              keyPoints: ['Review this article'],
              sourceUrl: article.url,
            });
          }
        }

        // Step 2: Create synthesized overview summary from all articles
        console.log(`Creating synthesized overview for digest "${digest.name}"...`);
        const overviewResult = await summariseGroupedContent(
          articleContents.map(a => ({ title: a.title, text: a.text, url: a.url }))
        );

        // Step 3: Create the ready grouped Nugget
        const nuggetId = `digest-${uuidv4()}`;
        const nugget: Nugget = {
          userId,
          nuggetId,
          sourceUrl: articleContents[0].url,
          sourceUrls: articleContents.map(a => a.url),
          sourceType: 'other',
          rawTitle: overviewResult.title,
          title: `${digest.name}`,
          summary: overviewResult.summary,
          keyPoints: overviewResult.keyPoints,
          question: overviewResult.question,
          status: 'inbox',
          processingState: 'ready', // Ready to view immediately
          category: 'digest',
          priorityScore: computePriorityScore(now, 0),
          createdAt: now,
          timesReviewed: 0,
          isGrouped: true,
          sourceNuggetIds: individualSummaries.map(s => s.nuggetId),
          individualSummaries,
        };

        await putItem(TableNames.nuggets, nugget);
        createdNuggets.push(nuggetId);

        // Update digest's lastGeneratedAt
        await updateItem(
          TableNames.customDigests,
          { userId, digestId: digest.digestId },
          { lastGeneratedAt: now, updatedAt: now }
        );

        console.log(`Created ready Nugget "${digest.name}" (${nuggetId}) with ${individualSummaries.length} articles`);
      } catch (error) {
        console.error(`Error processing digest ${digest.name}:`, error);
      }
    }
  } catch (error) {
    console.error('Error processing custom digests:', error);
  }

  return createdNuggets;
}

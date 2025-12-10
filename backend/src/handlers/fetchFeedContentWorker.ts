import { v4 as uuidv4 } from 'uuid';
import { query, putItem, updateItem, TableNames } from '../lib/dynamo';
import { UserFeedSubscription, Nugget } from '../lib/models';
import { getLatestItems } from '../lib/rssParser';
import { computePriorityScore } from '../lib/priority';
import { scrapeUrl } from '../lib/scraper';
import { summarizeFeedWithArticles } from '../lib/llm';

/**
 * Decode HTML entities in a string
 */
function decodeHtmlEntities(str: string | undefined): string {
  if (!str) return '';
  return str
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/&mdash;/g, '—')
    .replace(/&ndash;/g, '–')
    .replace(/&hellip;/g, '…')
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code, 10)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, code) => String.fromCharCode(parseInt(code, 16)));
}

/**
 * Clean and normalize a URL
 */
function cleanUrl(url: string | undefined): string {
  if (!url) return '';
  return url.replace(/&amp;/g, '&').replace(/&#38;/g, '&').trim();
}

interface WorkerEvent {
  userId: string;
  feedId?: string;
  limit?: number;
}

/**
 * Get time of day suffix (Morning, Afternoon, Evening)
 */
function getTimeOfDay(): string {
  const hour = new Date().getUTCHours();
  // Adjust for typical user timezone (assume ~UTC for now, can be user-specific later)
  if (hour >= 5 && hour < 12) return 'Morning';
  if (hour >= 12 && hour < 17) return 'Afternoon';
  return 'Evening';
}

/**
 * Get start of today in Unix timestamp
 */
function getStartOfToday(): number {
  const now = new Date();
  now.setUTCHours(0, 0, 0, 0);
  return now.getTime() / 1000;
}

/**
 * Count existing digests for this feed today with same time-of-day
 */
async function countTodaysDigests(userId: string, feedName: string, timeOfDay: string): Promise<number> {
  const startOfToday = getStartOfToday();

  // Query all user's nuggets that are digests created today
  const nuggets = await query<Nugget>(
    TableNames.nuggets,
    'userId = :userId',
    { ':userId': userId }
  );

  // Filter to digests from this feed, created today, with same time-of-day
  const titlePrefix = `${feedName} ${timeOfDay}`;
  const todaysDigests = nuggets.filter(n =>
    n.isGrouped === true &&
    n.createdAt >= startOfToday &&
    n.title?.startsWith(titlePrefix)
  );

  return todaysDigests.length;
}

/**
 * Worker Lambda for fetching feed content
 * Invoked asynchronously - no HTTP timeout constraints
 */
export async function handler(event: WorkerEvent): Promise<void> {
  const { userId, feedId: specificFeedId, limit = 5 } = event;

  console.log(`Worker starting feed fetch for user ${userId}, feedId: ${specificFeedId || 'all'}, limit: ${limit}`);

  try {
    // Get user's active subscriptions
    let subscriptions = await query<UserFeedSubscription>(
      TableNames.feeds,
      'userId = :userId',
      { ':userId': userId }
    );

    subscriptions = subscriptions.filter(sub => sub.isActive);

    if (specificFeedId) {
      subscriptions = subscriptions.filter(sub => sub.feedId === specificFeedId);
    }

    if (subscriptions.length === 0) {
      console.log('No active subscriptions found');
      return;
    }

    const now = Date.now() / 1000;

    // Fetch content from each subscribed feed
    for (const subscription of subscriptions) {
      try {
        console.log(`Fetching feed: ${subscription.feedName}`);

        // Get latest items from the feed
        const feedItems = await getLatestItems(
          subscription.feedUrl,
          subscription.rssFeedId,
          subscription.feedName,
          limit
        );

        if (feedItems.length === 0) {
          console.log(`No items found in feed: ${subscription.feedName}`);
          continue;
        }

        console.log(`Found ${feedItems.length} items in ${subscription.feedName}`);

        // Scrape full content from each article URL
        console.log(`Scraping ${feedItems.length} articles from ${subscription.feedName}...`);
        const scrapedArticles = [];

        for (const item of feedItems) {
          const cleanedLink = cleanUrl(item.link);
          if (!cleanedLink) continue;

          try {
            const scraped = await scrapeUrl(cleanedLink);
            scrapedArticles.push({
              title: decodeHtmlEntities(scraped.title) || decodeHtmlEntities(item.title),
              link: cleanedLink,
              content: decodeHtmlEntities(scraped.content) || decodeHtmlEntities(item.contentSnippet) || 'No content available',
            });
          } catch (scrapeError) {
            console.warn(`Failed to scrape ${cleanedLink}:`, scrapeError);
            // Fall back to RSS content if scraping fails
            scrapedArticles.push({
              title: decodeHtmlEntities(item.title),
              link: cleanedLink,
              content: decodeHtmlEntities(item.contentSnippet) || decodeHtmlEntities(item.content) || 'No content available',
            });
          }
        }

        if (scrapedArticles.length === 0) {
          console.log(`No articles could be scraped from ${subscription.feedName}`);
          continue;
        }

        console.log(`Successfully scraped ${scrapedArticles.length} articles, sending to AI for summarization...`);

        // Use AI to create summaries for each article + overall digest
        const summarized = await summarizeFeedWithArticles(
          scrapedArticles,
          subscription.feedName
        );

        // Create a nugget from the summarized content
        const nuggetId = uuidv4();

        // Generate title with time-of-day and sequential number if needed
        const timeOfDay = getTimeOfDay();
        const existingCount = await countTodaysDigests(userId, subscription.feedName, timeOfDay);
        const sequentialSuffix = existingCount > 0 ? ` #${existingCount + 1}` : '';
        const digestTitle = `${subscription.feedName} ${timeOfDay}${sequentialSuffix}`;

        // Add nuggetId to each individual summary
        const individualSummaries = summarized.individualSummaries.map((summary, index) => ({
          nuggetId: `${nuggetId}-article-${index}`,
          title: summary.title,
          summary: summary.summary,
          keyPoints: summary.keyPoints,
          sourceUrl: summary.sourceUrl,
        }));

        const nugget: Nugget = {
          userId,
          nuggetId,
          sourceUrl: subscription.feedUrl,
          sourceType: 'rss',  // Mark as RSS content
          rawTitle: summarized.title,
          title: digestTitle,
          rawText: JSON.stringify(scrapedArticles),
          status: 'digest',  // Separate from inbox
          processingState: 'ready',
          category: subscription.category,
          summary: summarized.summary,
          keyPoints: summarized.keyPoints,
          question: summarized.question,
          priorityScore: computePriorityScore(now, 0),
          createdAt: now,
          timesReviewed: 0,
          // Store the individual articles for reference
          isGrouped: true,
          sourceUrls: scrapedArticles.map(a => a.link),
          individualSummaries,
        };

        await putItem(TableNames.nuggets, nugget);

        // Update the subscription's lastFetchedAt
        await updateItem(
          TableNames.feeds,
          { userId, feedId: subscription.feedId },
          { lastFetchedAt: now }
        );

        console.log(`Created digest nugget for ${subscription.feedName}: ${nugget.nuggetId} with ${scrapedArticles.length} articles`);
      } catch (error) {
        console.error(`Error fetching feed ${subscription.feedName}:`, error);
        // Continue with other feeds
      }
    }

    console.log(`Worker completed feed fetch for user ${userId}`);
  } catch (error) {
    console.error('Error in fetchFeedContentWorker:', error);
    throw error;
  }
}

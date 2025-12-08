import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { putItem, getItem, deleteItem, TableNames } from '../lib/dynamo';
import { SubscribeFeedInput, UserFeedSubscription, User, Nugget } from '../lib/models';
import { getFeedById } from '../lib/rssCatalog';
import { getLatestItems } from '../lib/rssParser';
import { scrapeUrl } from '../lib/scraper';

/**
 * POST /v1/feeds/subscribe
 * Subscribe or unsubscribe from an RSS feed
 */
export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    // Extract and verify user
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body is required' }),
      };
    }

    const input: SubscribeFeedInput = JSON.parse(event.body);

    // Validate input
    if (!input.rssFeedId || typeof input.subscribe !== 'boolean') {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'rssFeedId and subscribe are required' }),
      };
    }

    // Get the feed from the catalog
    const feed = getFeedById(input.rssFeedId);
    if (!feed) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'Feed not found in catalog' }),
      };
    }

    // Check if user has a paid subscription for premium feeds
    if (feed.isPremium) {
      const user = await getItem<User>(TableNames.users, { userId });
      const tier = user?.subscriptionTier || user?.preferences?.subscriptionTier;
      if (!user || (tier !== 'pro' && tier !== 'ultimate')) {
        return {
          statusCode: 403,
          body: JSON.stringify({
            error: 'Premium subscription required',
            message: 'This feed requires a Pro subscription. Upgrade to access premium content.'
          }),
        };
      }
    }

    const feedId = `feed_${userId}_${input.rssFeedId}`;

    if (input.subscribe) {
      // Subscribe to the feed
      const now = Date.now() / 1000;

      const subscription: UserFeedSubscription = {
        userId,
        feedId,
        rssFeedId: input.rssFeedId,
        feedName: feed.name,
        feedUrl: feed.url,
        category: feed.category,
        subscribedAt: now,
        isActive: true
      };

      await putItem(TableNames.feeds, subscription);

      // Fetch latest 3 articles and create nuggets for them
      let articlesAdded = 0;
      try {
        console.log(`Fetching latest articles from ${feed.name} (${feed.url})`);
        const latestItems = await getLatestItems(feed.url, input.rssFeedId, feed.name, 3);

        for (const item of latestItems) {
          if (!item.link) continue;

          // Scrape the full article content from the URL
          let scrapedContent;
          try {
            console.log(`Scraping article: ${item.link}`);
            scrapedContent = await scrapeUrl(item.link);
          } catch (scrapeError) {
            console.error(`Failed to scrape ${item.link}:`, scrapeError);
            // Fall back to RSS snippet if scraping fails
            scrapedContent = {
              title: item.title || 'Untitled',
              description: item.contentSnippet,
              content: item.contentSnippet || item.content?.substring(0, 500) || '',
              suggestedCategory: feed.category
            };
          }

          const nuggetId = `ngt_${uuidv4()}`;
          const nugget: Nugget = {
            userId,
            nuggetId,
            sourceUrl: item.link,
            sourceType: 'url',
            rawTitle: scrapedContent.title || item.title,
            rawText: scrapedContent.content,
            rawDescription: scrapedContent.description || item.contentSnippet,
            status: 'inbox',
            processingState: 'scraped',  // Ready to be processed by AI
            category: scrapedContent.suggestedCategory || feed.category,
            priorityScore: 50,
            createdAt: now,
            timesReviewed: 0
          };

          await putItem(TableNames.nuggets, nugget);
          articlesAdded++;
        }

        console.log(`Added ${articlesAdded} articles from ${feed.name} to user's feed`);
      } catch (fetchError) {
        console.error(`Failed to fetch articles from ${feed.name}:`, fetchError);
        // Continue anyway - subscription was successful, just couldn't fetch articles
      }

      return {
        statusCode: 200,
        body: JSON.stringify({
          message: articlesAdded > 0
            ? `Subscribed to ${feed.name} and added ${articlesAdded} articles to your feed`
            : 'Successfully subscribed to feed',
          subscription: {
            feedId: subscription.feedId,
            rssFeedId: subscription.rssFeedId,
            feedName: subscription.feedName,
            category: subscription.category,
            isActive: subscription.isActive,
            subscribedAt: new Date(subscription.subscribedAt * 1000).toISOString()
          },
          articlesAdded
        }),
      };
    } else {
      // Unsubscribe from the feed
      await deleteItem(TableNames.feeds, { userId, feedId });

      return {
        statusCode: 200,
        body: JSON.stringify({
          message: 'Successfully unsubscribed from feed'
        }),
      };
    }
  } catch (error) {
    console.error('Error in subscribeFeed handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { query, putItem, updateItem, TableNames } from '../lib/dynamo';
import { UserFeedSubscription, Nugget } from '../lib/models';
import { getLatestItems, createRecapNugget } from '../lib/rssParser';
import { computePriorityScore } from '../lib/priority';

/**
 * POST /v1/feeds/fetch
 * Fetch latest content from user's subscribed RSS feeds and create recap nuggets
 *
 * Optional query params:
 * - feedId: specific feed to fetch (if not provided, fetches all subscribed feeds)
 * - limit: number of items per feed (default: 10)
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

    const specificFeedId = event.queryStringParameters?.feedId;
    const limit = parseInt(event.queryStringParameters?.limit || '10');

    // Get user's active subscriptions
    let subscriptions = await query<UserFeedSubscription>(
      TableNames.feeds,
      'userId = :userId',
      { ':userId': userId }
    );

    // Filter to active subscriptions only
    subscriptions = subscriptions.filter(sub => sub.isActive);

    // If specific feed requested, filter to that feed
    if (specificFeedId) {
      subscriptions = subscriptions.filter(sub => sub.feedId === specificFeedId);
      if (subscriptions.length === 0) {
        return {
          statusCode: 404,
          body: JSON.stringify({ error: 'Feed subscription not found' }),
        };
      }
    }

    if (subscriptions.length === 0) {
      return {
        statusCode: 200,
        body: JSON.stringify({
          message: 'No active feed subscriptions',
          nuggets: []
        }),
      };
    }

    const createdNuggets = [];
    const errors = [];
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

        // Create a recap nugget from the feed items
        const recap = await createRecapNugget(
          feedItems,
          subscription.rssFeedId,
          subscription.feedName
        );

        // Create a nugget from the recap
        const nuggetId = uuidv4();
        const nugget: Nugget = {
          userId,
          nuggetId,
          sourceUrl: subscription.feedUrl,
          sourceType: 'other',
          rawTitle: recap.summary,
          title: `${subscription.feedName} Recap`,
          rawText: JSON.stringify(recap.articles),
          status: 'inbox',
          processingState: 'ready',
          category: subscription.category,
          summary: recap.summary,
          keyPoints: recap.keyPoints,
          question: `What insights can you gain from today's ${subscription.feedName} stories?`,
          priorityScore: computePriorityScore(now, 0),
          createdAt: now,
          timesReviewed: 0,
          // Store the individual articles for reference
          isGrouped: true,
          sourceUrls: recap.articles.map(a => a.link),
        };

        await putItem(TableNames.nuggets, nugget);

        // Update the subscription's lastFetchedAt
        await updateItem(
          TableNames.feeds,
          { userId, feedId: subscription.feedId },
          { lastFetchedAt: now }
        );

        createdNuggets.push({
          nuggetId: nugget.nuggetId,
          feedName: subscription.feedName,
          articleCount: recap.articles.length,
          title: nugget.title,
          category: nugget.category
        });

        console.log(`Created recap nugget for ${subscription.feedName}: ${nugget.nuggetId}`);
      } catch (error) {
        console.error(`Error fetching feed ${subscription.feedName}:`, error);
        errors.push({
          feedId: subscription.feedId,
          feedName: subscription.feedName,
          error: error instanceof Error ? error.message : 'Unknown error'
        });
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: `Fetched ${createdNuggets.length} feed recap(s)`,
        nuggets: createdNuggets,
        errors: errors.length > 0 ? errors : undefined
      }),
    };
  } catch (error) {
    console.error('Error in fetchFeedContent handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

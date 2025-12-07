import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { putItem, getItem, deleteItem, TableNames } from '../lib/dynamo';
import { SubscribeFeedInput, UserFeedSubscription, User } from '../lib/models';
import { getFeedById } from '../lib/rssCatalog';

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

    // Check if user has premium subscription for premium feeds
    if (feed.isPremium) {
      const user = await getItem<User>(TableNames.users, { userId });
      if (!user || user.preferences?.subscriptionTier !== 'premium') {
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

      return {
        statusCode: 200,
        body: JSON.stringify({
          message: 'Successfully subscribed to feed',
          subscription: {
            feedId: subscription.feedId,
            rssFeedId: subscription.rssFeedId,
            feedName: subscription.feedName,
            category: subscription.category,
            isActive: subscription.isActive,
            subscribedAt: new Date(subscription.subscribedAt * 1000).toISOString()
          }
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

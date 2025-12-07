import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { query, TableNames } from '../lib/dynamo';
import { GetFeedsResponse, UserFeedSubscription } from '../lib/models';
import { getAllFeeds } from '../lib/rssCatalog';

/**
 * GET /v1/feeds
 * Returns the RSS catalog with subscription status for the current user
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

    // Get user's subscriptions
    const subscriptions = await query<UserFeedSubscription>(
      TableNames.feeds,
      'userId = :userId',
      { ':userId': userId }
    );

    // Create a set of subscribed feed IDs for quick lookup
    const subscribedFeedIds = new Set(
      subscriptions
        .filter(sub => sub.isActive)
        .map(sub => sub.rssFeedId)
    );

    // Get the full catalog
    const catalog = getAllFeeds();

    // Map catalog with subscription status
    const catalogWithStatus = catalog.map(feed => ({
      id: feed.id,
      name: feed.name,
      url: feed.url,
      category: feed.category,
      description: feed.description,
      isPremium: feed.isPremium,
      isSubscribed: subscribedFeedIds.has(feed.id)
    }));

    // Format subscription responses
    const subscriptionResponses = subscriptions
      .filter(sub => sub.isActive)
      .map(sub => ({
        feedId: sub.feedId,
        rssFeedId: sub.rssFeedId,
        feedName: sub.feedName,
        category: sub.category,
        isActive: sub.isActive,
        subscribedAt: new Date(sub.subscribedAt * 1000).toISOString()
      }));

    const response: GetFeedsResponse = {
      catalog: catalogWithStatus,
      subscriptions: subscriptionResponses
    };

    return {
      statusCode: 200,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in getFeeds handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

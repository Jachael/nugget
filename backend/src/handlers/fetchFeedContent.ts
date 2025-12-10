import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { extractUserId } from '../lib/auth';
import { query, TableNames } from '../lib/dynamo';
import { UserFeedSubscription } from '../lib/models';

const lambdaClient = new LambdaClient({ region: process.env.AWS_REGION || 'eu-west-1' });

/**
 * POST /v1/feeds/fetch
 * Trigger async feed fetching - returns immediately with 202
 *
 * Optional query params:
 * - feedId: specific feed to fetch (if not provided, fetches all subscribed feeds)
 * - limit: number of items per feed (default: 5)
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
    const limit = parseInt(event.queryStringParameters?.limit || '5');

    // Get user's active subscriptions to validate request
    let subscriptions = await query<UserFeedSubscription>(
      TableNames.feeds,
      'userId = :userId',
      { ':userId': userId }
    );

    subscriptions = subscriptions.filter(sub => sub.isActive);

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

    // Invoke the worker Lambda asynchronously
    const functionName = `nugget-${process.env.STAGE || 'dev'}-fetchFeedContentWorker`;

    await lambdaClient.send(new InvokeCommand({
      FunctionName: functionName,
      InvocationType: 'Event', // Async - returns immediately
      Payload: Buffer.from(JSON.stringify({
        userId,
        feedId: specificFeedId,
        limit,
      })),
    }));

    console.log(`Triggered async feed fetch for user ${userId}, feeds: ${subscriptions.length}`);

    return {
      statusCode: 202,
      body: JSON.stringify({
        message: `Fetching ${subscriptions.length} feed(s). New digests will appear in your inbox shortly.`,
        feedCount: subscriptions.length,
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

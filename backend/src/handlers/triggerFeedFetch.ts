import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, TableNames } from '../lib/dynamo';
import { User } from '../lib/models';
import { getEffectiveTier } from '../lib/subscription';

const lambdaClient = new LambdaClient({ region: process.env.AWS_REGION || 'eu-west-1' });

/**
 * POST /v1/feeds/fetch-all
 * Manually trigger feed fetching including custom digests
 * Uses async Lambda invocation to avoid HTTP timeout
 */
export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    // Get user and verify subscription
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    // Check subscription tier
    const effectiveTier = getEffectiveTier(user);
    if (effectiveTier === 'free') {
      return {
        statusCode: 403,
        body: JSON.stringify({
          error: 'RSS feeds require a Pro or Ultimate subscription',
          upgradeRequired: true,
        }),
      };
    }

    console.log(`Manually triggering feed fetch for user ${userId}`);

    // Invoke autoFetchFeeds Lambda asynchronously (fire-and-forget)
    // Pass digestsOnly: true to skip RSS feed processing and only create digest Nuggets
    const functionName = `nugget-${process.env.STAGE || 'dev'}-autoFetchFeeds`;

    await lambdaClient.send(new InvokeCommand({
      FunctionName: functionName,
      InvocationType: 'Event', // Async invocation - returns immediately
      Payload: Buffer.from(JSON.stringify({ userId, digestsOnly: true })),
    }));

    console.log(`Triggered async feed fetch for user ${userId}`);

    return {
      statusCode: 202, // Accepted - processing started
      body: JSON.stringify({
        message: 'Feed fetch started. New nuggets will appear in your inbox shortly.',
        tier: effectiveTier,
      }),
    };
  } catch (error) {
    console.error('Error in triggerFeedFetch handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

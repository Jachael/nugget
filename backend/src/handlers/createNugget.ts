import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { putItem, TableNames } from '../lib/dynamo';
import { Nugget, CreateNuggetInput, NuggetResponse } from '../lib/models';
import { computePriorityScore } from '../lib/priority';

const lambda = new LambdaClient({ region: process.env.AWS_REGION || 'eu-west-1' });

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    // Extract and verify user
    const userId = extractUserId(event);
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

    const input: CreateNuggetInput = JSON.parse(event.body);

    // Validate input
    if (!input.sourceUrl || !input.sourceType) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'sourceUrl and sourceType are required' }),
      };
    }

    const validSourceTypes = ['url', 'tweet', 'linkedin', 'youtube', 'other'];
    if (!validSourceTypes.includes(input.sourceType)) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Invalid sourceType' }),
      };
    }

    // Create nugget
    const now = Date.now() / 1000;
    const nuggetId = uuidv4();

    const nugget: Nugget = {
      userId,
      nuggetId,
      sourceUrl: input.sourceUrl,
      sourceType: input.sourceType,
      rawTitle: input.rawTitle,
      rawText: input.rawText,
      status: 'inbox',
      category: input.category,
      priorityScore: computePriorityScore(now, 0),
      createdAt: now,
      timesReviewed: 0,
    };

    await putItem(TableNames.nuggets, nugget);

    // Trigger async summarisation
    try {
      const functionName = `nugget-${process.env.STAGE || 'dev'}-summariseNugget`;
      await lambda.send(new InvokeCommand({
        FunctionName: functionName,
        InvocationType: 'Event', // Async invocation
        Payload: Buffer.from(JSON.stringify({ userId, nuggetId })),
      }));
    } catch (error) {
      console.error('Failed to trigger summarisation:', error);
      // Continue anyway - summarisation can be retried manually
    }

    // Return response
    const response: NuggetResponse = {
      nuggetId: nugget.nuggetId,
      sourceUrl: nugget.sourceUrl,
      sourceType: nugget.sourceType,
      title: nugget.rawTitle,
      category: nugget.category,
      status: nugget.status,
      createdAt: new Date(nugget.createdAt * 1000).toISOString(),
      timesReviewed: nugget.timesReviewed,
    };

    return {
      statusCode: 201,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in createNugget handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, queryItems, TableNames } from '../lib/dynamo';
import { User, Nugget } from '../lib/models';

const lambda = new LambdaClient({ region: process.env.AWS_REGION || 'eu-west-1' });

/**
 * Process specific nuggets or all scraped nuggets for a user
 * This triggers AI summarization (costs money, so only on explicit request)
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

    // Get nuggetIds from request (optional - if not provided, process all scraped nuggets)
    let nuggetIds: string[] | undefined;
    if (event.body) {
      const body = JSON.parse(event.body);
      nuggetIds = body.nuggetIds;
    }

    // Get user to check subscription limits
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    let nuggetsToProcess: Nugget[];

    if (nuggetIds && nuggetIds.length > 0) {
      // Process specific nuggets
      const nuggetPromises = nuggetIds.map(nuggetId =>
        getItem<Nugget>(TableNames.nuggets, { userId, nuggetId })
      );
      const results = await Promise.all(nuggetPromises);
      nuggetsToProcess = results.filter((n): n is Nugget => n !== null);
    } else {
      // Process all scraped (unprocessed) nuggets in inbox
      const allNuggets = await queryItems<Nugget>({
        TableName: TableNames.nuggets,
        IndexName: 'UserStatusIndex',
        KeyConditionExpression: 'userId = :userId AND #status = :status',
        ExpressionAttributeNames: {
          '#status': 'status',
        },
        ExpressionAttributeValues: {
          ':userId': userId,
          ':status': 'inbox',
        },
      });

      // Filter to only scraped (not yet AI processed) nuggets
      nuggetsToProcess = allNuggets.filter(n => n.processingState === 'scraped');

      // Note: Daily limit enforcement removed here because when users explicitly
      // tap "Process" button, they want to process all available items together.
      // The limit should be enforced at nugget creation time instead.
    }

    if (nuggetsToProcess.length === 0) {
      return {
        statusCode: 200,
        body: JSON.stringify({
          message: 'No nuggets to process',
          processedCount: 0,
          nuggetIds: [],
        }),
      };
    }

    // Group nuggets by category or process all together if no categories
    // This allows the AI to synthesize related content
    const functionName = `nugget-${process.env.STAGE || 'dev'}-summariseNugget`;

    // Process nuggets as a group if there are 2 or more
    if (nuggetsToProcess.length >= 2) {
      // Step 1: First summarize each nugget individually (async)
      console.log(`Starting individual summarization for ${nuggetsToProcess.length} nuggets...`);
      const individualSummarizePromises = nuggetsToProcess.map(nugget =>
        lambda.send(new InvokeCommand({
          FunctionName: functionName,
          InvocationType: 'Event', // Async invocation
          Payload: Buffer.from(JSON.stringify({
            userId,
            nuggetId: nugget.nuggetId,
            groupAfterSummarize: true, // Signal to trigger grouping after
            groupNuggetIds: nuggetsToProcess.map(n => n.nuggetId)
          })),
        }))
      );

      await Promise.all(individualSummarizePromises);
      console.log(`Individual summarization requests sent. Grouping will happen automatically.`);

      return {
        statusCode: 200,
        body: JSON.stringify({
          message: `Started processing ${nuggetsToProcess.length} nugget(s). They will be grouped once individual summaries are complete.`,
          processedCount: nuggetsToProcess.length,
          nuggetIds: nuggetsToProcess.map(n => n.nuggetId),
        }),
      };
    }

    // If only one nugget, process individually
    const invocationPromises = nuggetsToProcess.map(nugget =>
      lambda.send(new InvokeCommand({
        FunctionName: functionName,
        InvocationType: 'Event', // Async invocation
        Payload: Buffer.from(JSON.stringify({ userId, nuggetId: nugget.nuggetId })),
      }))
    );

    await Promise.all(invocationPromises);

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: `Started processing ${nuggetsToProcess.length} nugget(s)`,
        processedCount: nuggetsToProcess.length,
        nuggetIds: nuggetsToProcess.map(n => n.nuggetId),
      }),
    };
  } catch (error) {
    console.error('Error in processNuggets handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

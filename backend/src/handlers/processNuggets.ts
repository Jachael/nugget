import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { getItem, queryItems, putItem, TableNames } from '../lib/dynamo';
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

      console.log(`Found ${allNuggets.length} nuggets with status=inbox for user ${userId}`);
      console.log('Processing states:', allNuggets.map(n => `${n.nuggetId}: ${n.processingState}`));

      // Filter to only scraped (not yet AI processed) nuggets
      nuggetsToProcess = allNuggets.filter(n => n.processingState === 'scraped');

      console.log(`After filtering, found ${nuggetsToProcess.length} nuggets in 'scraped' state`);

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

    // Process nuggets as a group if there are 2 or more
    if (nuggetsToProcess.length >= 2) {
      const now = Date.now() / 1000;
      const groupedNuggetId = `group-${uuidv4()}`;

      // Detect common categories
      const categoryCount: Record<string, number> = {};
      nuggetsToProcess.forEach(n => {
        if (n.category) {
          categoryCount[n.category] = (categoryCount[n.category] || 0) + 1;
        }
      });
      const dominantCategory = Object.keys(categoryCount).length > 0
        ? Object.entries(categoryCount).sort((a, b) => b[1] - a[1])[0][0]
        : 'mixed';

      // Create grouped nugget with minimal placeholder content
      // AI will fill in the real summary, keyPoints, etc.
      const groupedNugget: Nugget = {
        userId,
        nuggetId: groupedNuggetId,
        sourceUrl: nuggetsToProcess[0].sourceUrl,
        sourceType: 'other',
        title: `Processing ${nuggetsToProcess.length} articles...`,
        rawTitle: `Processing ${nuggetsToProcess.length} articles...`,
        category: dominantCategory,
        status: 'inbox',
        createdAt: now,
        priorityScore: 100,
        timesReviewed: 0,
        processingState: 'processing', // Will be updated to 'ready' by AI
        isGrouped: true,
        sourceUrls: nuggetsToProcess.map(n => n.sourceUrl),
        sourceNuggetIds: nuggetsToProcess.map(n => n.nuggetId),
        summary: 'AI is analyzing and summarizing your articles...',
        keyPoints: ['Processing in progress'],
        question: 'Processing...',
      };

      // Save the grouped nugget
      await putItem(TableNames.nuggets, groupedNugget);

      // Trigger background processing to enhance summaries with AI
      const functionName = `nugget-${process.env.STAGE || 'dev'}-summariseNugget`;
      console.log(`Invoking ${functionName} for grouped nugget ${groupedNuggetId} with ${nuggetsToProcess.length} articles`);
      try {
        const invokeResult = await lambda.send(new InvokeCommand({
          FunctionName: functionName,
          InvocationType: 'Event',
          Payload: Buffer.from(JSON.stringify({
            userId,
            nuggetIds: nuggetsToProcess.map(n => n.nuggetId),
            grouped: true,
            groupedNuggetId, // Pass the ID so AI can update it
          })),
        }));
        console.log('Lambda invocation result:', invokeResult);
      } catch (err) {
        console.error('Background processing invocation failed:', err);
        // Don't fail the request - the grouped nugget is already created
      }

      return {
        statusCode: 200,
        body: JSON.stringify({
          message: `Created digest of ${nuggetsToProcess.length} articles`,
          processedCount: nuggetsToProcess.length,
          nuggetIds: [groupedNuggetId],
          groupedNuggetId,
        }),
      };
    }

    // If only one nugget, process individually
    const functionName = `nugget-${process.env.STAGE || 'dev'}-summariseNugget`;
    const invocationPromises = nuggetsToProcess.map(nugget =>
      lambda.send(new InvokeCommand({
        FunctionName: functionName,
        InvocationType: 'Event',
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

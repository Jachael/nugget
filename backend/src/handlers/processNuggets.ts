import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { getItem, queryItems, updateItem, TableNames } from '../lib/dynamo';
import { User, Nugget } from '../lib/models';
import { groupNuggetsByCategory } from '../lib/smartGrouping';

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

    // IMMEDIATELY mark all source nuggets as "processing" to hide them from the feed
    // This prevents the user from seeing individual articles while they're being processed
    console.log(`Marking ${nuggetsToProcess.length} nuggets as processing...`);
    const markProcessingPromises = nuggetsToProcess.map(nugget =>
      updateItem(TableNames.nuggets, { userId, nuggetId: nugget.nuggetId }, {
        processingState: 'processing',
      })
    );
    await Promise.all(markProcessingPromises);
    console.log(`All ${nuggetsToProcess.length} nuggets marked as processing`);

    // Group nuggets by category using smart grouping
    // This ensures articles about different topics become separate nuggets
    const categoryGroups = groupNuggetsByCategory(nuggetsToProcess);

    console.log(`Smart grouping created ${categoryGroups.length} groups from ${nuggetsToProcess.length} nuggets`);
    categoryGroups.forEach(g => console.log(`  - Category "${g.category}": ${g.nuggets.length} nuggets`));

    const functionName = `nugget-${process.env.STAGE || 'dev'}-summariseNugget`;
    const groupedNuggetIds: string[] = [];

    // Process each category group
    for (const group of categoryGroups) {
      if (group.nuggets.length >= 2) {
        // Create a grouped nugget for this category
        const groupedNuggetId = `group-${uuidv4()}`;
        groupedNuggetIds.push(groupedNuggetId);

        // DON'T create a placeholder nugget that users can see!
        // Instead, just trigger the AI processing which will create the nugget when ready
        console.log(`Invoking ${functionName} for category "${group.category}" group ${groupedNuggetId} with ${group.nuggets.length} articles`);

        try {
          await lambda.send(new InvokeCommand({
            FunctionName: functionName,
            InvocationType: 'Event',
            Payload: Buffer.from(JSON.stringify({
              userId,
              nuggetIds: group.nuggets.map(n => n.nuggetId),
              grouped: true,
              groupedNuggetId,
              category: group.category,
            })),
          }));
        } catch (err) {
          console.error(`Background processing invocation failed for group ${groupedNuggetId}:`, err);
        }
      } else if (group.nuggets.length === 1) {
        // Process single nugget individually
        const nugget = group.nuggets[0];
        try {
          await lambda.send(new InvokeCommand({
            FunctionName: functionName,
            InvocationType: 'Event',
            Payload: Buffer.from(JSON.stringify({ userId, nuggetId: nugget.nuggetId })),
          }));
          console.log(`Invoked AI processing for single nugget ${nugget.nuggetId}`);
        } catch (err) {
          console.error(`Background processing invocation failed for nugget ${nugget.nuggetId}:`, err);
        }
      }
    }

    // If we have groups, return success
    if (categoryGroups.length > 0) {
      return {
        statusCode: 200,
        body: JSON.stringify({
          message: `Processing ${nuggetsToProcess.length} articles in ${categoryGroups.length} category group(s)`,
          processedCount: nuggetsToProcess.length,
          groupCount: categoryGroups.length,
          categories: categoryGroups.map(g => g.category),
        }),
      };
    }

    // If only one nugget (this shouldn't happen since groupNuggetsByCategory handles single nuggets above)
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

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { batchDeleteItems, queryItems, TableNames } from '../lib/dynamo';
import { Nugget } from '../lib/models';

interface BatchDeleteRequest {
  nuggetIds?: string[];  // Specific IDs to delete
  deleteAll?: boolean;   // Delete all nuggets for the user
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const body: BatchDeleteRequest = event.body ? JSON.parse(event.body) : {};
    const { nuggetIds, deleteAll } = body;

    if (!nuggetIds && !deleteAll) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Either nuggetIds or deleteAll must be provided' }),
      };
    }

    let keysToDelete: { userId: string; nuggetId: string }[] = [];

    if (deleteAll) {
      // Get all nuggets for this user
      const allNuggets = await queryItems<Nugget>({
        TableName: TableNames.nuggets,
        KeyConditionExpression: 'userId = :userId',
        ExpressionAttributeValues: {
          ':userId': userId,
        },
      });

      keysToDelete = allNuggets.map(n => ({
        userId,
        nuggetId: n.nuggetId,
      }));
    } else if (nuggetIds && nuggetIds.length > 0) {
      keysToDelete = nuggetIds.map(nuggetId => ({
        userId,
        nuggetId,
      }));
    }

    if (keysToDelete.length === 0) {
      return {
        statusCode: 200,
        body: JSON.stringify({ success: true, deleted: 0 }),
      };
    }

    // Batch delete
    await batchDeleteItems(TableNames.nuggets, keysToDelete);

    console.log(`Deleted ${keysToDelete.length} nuggets for user ${userId}`);

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        deleted: keysToDelete.length,
      }),
    };
  } catch (error) {
    console.error('Error in batchDeleteNuggets handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

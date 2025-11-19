import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { deleteItem, TableNames } from '../lib/dynamo';

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

    const nuggetId = event.pathParameters?.nuggetId;
    if (!nuggetId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'nuggetId is required' }),
      };
    }

    // Delete the nugget
    await deleteItem(TableNames.nuggets, { userId, nuggetId });

    return {
      statusCode: 200,
      body: JSON.stringify({ success: true }),
    };
  } catch (error) {
    console.error('Error in deleteNugget handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, updateItem, TableNames } from '../lib/dynamo';
import { Nugget, PatchNuggetInput } from '../lib/models';

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

    const nuggetId = event.pathParameters?.nuggetId;
    if (!nuggetId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'nuggetId is required' }),
      };
    }

    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body is required' }),
      };
    }

    const input: PatchNuggetInput = JSON.parse(event.body);

    // Verify nugget exists and belongs to user
    const nugget = await getItem<Nugget>(TableNames.nuggets, { userId, nuggetId });
    if (!nugget) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'Nugget not found' }),
      };
    }

    // Build updates
    const updates: Record<string, unknown> = {};

    if (input.status) {
      const validStatuses = ['inbox', 'completed', 'archived'];
      if (!validStatuses.includes(input.status)) {
        return {
          statusCode: 400,
          body: JSON.stringify({ error: 'Invalid status' }),
        };
      }
      updates.status = input.status;
    }

    if (input.category !== undefined) {
      updates.category = input.category;
    }

    if (Object.keys(updates).length === 0) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'No valid fields to update' }),
      };
    }

    // Update nugget
    await updateItem(TableNames.nuggets, { userId, nuggetId }, updates);

    return {
      statusCode: 200,
      body: JSON.stringify({ success: true, updated: updates }),
    };
  } catch (error) {
    console.error('Error in patchNugget handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

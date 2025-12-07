import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, TableNames } from '../lib/dynamo';
import { User } from '../lib/models';

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    // Return the stored streak and lastActiveDate
    // These are updated by completeSession when user completes daily learning
    return {
      statusCode: 200,
      body: JSON.stringify({
        userId: user.userId,
        streak: user.streak || 0,
        lastActiveDate: user.lastActiveDate || new Date().toISOString().split('T')[0],
        firstName: user.firstName,
      }),
    };
  } catch (error) {
    console.error('Error in getMe handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

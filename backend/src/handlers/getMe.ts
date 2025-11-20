import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, TableNames, queryItems, updateItem } from '../lib/dynamo';
import { User, Nugget } from '../lib/models';
import { calculateStreak } from '../lib/streak';

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

    // Get all user nuggets to calculate actual streak
    const nuggets = await queryItems<Nugget>({
      TableName: TableNames.nuggets,
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId,
      },
    });

    // Calculate streak based on nugget creation dates
    const nuggetTimestamps = nuggets.map(n => n.createdAt);
    const { streak, lastActiveDate } = calculateStreak(nuggetTimestamps);

    // Update user's streak if it changed
    if (streak !== user.streak || lastActiveDate !== user.lastActiveDate) {
      await updateItem(TableNames.users, { userId }, { streak, lastActiveDate });
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        userId: user.userId,
        streak,
        lastActiveDate,
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

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { verifyCognitoToken, getCognitoUserId } from '../lib/cognito';
import { getItem, putItem, TableNames } from '../lib/dynamo';
import { User, AuthResponse } from '../lib/models';

interface AuthCognitoRequest {
  idToken: string;
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body is required' }),
      };
    }

    const body: AuthCognitoRequest = JSON.parse(event.body);

    if (!body.idToken) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'idToken is required' }),
      };
    }

    // Verify Cognito token
    const cognitoUser = await verifyCognitoToken(body.idToken);
    if (!cognitoUser) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Invalid token' }),
      };
    }

    const userId = getCognitoUserId(cognitoUser.sub);

    // Look for existing user in DynamoDB
    let user = await getItem<User>(TableNames.users, { userId });

    if (!user) {
      // Create new user
      const now = Date.now() / 1000;
      const today = new Date().toISOString().split('T')[0];

      user = {
        userId,
        cognitoSub: cognitoUser.sub,
        email: cognitoUser.email,
        name: cognitoUser.name,
        createdAt: now,
        lastActiveDate: today,
        streak: 1,
        settings: {},
      };

      await putItem(TableNames.users, user);
    } else {
      // Update last active date and streak if needed
      const today = new Date().toISOString().split('T')[0];
      if (user.lastActiveDate !== today) {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        const yesterdayStr = yesterday.toISOString().split('T')[0];

        if (user.lastActiveDate === yesterdayStr) {
          // Consecutive day - increment streak
          user.streak = (user.streak || 0) + 1;
        } else {
          // Streak broken - reset to 1
          user.streak = 1;
        }

        user.lastActiveDate = today;
        await putItem(TableNames.users, user);
      }
    }

    // Return the Cognito token directly (no need to generate our own JWT)
    const response: AuthResponse = {
      userId: user!.userId,
      accessToken: body.idToken, // Pass through the Cognito token
      streak: user!.streak,
    };

    return {
      statusCode: 200,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in authCognito handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}
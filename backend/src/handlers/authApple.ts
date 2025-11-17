import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { verifyAppleToken, generateAccessToken } from '../lib/auth';
import { getItem, putItem, TableNames } from '../lib/dynamo';
import { User, AuthResponse } from '../lib/models';

interface AuthAppleRequest {
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

    const body: AuthAppleRequest = JSON.parse(event.body);

    if (!body.idToken) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'idToken is required' }),
      };
    }

    // Verify Apple token
    const applePayload = await verifyAppleToken(body.idToken);
    if (!applePayload) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Invalid Apple ID token' }),
      };
    }

    const appleSub = applePayload.sub;

    // Look for existing user by scanning (in production, use a GSI on appleSub)
    // For MVP simplicity, we'll do a simple scan or maintain a separate lookup
    // For now, we'll use appleSub as a deterministic userId generator
    const userId = `usr_${appleSub}`;

    let user = await getItem<User>(TableNames.users, { userId });

    if (!user) {
      // Create new user
      const now = Date.now() / 1000;
      const today = new Date().toISOString().split('T')[0];

      user = {
        userId,
        appleSub,
        createdAt: now,
        lastActiveDate: today,
        streak: 0,
        settings: {},
      };

      await putItem(TableNames.users, user);
    }

    // Generate access token
    const accessToken = generateAccessToken(userId);

    const response: AuthResponse = {
      userId: user.userId,
      accessToken,
      streak: user.streak,
    };

    return {
      statusCode: 200,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in authApple handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { OAuth2Client } from 'google-auth-library';
import { generateAccessToken } from '../lib/auth';
import { getItem, putItem, TableNames } from '../lib/dynamo';
import { User, AuthResponse } from '../lib/models';

interface AuthGoogleRequest {
  idToken: string;
}

const client = new OAuth2Client();

/**
 * Google authentication handler
 * Verifies Google ID token and creates/retrieves user
 */
export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body is required' }),
      };
    }

    const body: AuthGoogleRequest = JSON.parse(event.body);

    if (!body.idToken) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'idToken is required' }),
      };
    }

    // Verify Google token
    const googleClientId = process.env.GOOGLE_CLIENT_ID;
    if (!googleClientId) {
      console.error('GOOGLE_CLIENT_ID not configured');
      return {
        statusCode: 500,
        body: JSON.stringify({ error: 'Google authentication not configured' }),
      };
    }

    const ticket = await client.verifyIdToken({
      idToken: body.idToken,
      audience: googleClientId,
    });

    const payload = ticket.getPayload();
    if (!payload) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Invalid Google ID token' }),
      };
    }

    const googleSub = payload.sub;
    const email = payload.email;
    const firstName = payload.given_name;
    const lastName = payload.family_name;
    const picture = payload.picture;

    // Generate deterministic userId from Google sub
    const userId = `usr_g_${googleSub}`;

    let user = await getItem<User>(TableNames.users, { userId });

    if (!user) {
      // Create new user
      const now = Date.now() / 1000;
      const today = new Date().toISOString().split('T')[0];

      user = {
        userId,
        googleSub,
        email,
        firstName,
        lastName,
        picture,
        createdAt: now,
        lastActiveDate: today,
        streak: 1,
        settings: {},
        onboardingCompleted: false,
      };

      await putItem(TableNames.users, user);
    }

    // Generate access token
    const accessToken = generateAccessToken(userId);

    const response: AuthResponse = {
      userId: user!.userId,
      accessToken,
      streak: user!.streak,
    };

    return {
      statusCode: 200,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in authGoogle handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}
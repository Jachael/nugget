import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { verifyAppleToken, generateAccessToken } from '../lib/auth';
import { getItem, putItem, TableNames } from '../lib/dynamo';
import { User, AuthResponse } from '../lib/models';

interface AuthAppleRequest {
  identityToken?: string;
  idToken?: string; // Legacy field name for backward compatibility
  authorizationCode: string;
  userIdentifier: string;
  email?: string;
  firstName?: string;
  lastName?: string;
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    console.log('authApple handler called, event.body:', event.body);

    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body is required' }),
      };
    }

    const body: AuthAppleRequest = JSON.parse(event.body);
    console.log('Parsed body keys:', Object.keys(body));

    // Support both identityToken (new) and idToken (legacy) field names
    const token = body.identityToken || body.idToken;
    console.log('identityToken present:', !!body.identityToken);
    console.log('idToken present:', !!body.idToken);
    console.log('token length:', token?.length);

    if (!token) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'identityToken is required' }),
      };
    }

    // Verify Apple token
    const applePayload = await verifyAppleToken(token);
    if (!applePayload) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Invalid Apple ID token' }),
      };
    }

    const appleSub = applePayload.sub;
    const tokenEmail = applePayload.email;

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
        email: body.email || tokenEmail, // Use email from request or from token
        firstName: body.firstName,
        lastName: body.lastName,
        createdAt: now,
        lastActiveDate: today,
        streak: 1,
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
      firstName: user.firstName,
      subscriptionTier: user.subscriptionTier || 'free',
      subscriptionExpiresAt: user.subscriptionExpiresAt,
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

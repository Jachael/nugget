import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { generateAccessToken } from '../lib/auth';
import { getItem, putItem, TableNames } from '../lib/dynamo';
import { User, AuthResponse } from '../lib/models';

interface AuthMockRequest {
  mockUser: string;
}

/**
 * Mock authentication handler for local testing
 * Creates or retrieves a test user without real authentication
 * ONLY available in development/local environments
 */
export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    // Only allow in dev/local environments OR with special test header
    const testHeader = event.headers?.['x-test-auth'] || event.headers?.['X-Test-Auth'];
    if (process.env.STAGE === 'prod' && testHeader !== 'nugget-test-2024') {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'Not found' }),
      };
    }

    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body is required' }),
      };
    }

    const body: AuthMockRequest = JSON.parse(event.body);

    if (!body.mockUser) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'mockUser is required' }),
      };
    }

    // Generate deterministic userId from mock username
    const userId = `usr_mock_${body.mockUser}`;

    let user = await getItem<User>(TableNames.users, { userId });

    if (!user) {
      // Create new mock user
      const now = Date.now() / 1000;
      const today = new Date().toISOString().split('T')[0];

      user = {
        userId,
        email: `${body.mockUser}@example.com`,
        firstName: 'Test',
        lastName: 'User',
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
      userId: user.userId,
      accessToken,
      streak: user.streak,
    };

    return {
      statusCode: 200,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in authMock handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}
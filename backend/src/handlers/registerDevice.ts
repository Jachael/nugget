import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { registerDeviceToken, unregisterDeviceToken } from '../lib/notifications';

interface RegisterDeviceRequest {
  deviceToken: string;
  platform: 'ios' | 'android';
  unregister?: boolean; // Optional flag to unregister the device
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    // Authenticate the request
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    // Parse request body
    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body is required' }),
      };
    }

    const body: RegisterDeviceRequest = JSON.parse(event.body);

    // Validate required fields
    if (!body.deviceToken) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'deviceToken is required' }),
      };
    }

    if (!body.platform || !['ios', 'android'].includes(body.platform)) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'platform must be either "ios" or "android"' }),
      };
    }

    // Handle unregistration
    if (body.unregister) {
      await unregisterDeviceToken(userId, body.deviceToken);
      return {
        statusCode: 200,
        body: JSON.stringify({
          success: true,
          message: 'Device token unregistered successfully',
        }),
      };
    }

    // Register the device token
    await registerDeviceToken(userId, body.deviceToken, body.platform);

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        message: 'Device token registered successfully',
      }),
    };
  } catch (error) {
    console.error('Error in registerDevice handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
    };
  }
}

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { sendNuggetsReadyNotification, sendStreakReminderNotification, sendNewContentNotification } from '../lib/notifications';
import { queryItems, TableNames } from '../lib/dynamo';
import { DeviceToken } from '../lib/models';

interface TestNotificationRequest {
  type?: 'nuggets_ready' | 'streak_reminder' | 'new_content';
  count?: number; // For nuggets_ready
  streak?: number; // For streak_reminder
  title?: string; // For new_content
}

/**
 * Test endpoint to send a push notification to the authenticated user
 * POST /v1/notifications/test
 */
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
    const body: TestNotificationRequest = event.body ? JSON.parse(event.body) : {};
    const notificationType = body.type || 'nuggets_ready';

    // Check if user has any registered device tokens
    const deviceTokens = await queryItems<DeviceToken>({
      TableName: TableNames.deviceTokens,
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId,
      },
    });

    if (!deviceTokens || deviceTokens.length === 0) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          error: 'No registered devices',
          message: 'Please ensure your device is registered for push notifications. Check that you have granted notification permissions in the app.',
        }),
      };
    }

    // Check if any tokens have SNS endpoints
    const tokensWithEndpoints = deviceTokens.filter(t => t.endpointArn);

    console.log(`Found ${deviceTokens.length} device token(s) for user ${userId}, ${tokensWithEndpoints.length} with SNS endpoints`);

    // Send the appropriate notification
    switch (notificationType) {
      case 'nuggets_ready':
        await sendNuggetsReadyNotification(userId, body.count || 3);
        break;
      case 'streak_reminder':
        await sendStreakReminderNotification(userId, body.streak || 5);
        break;
      case 'new_content':
        await sendNewContentNotification(userId, body.title || 'Test notification content');
        break;
      default:
        return {
          statusCode: 400,
          body: JSON.stringify({ error: 'Invalid notification type' }),
        };
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        message: `Test notification sent successfully`,
        details: {
          type: notificationType,
          deviceCount: deviceTokens.length,
          devicesWithSNS: tokensWithEndpoints.length,
        },
      }),
    };
  } catch (error) {
    console.error('Error in testNotification handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
    };
  }
}

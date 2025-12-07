import { SNSClient, CreatePlatformEndpointCommand, PublishCommand, DeleteEndpointCommand } from '@aws-sdk/client-sns';
import { getItem, putItem, queryItems, TableNames, deleteItem } from './dynamo';
import { DeviceToken } from './models';

const snsClient = new SNSClient({ region: process.env.AWS_REGION || 'eu-west-1' });

// Platform Application ARN for iOS (needs to be configured in AWS SNS)
// This should be set in environment variables
const IOS_PLATFORM_APPLICATION_ARN = process.env.IOS_PLATFORM_APPLICATION_ARN || '';
const ANDROID_PLATFORM_APPLICATION_ARN = process.env.ANDROID_PLATFORM_APPLICATION_ARN || '';

export enum NotificationType {
  NUGGETS_READY = 'NUGGETS_READY',
  STREAK_REMINDER = 'STREAK_REMINDER',
  NEW_CONTENT = 'NEW_CONTENT',
}

export interface PushNotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
  badge?: number;
  sound?: string;
  category?: string;
}

/**
 * Register a device token with SNS and store in DynamoDB
 */
export async function registerDeviceToken(
  userId: string,
  deviceToken: string,
  platform: 'ios' | 'android'
): Promise<void> {
  const now = Date.now() / 1000;

  // Check if device token already exists
  const existingToken = await getItem<DeviceToken>(TableNames.deviceTokens, {
    userId,
    deviceToken,
  });

  // Get the appropriate platform application ARN
  const platformApplicationArn = platform === 'ios'
    ? IOS_PLATFORM_APPLICATION_ARN
    : ANDROID_PLATFORM_APPLICATION_ARN;

  if (!platformApplicationArn) {
    console.warn(`Platform application ARN not configured for ${platform}`);
    // Still store the token in DynamoDB even if SNS is not configured
    // This allows testing and gradual rollout
  }

  let endpointArn: string | undefined;

  // Create SNS platform endpoint if ARN is configured
  if (platformApplicationArn) {
    try {
      const createEndpointCommand = new CreatePlatformEndpointCommand({
        PlatformApplicationArn: platformApplicationArn,
        Token: deviceToken,
        CustomUserData: userId,
      });

      const response = await snsClient.send(createEndpointCommand);
      endpointArn = response.EndpointArn;
      console.log(`Created SNS endpoint: ${endpointArn}`);
    } catch (error) {
      console.error('Error creating SNS endpoint:', error);
      // Continue to store the token even if SNS fails
    }
  }

  // Store or update device token in DynamoDB
  const deviceTokenRecord: DeviceToken = {
    userId,
    deviceToken,
    platform,
    endpointArn,
    createdAt: existingToken?.createdAt || now,
    updatedAt: now,
  };

  await putItem(TableNames.deviceTokens, deviceTokenRecord);
  console.log(`Device token registered for user ${userId}`);
}

/**
 * Unregister a device token
 */
export async function unregisterDeviceToken(userId: string, deviceToken: string): Promise<void> {
  // Get the device token record
  const tokenRecord = await getItem<DeviceToken>(TableNames.deviceTokens, {
    userId,
    deviceToken,
  });

  if (!tokenRecord) {
    console.log(`Device token not found for user ${userId}`);
    return;
  }

  // Delete SNS endpoint if it exists
  if (tokenRecord.endpointArn) {
    try {
      const deleteEndpointCommand = new DeleteEndpointCommand({
        EndpointArn: tokenRecord.endpointArn,
      });
      await snsClient.send(deleteEndpointCommand);
      console.log(`Deleted SNS endpoint: ${tokenRecord.endpointArn}`);
    } catch (error) {
      console.error('Error deleting SNS endpoint:', error);
    }
  }

  // Delete from DynamoDB
  await deleteItem(TableNames.deviceTokens, { userId, deviceToken });
  console.log(`Device token unregistered for user ${userId}`);
}

/**
 * Send a push notification to a specific user
 */
export async function sendPushNotification(
  userId: string,
  notificationType: NotificationType,
  payload: PushNotificationPayload
): Promise<void> {
  // Get all device tokens for the user
  const deviceTokens = await queryItems<DeviceToken>({
    TableName: TableNames.deviceTokens,
    KeyConditionExpression: 'userId = :userId',
    ExpressionAttributeValues: {
      ':userId': userId,
    },
  });

  if (!deviceTokens || deviceTokens.length === 0) {
    console.log(`No device tokens found for user ${userId}`);
    return;
  }

  console.log(`Sending notification to ${deviceTokens.length} device(s) for user ${userId}`);

  // Send notification to each device
  const promises = deviceTokens.map(async (token) => {
    if (!token.endpointArn) {
      console.log(`No endpoint ARN for device token, skipping`);
      return;
    }

    try {
      // Build the notification payload based on platform
      const message = buildNotificationMessage(token.platform, notificationType, payload);

      const publishCommand = new PublishCommand({
        TargetArn: token.endpointArn,
        Message: JSON.stringify(message),
        MessageStructure: 'json',
      });

      await snsClient.send(publishCommand);
      console.log(`Notification sent to endpoint: ${token.endpointArn}`);
    } catch (error) {
      console.error(`Error sending notification to ${token.endpointArn}:`, error);

      // If the endpoint is invalid, delete it
      if ((error as any).code === 'EndpointDisabled' || (error as any).code === 'InvalidParameter') {
        console.log(`Endpoint ${token.endpointArn} is invalid, removing from database`);
        await deleteItem(TableNames.deviceTokens, {
          userId: token.userId,
          deviceToken: token.deviceToken,
        });
      }
    }
  });

  await Promise.all(promises);
}

/**
 * Build platform-specific notification message
 */
function buildNotificationMessage(
  platform: 'ios' | 'android',
  notificationType: NotificationType,
  payload: PushNotificationPayload
): Record<string, string> {
  const { title, body, data = {}, badge, sound = 'default', category } = payload;

  // Add notification type to data
  const extendedData = {
    ...data,
    type: notificationType,
  };

  if (platform === 'ios') {
    // APNs format
    const aps: any = {
      alert: {
        title,
        body,
      },
      sound,
    };

    if (badge !== undefined) {
      aps.badge = badge;
    }

    if (category) {
      aps.category = category;
    }

    return {
      APNS: JSON.stringify({
        aps,
        ...extendedData,
      }),
      APNS_SANDBOX: JSON.stringify({
        aps,
        ...extendedData,
      }),
    };
  } else {
    // FCM format (Android)
    return {
      GCM: JSON.stringify({
        notification: {
          title,
          body,
          sound,
        },
        data: extendedData,
      }),
    };
  }
}

/**
 * Helper function to send "nuggets ready" notification
 */
export async function sendNuggetsReadyNotification(
  userId: string,
  nuggetCount: number
): Promise<void> {
  const payload: PushNotificationPayload = {
    title: 'Your Nuggets are Ready!',
    body: `${nuggetCount} new nugget${nuggetCount > 1 ? 's are' : ' is'} ready to review`,
    category: NotificationType.NUGGETS_READY,
    badge: nuggetCount,
    data: {
      nuggetCount: nuggetCount.toString(),
    },
  };

  await sendPushNotification(userId, NotificationType.NUGGETS_READY, payload);
}

/**
 * Helper function to send streak reminder notification
 */
export async function sendStreakReminderNotification(
  userId: string,
  currentStreak: number
): Promise<void> {
  const payload: PushNotificationPayload = {
    title: 'Keep Your Streak Alive!',
    body: `You're on a ${currentStreak} day streak. Don't break it!`,
    category: NotificationType.STREAK_REMINDER,
    data: {
      streak: currentStreak.toString(),
    },
  };

  await sendPushNotification(userId, NotificationType.STREAK_REMINDER, payload);
}

/**
 * Helper function to send new content notification
 */
export async function sendNewContentNotification(
  userId: string,
  contentTitle: string
): Promise<void> {
  const payload: PushNotificationPayload = {
    title: 'New Content Available',
    body: contentTitle,
    category: NotificationType.NEW_CONTENT,
  };

  await sendPushNotification(userId, NotificationType.NEW_CONTENT, payload);
}

import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { v4 as uuidv4 } from 'uuid';
import { getItem, queryItems, updateItem, TableNames } from '../lib/dynamo';
import { User, Nugget, ProcessingSchedule, DeviceToken } from '../lib/models';
import { createProcessingBatches } from '../lib/smartGrouping';

const lambda = new LambdaClient({ region: process.env.AWS_REGION || 'eu-west-1' });
const sns = new SNSClient({ region: process.env.AWS_REGION || 'eu-west-1' });

interface AutoProcessEvent {
  userId: string;
}

/**
 * Auto-process nuggets for a user based on their schedule
 * Invoked by EventBridge Scheduler
 */
export async function handler(event: AutoProcessEvent): Promise<void> {
  try {
    console.log('Received event:', JSON.stringify(event, null, 2));

    const userId = event.userId;

    if (!userId) {
      console.error('No userId provided in event');
      return;
    }

    console.log(`Auto-processing nuggets for user: ${userId}`);

    // Get user
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      console.error(`User not found: ${userId}`);
      return;
    }

    // Verify user has paid subscription (pro or ultimate) and auto-process enabled
    const tier = user.subscriptionTier || user.preferences?.subscriptionTier;
    if (tier !== 'pro' && tier !== 'ultimate') {
      console.error(`User ${userId} does not have a paid subscription (tier: ${tier})`);
      return;
    }

    if (!user.autoProcessEnabled) {
      console.log(`Auto-processing disabled for user ${userId}`);
      return;
    }

    // Get user's processing schedule
    const scheduleTableName = process.env.NUGGET_SCHEDULES_TABLE || `nugget-schedules-${process.env.STAGE || 'dev'}`;
    const schedule = user.processingScheduleId
      ? await getItem<ProcessingSchedule>(scheduleTableName, {
          userId,
          scheduleId: user.processingScheduleId
        })
      : null;

    if (!schedule || !schedule.enabled) {
      console.log(`No active schedule found for user ${userId}`);
      return;
    }

    // Fetch unprocessed nuggets in inbox
    const allNuggets = await queryItems<Nugget>({
      TableName: TableNames.nuggets,
      IndexName: 'UserStatusIndex',
      KeyConditionExpression: 'userId = :userId AND #status = :status',
      ExpressionAttributeNames: {
        '#status': 'status',
      },
      ExpressionAttributeValues: {
        ':userId': userId,
        ':status': 'inbox',
      },
    });

    console.log(`Found ${allNuggets.length} nuggets with status=inbox for user ${userId}`);

    // Filter to only scraped (not yet AI processed) nuggets
    const nuggetsToProcess = allNuggets.filter(n => n.processingState === 'scraped');

    console.log(`Found ${nuggetsToProcess.length} unprocessed nuggets for user ${userId}`);

    if (nuggetsToProcess.length === 0) {
      console.log('No nuggets to process');

      // Update schedule's last run time
      const now = Math.floor(Date.now() / 1000);
      await updateItem(scheduleTableName, { userId, scheduleId: schedule.scheduleId }, {
        lastRun: now,
        updatedAt: now,
      });

      return;
    }

    // Apply tier-based limits
    const subscriptionTier = user.subscriptionTier || user.preferences?.subscriptionTier || 'free';
    const batchLimit = subscriptionTier === 'ultimate' ? 15 : (subscriptionTier === 'pro' ? 10 : 3);
    const limitedNuggets = nuggetsToProcess.slice(0, batchLimit);

    console.log(`Processing ${limitedNuggets.length} nuggets (limit: ${batchLimit})`);

    // Group nuggets by category for smart processing
    const batches = createProcessingBatches(limitedNuggets, subscriptionTier);

    console.log(`Created ${batches.length} processing batches based on smart grouping`);

    // Process each batch
    const functionName = `nugget-${process.env.STAGE || 'dev'}-summariseNugget`;
    let processedCount = 0;
    const groupedNuggetIds: string[] = [];

    for (const batch of batches) {
      if (batch.length === 0) continue;

      if (batch.length >= 2) {
        // DON'T create a placeholder nugget - let AI processing create the final nugget when ready
        const groupedNuggetId = `group-${uuidv4()}`;
        groupedNuggetIds.push(groupedNuggetId);

        // Detect category for this batch (used by smart grouping)
        const categoryCount: Record<string, number> = {};
        batch.forEach(n => {
          if (n.category) {
            categoryCount[n.category] = (categoryCount[n.category] || 0) + 1;
          }
        });
        const batchCategory = Object.keys(categoryCount).length > 0
          ? Object.entries(categoryCount).sort((a, b) => b[1] - a[1])[0][0]
          : 'mixed';

        // Trigger AI processing - it will create the nugget when ready
        try {
          await lambda.send(new InvokeCommand({
            FunctionName: functionName,
            InvocationType: 'Event',
            Payload: Buffer.from(JSON.stringify({
              userId,
              nuggetIds: batch.map(n => n.nuggetId),
              grouped: true,
              groupedNuggetId,
              category: batchCategory,
            })),
          }));
          console.log(`Invoked AI processing for grouped nugget ${groupedNuggetId} with ${batch.length} articles (category: ${batchCategory})`);
          processedCount += batch.length;
        } catch (err) {
          console.error('Error invoking AI processing:', err);
        }
      } else {
        // Process single nugget
        const nugget = batch[0];
        try {
          await lambda.send(new InvokeCommand({
            FunctionName: functionName,
            InvocationType: 'Event',
            Payload: Buffer.from(JSON.stringify({ userId, nuggetId: nugget.nuggetId })),
          }));
          console.log(`Invoked AI processing for nugget ${nugget.nuggetId}`);
          processedCount += 1;
        } catch (err) {
          console.error('Error invoking AI processing:', err);
        }
      }
    }

    // Update schedule's last run and next run time
    const now = Math.floor(Date.now() / 1000);
    const nextRunTimestamp = calculateNextRun(schedule.frequency, schedule.preferredTime, schedule.timezone);
    const nextRun = new Date(nextRunTimestamp * 1000).toISOString();

    await updateItem(scheduleTableName, { userId, scheduleId: schedule.scheduleId }, {
      lastRun: now,
      nextRun,  // Store as ISO string to match model
      updatedAt: now,
    });

    console.log(`Auto-processing complete. Processed ${processedCount} nuggets in ${batches.length} batches`);

    // Send push notification if user has device tokens
    try {
      await sendProcessingNotification(userId, processedCount);
    } catch (err) {
      console.error('Error sending notification:', err);
      // Don't fail the function if notification fails
    }

  } catch (error) {
    console.error('Error in autoProcessNuggets handler:', error);
    throw error;
  }
}

/**
 * Calculate next run time based on schedule
 */
function calculateNextRun(frequency: string, preferredTime: string, _timezone: string): number {
  const now = new Date();
  const [hours, minutes] = preferredTime.split(':').map(Number);

  const next = new Date(now);
  next.setHours(hours, minutes, 0, 0);

  switch (frequency) {
    case 'daily':
      // Next occurrence is tomorrow at the same time
      if (next <= now) {
        next.setDate(next.getDate() + 1);
      }
      break;
    case 'twice_daily':
      // Next occurrence is either later today (12h later) or tomorrow
      const secondRun = new Date(next);
      secondRun.setHours((hours + 12) % 24);
      if (secondRun > now) {
        return Math.floor(secondRun.getTime() / 1000);
      }
      next.setDate(next.getDate() + 1);
      break;
    case 'weekly':
      // Next occurrence is next Monday
      next.setDate(next.getDate() + 7);
      break;
  }

  return Math.floor(next.getTime() / 1000);
}

/**
 * Send push notification about completed processing
 */
async function sendProcessingNotification(userId: string, count: number): Promise<void> {
  // Check if user has push notifications enabled in settings
  // Default to true if not explicitly set to false
  const user = await getItem<User>(TableNames.users, { userId });
  if (user?.settings?.notificationsEnabled === false) {
    console.log(`Notifications disabled for user ${userId}`);
    return;
  }

  // Get user's device tokens
  const deviceTokensTable = process.env.NUGGET_DEVICE_TOKENS_TABLE || `nugget-device-tokens-${process.env.STAGE || 'dev'}`;
  const deviceTokens = await queryItems<DeviceToken>({
    TableName: deviceTokensTable,
    KeyConditionExpression: 'userId = :userId',
    ExpressionAttributeValues: {
      ':userId': userId,
    },
  });

  if (deviceTokens.length === 0) {
    console.log(`No device tokens found for user ${userId}`);
    return;
  }

  // Send notification to each device
  const message = count > 1
    ? `${count} articles have been processed and are ready to review!`
    : `1 article has been processed and is ready to review!`;

  for (const deviceToken of deviceTokens) {
    if (!deviceToken.endpointArn) continue;

    try {
      await sns.send(new PublishCommand({
        TargetArn: deviceToken.endpointArn,
        Message: JSON.stringify({
          aps: {
            alert: {
              title: 'Nuggets Ready',
              body: message,
            },
            badge: count,
            sound: 'default',
          },
        }),
        MessageStructure: 'json',
      }));
      console.log(`Sent notification to device ${deviceToken.deviceToken}`);
    } catch (err) {
      console.error(`Error sending notification to device ${deviceToken.deviceToken}:`, err);
    }
  }
}

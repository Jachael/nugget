import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { SchedulerClient, CreateScheduleCommand, UpdateScheduleCommand, DeleteScheduleCommand, GetScheduleCommand } from '@aws-sdk/client-scheduler';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { getItem, putItem, updateItem, TableNames } from '../lib/dynamo';
import { User, ProcessingSchedule } from '../lib/models';

const scheduler = new SchedulerClient({ region: process.env.AWS_REGION || 'eu-west-1' });

interface SetScheduleRequest {
  enabled: boolean;
  frequency?: 'daily' | 'twice_daily' | 'weekly';
  preferredTime?: string; // "09:00" format
  timezone?: string; // IANA timezone
}

/**
 * Calculate next run time based on schedule
 */
function calculateNextRun(frequency: string, preferredTime: string, _timezone: string): number {
  const now = new Date();
  const [hours, minutes] = preferredTime.split(':').map(Number);

  const next = new Date(now);
  next.setHours(hours, minutes, 0, 0);

  // If time has passed today, schedule for tomorrow
  if (next <= now) {
    next.setDate(next.getDate() + 1);
  }

  // For weekly, schedule for next week
  if (frequency === 'weekly' && next <= now) {
    next.setDate(next.getDate() + 7);
  }

  return Math.floor(next.getTime() / 1000);
}

/**
 * Convert frequency to EventBridge cron expression
 */
function frequencyToCron(frequency: string, preferredTime: string, _timezone: string): string {
  const [hours, minutes] = preferredTime.split(':').map(Number);

  switch (frequency) {
    case 'daily':
      return `cron(${minutes} ${hours} * * ? *)`;
    case 'twice_daily':
      // Run at preferred time and 12 hours later
      const secondHour = (hours + 12) % 24;
      return `cron(${minutes} ${hours},${secondHour} * * ? *)`;
    case 'weekly':
      // Run every Monday at preferred time
      return `cron(${minutes} ${hours} ? * MON *)`;
    default:
      return `cron(${minutes} ${hours} * * ? *)`;
  }
}

/**
 * Create/update user's processing schedule
 * Requires Plus or Pro subscription
 */
export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    // Parse request
    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body required' }),
      };
    }

    const request: SetScheduleRequest = JSON.parse(event.body);

    // Get user and check subscription
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    // Check if user has a paid subscription (pro or ultimate)
    const tier = user.subscriptionTier || user.preferences?.subscriptionTier;
    if (tier !== 'pro' && tier !== 'ultimate') {
      return {
        statusCode: 403,
        body: JSON.stringify({
          error: 'Auto-processing requires a Pro or Ultimate subscription',
          upgradeRequired: true,
        }),
      };
    }

    // If disabling, delete the schedule
    if (!request.enabled) {
      if (user.processingScheduleId) {
        const scheduleName = `nugget-auto-process-${userId}`;

        try {
          // Delete EventBridge schedule
          await scheduler.send(new DeleteScheduleCommand({
            Name: scheduleName,
          }));
        } catch (err) {
          console.error('Error deleting EventBridge schedule:', err);
          // Continue even if schedule deletion fails
        }

        // Update user
        await updateItem(TableNames.users, { userId }, {
          autoProcessEnabled: false,
          processingScheduleId: undefined,
        });
      }

      return {
        statusCode: 200,
        body: JSON.stringify({
          message: 'Auto-processing disabled',
          enabled: false,
        }),
      };
    }

    // Validate required fields for enabling
    if (!request.frequency || !request.preferredTime || !request.timezone) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          error: 'frequency, preferredTime, and timezone are required when enabling auto-processing'
        }),
      };
    }

    // Validate time format
    if (!/^\d{2}:\d{2}$/.test(request.preferredTime)) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'preferredTime must be in HH:MM format (e.g., "09:00")' }),
      };
    }

    const scheduleTableName = process.env.NUGGET_SCHEDULES_TABLE || `nugget-schedules-${process.env.STAGE || 'dev'}`;
    const now = Math.floor(Date.now() / 1000);
    const scheduleId = user.processingScheduleId || `schedule-${uuidv4()}`;
    const nextRunTimestamp = calculateNextRun(request.frequency, request.preferredTime, request.timezone);
    const nextRun = new Date(nextRunTimestamp * 1000).toISOString();

    // Create or update schedule record
    const schedule: ProcessingSchedule = {
      userId,
      scheduleId,
      frequency: request.frequency,
      preferredTime: request.preferredTime,
      timezone: request.timezone,
      enabled: true,
      nextRun,
      createdAt: user.processingScheduleId ? (await getItem<ProcessingSchedule>(scheduleTableName, { userId, scheduleId }))?.createdAt || now : now,
      updatedAt: now,
    };

    await putItem(scheduleTableName, schedule);

    // Create/update EventBridge Scheduler rule
    const scheduleName = `nugget-auto-process-${userId}`;
    const autoProcessFunctionArn = `arn:aws:lambda:${process.env.AWS_REGION || 'eu-west-1'}:${process.env.AWS_ACCOUNT_ID}:function:nugget-${process.env.STAGE || 'dev'}-autoProcessNuggets`;
    const scheduleRoleArn = process.env.EVENTBRIDGE_SCHEDULER_ROLE_ARN || `arn:aws:iam::${process.env.AWS_ACCOUNT_ID}:role/EventBridgeSchedulerRole`;

    const scheduleConfig = {
      Name: scheduleName,
      ScheduleExpression: frequencyToCron(request.frequency, request.preferredTime, request.timezone),
      ScheduleExpressionTimezone: request.timezone,
      FlexibleTimeWindow: {
        Mode: 'OFF' as const,
      },
      Target: {
        Arn: autoProcessFunctionArn,
        RoleArn: scheduleRoleArn,
        Input: JSON.stringify({ userId }),
      },
      State: 'ENABLED' as const,
    };

    try {
      // Check if schedule exists
      try {
        await scheduler.send(new GetScheduleCommand({ Name: scheduleName }));
        // Update existing schedule
        await scheduler.send(new UpdateScheduleCommand(scheduleConfig));
        console.log(`Updated EventBridge schedule: ${scheduleName}`);
      } catch (err: any) {
        if (err.name === 'ResourceNotFoundException') {
          // Create new schedule
          await scheduler.send(new CreateScheduleCommand(scheduleConfig));
          console.log(`Created EventBridge schedule: ${scheduleName}`);
        } else {
          throw err;
        }
      }
    } catch (err) {
      console.error('Error creating/updating EventBridge schedule:', err);
      return {
        statusCode: 500,
        body: JSON.stringify({
          error: 'Failed to configure schedule. Please ensure EventBridge Scheduler permissions are set up correctly.'
        }),
      };
    }

    // Update user record
    await updateItem(TableNames.users, { userId }, {
      autoProcessEnabled: true,
      processingScheduleId: scheduleId,
    });

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Auto-processing schedule configured',
        schedule: {
          scheduleId,
          frequency: request.frequency,
          preferredTime: request.preferredTime,
          timezone: request.timezone,
          enabled: true,
          nextRun,
        },
      }),
    };
  } catch (error) {
    console.error('Error in setProcessingSchedule handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

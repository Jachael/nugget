import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { SchedulerClient, CreateScheduleCommand, UpdateScheduleCommand, DeleteScheduleCommand, GetScheduleCommand } from '@aws-sdk/client-scheduler';
import { v4 as uuidv4 } from 'uuid';
import { createHash } from 'crypto';
import { extractUserId } from '../lib/auth';
import { getItem, putItem, updateItem, TableNames } from '../lib/dynamo';
import { User, ProcessingSchedule, ProcessingMode } from '../lib/models';
import { getEffectiveTier, getAutoProcessMode, isValidIntervalHours, PRO_PROCESSING_WINDOWS, VALID_INTERVAL_HOURS } from '../lib/subscription';

/**
 * GET /v1/processing/schedule
 * Get current processing schedule for user
 */
export async function getScheduleHandler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    // Get user
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    const effectiveTier = getEffectiveTier(user);
    const autoProcessMode = getAutoProcessMode(user);

    // Check if user has a schedule
    if (!user.processingScheduleId) {
      return {
        statusCode: 200,
        body: JSON.stringify({
          enabled: false,
          tier: effectiveTier,
          processingMode: autoProcessMode === 'none' ? null : autoProcessMode,
        }),
      };
    }

    // Get the schedule record
    const scheduleTableName = process.env.NUGGET_SCHEDULES_TABLE || `nugget-schedules-${process.env.STAGE || 'dev'}`;
    const schedule = await getItem<ProcessingSchedule>(scheduleTableName, {
      userId,
      scheduleId: user.processingScheduleId,
    });

    if (!schedule) {
      return {
        statusCode: 200,
        body: JSON.stringify({
          enabled: user.autoProcessEnabled || false,
          tier: effectiveTier,
          processingMode: autoProcessMode === 'none' ? null : autoProcessMode,
        }),
      };
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        scheduleId: schedule.scheduleId,
        frequency: schedule.frequency,
        preferredTime: schedule.preferredTime,
        timezone: schedule.timezone,
        enabled: schedule.enabled,
        nextRun: schedule.nextRun,
        processingMode: schedule.processingMode,
        intervalHours: schedule.intervalHours,
        tier: effectiveTier,
      }),
    };
  } catch (error) {
    console.error('Error in getScheduleHandler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

const scheduler = new SchedulerClient({ region: process.env.AWS_REGION || 'eu-west-1' });

interface SetScheduleRequest {
  enabled: boolean;
  frequency?: 'daily' | 'twice_daily' | 'weekly' | 'interval';
  preferredTime?: string; // "09:00" format
  timezone?: string; // IANA timezone
  intervalHours?: number; // 2, 4, 6, 8, or 12 (Ultimate only)
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
 * Create cron expression for Pro tier windows (3x daily at fixed times)
 * Morning: 7:30 AM, Afternoon: 1:30 PM, Evening: 7:30 PM
 */
function createProWindowsCron(): string {
  const { morning, afternoon, evening } = PRO_PROCESSING_WINDOWS;
  // Cron: run at minutes 30 at hours 7, 13, and 19
  return `cron(${morning.minute} ${morning.hour},${afternoon.hour},${evening.hour} * * ? *)`;
}

/**
 * Create cron expression for Ultimate tier intervals
 * Runs every N hours starting from midnight
 */
function createIntervalCron(intervalHours: number): string {
  const hours: number[] = [];
  for (let h = 0; h < 24; h += intervalHours) {
    hours.push(h);
  }
  return `cron(0 ${hours.join(',')} * * ? *)`;
}

/**
 * Create a short hash of userId for schedule names
 * EventBridge Scheduler has a 64 character limit for names
 */
function hashUserId(userId: string): string {
  return createHash('sha256').update(userId).digest('hex').substring(0, 16);
}

/**
 * Get schedule name based on tier and mode
 * Uses hashed userId to stay within 64 char limit
 */
function getScheduleName(userId: string): string {
  // nugget-auto-process- (19 chars) + hash (16 chars) = 35 chars total
  return `nugget-auto-process-${hashUserId(userId)}`;
}

/**
 * Get feed fetch schedule name
 */
function getFeedFetchScheduleName(userId: string): string {
  // nugget-feed-fetch- (17 chars) + hash (16 chars) = 33 chars total
  return `nugget-feed-fetch-${hashUserId(userId)}`;
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
    const effectiveTier = getEffectiveTier(user);
    const autoProcessMode = getAutoProcessMode(user);

    if (autoProcessMode === 'none') {
      return {
        statusCode: 403,
        body: JSON.stringify({
          error: 'Auto-processing requires a Pro or Ultimate subscription',
          upgradeRequired: true,
        }),
      };
    }

    // If disabling, delete the schedules
    if (!request.enabled) {
      if (user.processingScheduleId) {
        const scheduleName = getScheduleName(userId);
        const feedFetchScheduleName = getFeedFetchScheduleName(userId);

        try {
          // Delete EventBridge schedules
          await scheduler.send(new DeleteScheduleCommand({
            Name: scheduleName,
          }));
          console.log(`Deleted schedule: ${scheduleName}`);
        } catch (err) {
          console.error('Error deleting EventBridge schedule:', err);
          // Continue even if schedule deletion fails
        }

        try {
          await scheduler.send(new DeleteScheduleCommand({
            Name: feedFetchScheduleName,
          }));
          console.log(`Deleted schedule: ${feedFetchScheduleName}`);
        } catch (err) {
          console.error('Error deleting feed fetch schedule:', err);
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

    // Timezone is always required
    if (!request.timezone) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          error: 'timezone is required when enabling auto-processing'
        }),
      };
    }

    // Tier-specific validation
    let processingMode: ProcessingMode;
    let cronExpression: string;
    let frequency: 'daily' | 'twice_daily' | 'weekly' | 'interval';
    let intervalHours: number | undefined;
    let preferredTime: string;

    if (autoProcessMode === 'windows') {
      // Pro tier: Fixed windows (3x daily), no user configuration needed
      processingMode = 'windows';
      frequency = 'daily'; // Stored as daily but runs 3x
      cronExpression = createProWindowsCron();
      preferredTime = `${PRO_PROCESSING_WINDOWS.morning.hour.toString().padStart(2, '0')}:${PRO_PROCESSING_WINDOWS.morning.minute.toString().padStart(2, '0')}`;
      console.log(`Pro user ${userId}: Setting up fixed windows schedule (7:30am, 1:30pm, 7:30pm)`);
    } else if (autoProcessMode === 'interval') {
      // Ultimate tier: Configurable intervals
      if (!request.intervalHours) {
        return {
          statusCode: 400,
          body: JSON.stringify({
            error: 'intervalHours is required for Ultimate tier auto-processing',
            validIntervals: VALID_INTERVAL_HOURS,
          }),
        };
      }

      if (!isValidIntervalHours(request.intervalHours)) {
        return {
          statusCode: 400,
          body: JSON.stringify({
            error: `Invalid intervalHours. Must be one of: ${VALID_INTERVAL_HOURS.join(', ')}`,
            validIntervals: VALID_INTERVAL_HOURS,
          }),
        };
      }

      processingMode = 'interval';
      frequency = 'interval';
      intervalHours = request.intervalHours;
      cronExpression = createIntervalCron(intervalHours);
      preferredTime = '00:00'; // Starts at midnight for intervals
      console.log(`Ultimate user ${userId}: Setting up interval schedule (every ${intervalHours} hours)`);
    } else {
      // Fallback to legacy behavior if needed
      if (!request.frequency || !request.preferredTime) {
        return {
          statusCode: 400,
          body: JSON.stringify({
            error: 'frequency and preferredTime are required when enabling auto-processing'
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

      processingMode = 'windows';
      frequency = request.frequency;
      preferredTime = request.preferredTime;
      cronExpression = frequencyToCron(frequency, preferredTime, request.timezone);
    }

    const scheduleTableName = process.env.NUGGET_SCHEDULES_TABLE || `nugget-schedules-${process.env.STAGE || 'dev'}`;
    const now = Math.floor(Date.now() / 1000);
    const scheduleId = user.processingScheduleId || `schedule-${uuidv4()}`;
    const nextRunTimestamp = calculateNextRun(frequency === 'interval' ? 'daily' : frequency, preferredTime, request.timezone);
    const nextRun = new Date(nextRunTimestamp * 1000).toISOString();

    // Create or update schedule record
    const schedule: ProcessingSchedule = {
      userId,
      scheduleId,
      frequency,
      preferredTime,
      timezone: request.timezone,
      enabled: true,
      nextRun,
      createdAt: user.processingScheduleId ? (await getItem<ProcessingSchedule>(scheduleTableName, { userId, scheduleId }))?.createdAt || now : now,
      updatedAt: now,
      processingMode,
      intervalHours,
    };

    await putItem(scheduleTableName, schedule);

    // Create/update EventBridge Scheduler rule
    const scheduleName = getScheduleName(userId);
    const autoProcessFunctionArn = `arn:aws:lambda:${process.env.AWS_REGION || 'eu-west-1'}:${process.env.AWS_ACCOUNT_ID}:function:nugget-${process.env.STAGE || 'dev'}-autoProcessNuggets`;
    const scheduleRoleArn = process.env.EVENTBRIDGE_SCHEDULER_ROLE_ARN || `arn:aws:iam::${process.env.AWS_ACCOUNT_ID}:role/EventBridgeSchedulerRole`;

    const scheduleConfig = {
      Name: scheduleName,
      ScheduleExpression: cronExpression,
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

    // Also create schedule for RSS feed fetching
    const feedFetchScheduleName = getFeedFetchScheduleName(userId);
    const autoFetchFunctionArn = `arn:aws:lambda:${process.env.AWS_REGION || 'eu-west-1'}:${process.env.AWS_ACCOUNT_ID}:function:nugget-${process.env.STAGE || 'dev'}-autoFetchFeeds`;

    const feedFetchConfig = {
      Name: feedFetchScheduleName,
      ScheduleExpression: cronExpression,
      ScheduleExpressionTimezone: request.timezone,
      FlexibleTimeWindow: {
        Mode: 'OFF' as const,
      },
      Target: {
        Arn: autoFetchFunctionArn,
        RoleArn: scheduleRoleArn,
        Input: JSON.stringify({ userId }),
      },
      State: 'ENABLED' as const,
    };

    try {
      // Create/update auto-process schedule
      try {
        await scheduler.send(new GetScheduleCommand({ Name: scheduleName }));
        await scheduler.send(new UpdateScheduleCommand(scheduleConfig));
        console.log(`Updated EventBridge schedule: ${scheduleName}`);
      } catch (err: any) {
        if (err.name === 'ResourceNotFoundException') {
          await scheduler.send(new CreateScheduleCommand(scheduleConfig));
          console.log(`Created EventBridge schedule: ${scheduleName}`);
        } else {
          throw err;
        }
      }

      // Create/update feed fetch schedule
      try {
        await scheduler.send(new GetScheduleCommand({ Name: feedFetchScheduleName }));
        await scheduler.send(new UpdateScheduleCommand(feedFetchConfig));
        console.log(`Updated EventBridge schedule: ${feedFetchScheduleName}`);
      } catch (err: any) {
        if (err.name === 'ResourceNotFoundException') {
          await scheduler.send(new CreateScheduleCommand(feedFetchConfig));
          console.log(`Created EventBridge schedule: ${feedFetchScheduleName}`);
        } else {
          throw err;
        }
      }
    } catch (err) {
      console.error('Error creating/updating EventBridge schedules:', err);
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
          frequency,
          preferredTime,
          timezone: request.timezone,
          enabled: true,
          nextRun,
          processingMode,
          intervalHours,
          tier: effectiveTier,
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

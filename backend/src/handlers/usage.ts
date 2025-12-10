import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, TableNames } from '../lib/dynamo';
import { User } from '../lib/models';
import {
  getEffectiveTier,
  getDailyNuggetLimit,
  getDailySwipeSessionLimit,
  getMaxRSSFeeds,
  getMaxCustomRSSFeeds,
  getMaxFriendsLimit,
  getLimitsForTier
} from '../lib/subscription';

// Get today's date in UTC as YYYY-MM-DD
function getTodayUTC(): string {
  return new Date().toISOString().split('T')[0];
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    // Extract and verify user
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

    const tier = getEffectiveTier(user);
    const limits = getLimitsForTier(tier);
    const today = getTodayUTC();

    // Get current usage, reset if new day
    const dailyUsage = user.dailyUsage;
    const isToday = dailyUsage?.date === today;

    const nuggetsCreated = isToday ? (dailyUsage?.nuggetsCreated || 0) : 0;
    const swipeSessionsStarted = isToday ? (dailyUsage?.swipeSessionsStarted || 0) : 0;

    const dailyNuggetLimit = getDailyNuggetLimit(user);
    const dailySwipeLimit = getDailySwipeSessionLimit(user);

    return {
      statusCode: 200,
      body: JSON.stringify({
        tier,
        date: today,
        usage: {
          nuggetsCreated,
          swipeSessionsStarted,
        },
        limits: {
          dailyNuggets: dailyNuggetLimit,
          dailySwipeSessions: dailySwipeLimit,
          maxRSSFeeds: getMaxRSSFeeds(user),
          maxCustomRSSFeeds: getMaxCustomRSSFeeds(user),
          maxFriends: getMaxFriendsLimit(user),
        },
        remaining: {
          nuggets: dailyNuggetLimit === -1 ? -1 : Math.max(0, dailyNuggetLimit - nuggetsCreated),
          swipeSessions: dailySwipeLimit === -1 ? -1 : Math.max(0, dailySwipeLimit - swipeSessionsStarted),
        },
        features: {
          hasAutoProcess: limits.hasAutoProcess,
          hasRSSSupport: limits.hasRSSSupport,
          hasCustomDigests: limits.hasCustomDigests,
          hasOfflineMode: limits.hasOfflineMode,
          hasReaderMode: limits.hasReaderMode,
          hasNotificationConfig: limits.hasNotificationConfig,
        },
      }),
    };
  } catch (error) {
    console.error('Error in usage handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

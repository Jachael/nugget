import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, updateItem, TableNames } from '../lib/dynamo';
import { Nugget, User } from '../lib/models';
import { computePriorityScore } from '../lib/priority';

interface MarkNuggetsReadRequest {
  nuggetIds: string[];
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

    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body is required' }),
      };
    }

    const input: MarkNuggetsReadRequest = JSON.parse(event.body);

    if (!Array.isArray(input.nuggetIds) || input.nuggetIds.length === 0) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'nuggetIds must be a non-empty array' }),
      };
    }

    const now = Date.now() / 1000;
    let markedCount = 0;

    // Update each nugget
    for (const nuggetId of input.nuggetIds) {
      const nugget = await getItem<Nugget>(TableNames.nuggets, { userId, nuggetId });
      if (!nugget) {
        continue;
      }

      const newTimesReviewed = nugget.timesReviewed + 1;
      const newPriorityScore = computePriorityScore(nugget.createdAt, newTimesReviewed);

      await updateItem(TableNames.nuggets, { userId, nuggetId }, {
        lastReviewedAt: now,
        timesReviewed: newTimesReviewed,
        priorityScore: newPriorityScore,
      });

      markedCount++;
    }

    // Update user streak
    const user = await getItem<User>(TableNames.users, { userId });
    if (user && markedCount > 0) {
      const today = new Date().toISOString().split('T')[0];
      const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

      let newStreak = user.streak;

      if (user.lastActiveDate === today) {
        // Already active today, keep streak
        newStreak = user.streak;
      } else if (user.lastActiveDate === yesterday) {
        // Active yesterday, increment streak
        newStreak = user.streak + 1;
      } else {
        // Streak broken, reset to 1
        newStreak = 1;
      }

      await updateItem(TableNames.users, { userId }, {
        lastActiveDate: today,
        streak: newStreak,
      });
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        markedCount,
      }),
    };
  } catch (error) {
    console.error('Error in markNuggetsRead handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, updateItem, TableNames } from '../lib/dynamo';
import { Session, Nugget, User } from '../lib/models';
import { computePriorityScore } from '../lib/priority';

interface CompleteSessionRequest {
  completedNuggetIds: string[];
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

    const sessionId = event.pathParameters?.sessionId;
    if (!sessionId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'sessionId is required' }),
      };
    }

    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body is required' }),
      };
    }

    const input: CompleteSessionRequest = JSON.parse(event.body);

    if (!Array.isArray(input.completedNuggetIds)) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'completedNuggetIds must be an array' }),
      };
    }

    // Verify session exists and belongs to user
    const session = await getItem<Session>(TableNames.sessions, { userId, sessionId });
    if (!session) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'Session not found' }),
      };
    }

    if (session.completedAt) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Session already completed' }),
      };
    }

    const now = Date.now() / 1000;

    // Update completed nuggets
    for (const nuggetId of input.completedNuggetIds) {
      if (!session.nuggetIds.includes(nuggetId)) {
        continue; // Skip nuggets not in this session
      }

      const nugget = await getItem<Nugget>(TableNames.nuggets, { userId, nuggetId });
      if (!nugget) {
        continue;
      }

      const newTimesReviewed = nugget.timesReviewed + 1;
      const newPriorityScore = computePriorityScore(nugget.createdAt, newTimesReviewed);

      await updateItem(TableNames.nuggets, { userId, nuggetId }, {
        status: 'completed',
        lastReviewedAt: now,
        timesReviewed: newTimesReviewed,
        priorityScore: newPriorityScore,
      });
    }

    // Update session
    await updateItem(TableNames.sessions, { userId, sessionId }, {
      completedAt: now,
      completedCount: input.completedNuggetIds.length,
    });

    // Update user streak
    const user = await getItem<User>(TableNames.users, { userId });
    if (user) {
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
        completedCount: input.completedNuggetIds.length,
      }),
    };
  } catch (error) {
    console.error('Error in completeSession handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

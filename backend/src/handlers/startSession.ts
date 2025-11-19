import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { queryItems, putItem, getItem, TableNames } from '../lib/dynamo';
import { Nugget, Session, SessionResponse, NuggetResponse, User } from '../lib/models';

interface StartSessionRequest {
  size?: number;
  category?: string;
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

    // Get user preferences
    const user = await getItem<User>(TableNames.users, { userId });
    const dailyLimit = user?.preferences?.dailyNuggetLimit || 1;
    const userInterests = user?.preferences?.interests || [];

    // Parse request
    const input: StartSessionRequest = event.body ? JSON.parse(event.body) : {};
    const requestedSize = Math.min(input.size || dailyLimit, 10); // Max 10 nuggets per session
    const size = Math.min(requestedSize, dailyLimit); // Apply daily limit
    const category = input.category;

    // Query inbox nuggets sorted by priority - only READY nuggets
    let filterExpression = 'processingState = :ready';
    const expressionAttributeValues: Record<string, unknown> = {
      ':userId': userId,
      ':ready': 'ready',
    };

    if (category) {
      filterExpression += ' AND category = :category';
      expressionAttributeValues[':category'] = category;
    } else if (userInterests.length > 0) {
      // Filter by user's interests if no specific category requested
      filterExpression += ' AND category IN (' + userInterests.map((_, i) => `:interest${i}`).join(',') + ')';
      userInterests.forEach((interest, i) => {
        expressionAttributeValues[`:interest${i}`] = interest;
      });
    }

    const nuggets = await queryItems<Nugget>({
      TableName: TableNames.nuggets,
      IndexName: 'UserPriorityIndex',
      KeyConditionExpression: 'userId = :userId',
      FilterExpression: `#status = :status AND ${filterExpression}`,
      ExpressionAttributeNames: {
        '#status': 'status',
      },
      ExpressionAttributeValues: {
        ...expressionAttributeValues,
        ':status': 'inbox',
      },
      ScanIndexForward: false, // Highest priority first
      Limit: size * 2, // Query more to account for filtering
    });

    // Take only the requested size after filtering
    const selectedNuggets = nuggets.slice(0, size);

    if (selectedNuggets.length === 0) {
      return {
        statusCode: 200,
        body: JSON.stringify({
          message: 'No nuggets available for session. Make sure you have processed nuggets that are ready.',
          sessionId: null,
          nuggets: [],
        }),
      };
    }

    // Create session
    const now = Date.now() / 1000;
    const today = new Date().toISOString().split('T')[0];
    const sessionId = uuidv4();

    const session: Session = {
      userId,
      sessionId,
      date: today,
      startedAt: now,
      nuggetIds: selectedNuggets.map(n => n.nuggetId),
      completedCount: 0,
    };

    await putItem(TableNames.sessions, session);

    // Transform nuggets to response format
    const nuggetResponses: NuggetResponse[] = selectedNuggets.map(nugget => ({
      nuggetId: nugget.nuggetId,
      sourceUrl: nugget.sourceUrl,
      sourceType: nugget.sourceType,
      title: nugget.rawTitle || nugget.summary?.substring(0, 50),
      category: nugget.category,
      status: nugget.status,
      summary: nugget.summary,
      keyPoints: nugget.keyPoints,
      question: nugget.question,
      createdAt: new Date(nugget.createdAt * 1000).toISOString(),
      lastReviewedAt: nugget.lastReviewedAt ? new Date(nugget.lastReviewedAt * 1000).toISOString() : undefined,
      timesReviewed: nugget.timesReviewed,
      // Include grouped nugget fields
      isGrouped: nugget.isGrouped,
      sourceNuggetIds: nugget.sourceNuggetIds,
      sourceUrls: nugget.sourceUrls,
      individualSummaries: nugget.individualSummaries,
    }));

    const response: SessionResponse = {
      sessionId,
      nuggets: nuggetResponses,
    };

    return {
      statusCode: 200,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in startSession handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

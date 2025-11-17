import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { queryItems, putItem, TableNames } from '../lib/dynamo';
import { Nugget, Session, SessionResponse, NuggetResponse } from '../lib/models';

interface StartSessionRequest {
  size?: number;
  category?: string;
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    // Extract and verify user
    const userId = extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    // Parse request
    const input: StartSessionRequest = event.body ? JSON.parse(event.body) : {};
    const size = Math.min(input.size || 3, 10); // Max 10 nuggets per session
    const category = input.category;

    // Query inbox nuggets sorted by priority
    let filterExpression: string | undefined;
    const expressionAttributeValues: Record<string, unknown> = {
      ':userId': userId,
    };

    if (category) {
      filterExpression = 'category = :category';
      expressionAttributeValues[':category'] = category;
    }

    const nuggets = await queryItems<Nugget>({
      TableName: TableNames.nuggets,
      IndexName: 'UserPriorityIndex',
      KeyConditionExpression: 'userId = :userId',
      FilterExpression: filterExpression ? `#status = :status AND ${filterExpression}` : '#status = :status',
      ExpressionAttributeNames: {
        '#status': 'status',
      },
      ExpressionAttributeValues: {
        ...expressionAttributeValues,
        ':status': 'inbox',
      },
      ScanIndexForward: false, // Highest priority first
      Limit: size,
    });

    if (nuggets.length === 0) {
      return {
        statusCode: 200,
        body: JSON.stringify({
          message: 'No nuggets available for session',
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
      nuggetIds: nuggets.map(n => n.nuggetId),
      completedCount: 0,
    };

    await putItem(TableNames.sessions, session);

    // Transform nuggets to response format
    const nuggetResponses: NuggetResponse[] = nuggets.map(nugget => ({
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

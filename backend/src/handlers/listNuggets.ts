import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { queryItems, TableNames } from '../lib/dynamo';
import { Nugget, NuggetResponse } from '../lib/models';

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

    // Get query parameters
    const status = event.queryStringParameters?.status || 'inbox';
    const category = event.queryStringParameters?.category;
    const limit = parseInt(event.queryStringParameters?.limit || '50', 10);

    // Query nuggets
    let filterExpression: string | undefined;
    let expressionAttributeValues: Record<string, unknown> = {
      ':userId': userId,
      ':status': status,
    };

    if (category) {
      filterExpression = 'category = :category';
      expressionAttributeValues[':category'] = category;
    }

    const nuggets = await queryItems<Nugget>({
      TableName: TableNames.nuggets,
      IndexName: 'UserStatusIndex',
      KeyConditionExpression: 'userId = :userId AND #status = :status',
      ExpressionAttributeNames: {
        '#status': 'status',
      },
      ExpressionAttributeValues: expressionAttributeValues,
      FilterExpression: filterExpression,
      Limit: limit,
      ScanIndexForward: false, // Most recent first
    });

    // Transform to response format
    const response: NuggetResponse[] = nuggets.map(nugget => ({
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

    return {
      statusCode: 200,
      body: JSON.stringify({ nuggets: response }),
    };
  } catch (error) {
    console.error('Error in listNuggets handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

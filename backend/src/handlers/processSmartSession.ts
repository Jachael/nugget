import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, TableNames } from '../lib/dynamo';
import { Nugget } from '../lib/models';
import { summariseGroupedContent } from '../lib/llm';

interface ProcessSmartSessionRequest {
  sessionId: string;
  nuggetIds: string[];
  query: string;
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
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

    const request: ProcessSmartSessionRequest = JSON.parse(event.body);

    // Get all the nuggets
    const nuggets = await Promise.all(
      request.nuggetIds.map(nuggetId =>
        getItem<Nugget>(TableNames.nuggets, { userId, nuggetId })
      )
    );

    const validNuggets = nuggets.filter(n => n !== null) as Nugget[];

    if (validNuggets.length === 0) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'No nuggets found' }),
      };
    }

    // Process each nugget individually first to get summaries
    const individualSummaries = await Promise.all(
      validNuggets.map(async nugget => {
        const summary = await summariseGroupedContent([{
          title: nugget.rawTitle || '',
          text: nugget.rawText || '',
          url: nugget.sourceUrl
        }]);
        return {
          nuggetId: nugget.nuggetId,
          title: nugget.rawTitle || 'Untitled',
          sourceUrl: nugget.sourceUrl,
          summary: summary.summary,
          keyPoints: summary.keyPoints,
        };
      })
    );

    // Now create a combined summary based on the query
    const combinedContent = validNuggets.map(n => ({
      title: n.rawTitle || '',
      text: n.rawText || '',
      url: n.sourceUrl
    }));

    const groupedSummary = await summariseGroupedContent(combinedContent);

    // Create the response with both grouped and individual summaries
    const response = {
      sessionId: request.sessionId,
      query: request.query,
      groupedSummary: {
        title: `${request.query} - ${validNuggets.length} articles`,
        summary: groupedSummary.summary,
        keyPoints: groupedSummary.keyPoints,
        question: groupedSummary.question,
        sourceCount: validNuggets.length,
      },
      individualSummaries,
      processingComplete: true,
    };

    return {
      statusCode: 200,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in processSmartSession:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}
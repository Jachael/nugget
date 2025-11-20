import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, updateItem, putItem, TableNames } from '../lib/dynamo';
import { Session, Nugget, SessionResponse } from '../lib/models';
import { summariseGroupedContent } from '../lib/llm';

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
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
        body: JSON.stringify({ error: 'Session ID is required' }),
      };
    }

    // Get the session
    const session = await getItem<Session>(TableNames.sessions, { userId, sessionId });
    if (!session) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'Session not found' }),
      };
    }

    // Get all nuggets for this session
    const nuggetPromises = session.nuggetIds.map(nuggetId =>
      getItem<Nugget>(TableNames.nuggets, { userId, nuggetId })
    );

    const nuggets = await Promise.all(nuggetPromises);
    const validNuggets = nuggets.filter(n => n !== null) as Nugget[];

    // Check if all nuggets are processed
    const allProcessed = validNuggets.every(n => n.summary && n.summary !== 'Processing...');
    const processedCount = validNuggets.filter(n => n.summary && n.summary !== 'Processing...').length;

    // Create grouped response
    const groupedNuggetId = `group-${sessionId}`;

    // Default values for processing state
    let combinedSummary = `Processing ${processedCount}/${validNuggets.length} articles...`;
    let combinedKeyPoints: string[] = [];
    let combinedQuestion = 'Processing your content...';

    // Generate a better title based on content
    let sessionTitle = 'Session Results';
    if (validNuggets.length > 0) {
      const categories = [...new Set(validNuggets.map(n => n.category).filter(Boolean))];
      if (categories.length === 1 && categories[0]) {
        sessionTitle = `${categories[0].charAt(0).toUpperCase() + categories[0].slice(1)} Insights`;
      } else if (validNuggets.length === 1) {
        sessionTitle = validNuggets[0].title || validNuggets[0].rawTitle || 'Nugget';
      } else {
        sessionTitle = `${validNuggets.length} Articles Summary`;
      }
    }

    // Check if we have a cached synthesis
    let cachedSynthesis = session.synthesis;

    if (allProcessed) {
      // Only generate synthesis once
      if (!cachedSynthesis) {
        try {
          // Prepare content for AI synthesis - using summaries as the text
          const articlesContent = validNuggets.map(n => ({
            title: n.title || n.rawTitle || 'Untitled',
            text: n.summary || '',
            url: n.sourceUrl
          }));

          // Generate AI synthesis of all articles
          const synthesis = await summariseGroupedContent(articlesContent);

          combinedSummary = synthesis.summary;
          combinedKeyPoints = synthesis.keyPoints || [];
          combinedQuestion = synthesis.question || 'Based on these insights, what specific aspect would you like to explore further?';

          // Cache the synthesis in the session
          await updateItem(
            TableNames.sessions,
            { userId, sessionId },
            {
              synthesis: {
                summary: combinedSummary,
                keyPoints: combinedKeyPoints,
                question: combinedQuestion,
                generatedAt: Date.now()
              }
            }
          );

          // Save the grouped nugget to the database so it appears in Recent Nuggets
          const groupedNugget: Nugget = {
            userId,
            nuggetId: groupedNuggetId,
            sourceUrl: '', // No single source for grouped nuggets
            sourceType: 'other',
            title: synthesis.title || sessionTitle,
            rawTitle: sessionTitle,
            status: 'inbox',
            processingState: 'ready',
            category: validNuggets[0]?.category || 'mixed',
            summary: combinedSummary,
            keyPoints: combinedKeyPoints,
            question: combinedQuestion,
            priorityScore: Math.max(...validNuggets.map(n => n.priorityScore || 0)),
            createdAt: Date.now() / 1000,
            timesReviewed: 0,
            isGrouped: true,
            sourceUrls: validNuggets.map(n => n.sourceUrl),
            individualSummaries: validNuggets.map(nugget => ({
              nuggetId: nugget.nuggetId,
              title: nugget.title || nugget.rawTitle || 'Untitled',
              sourceUrl: nugget.sourceUrl,
              summary: nugget.summary || '',
              keyPoints: nugget.keyPoints || [],
            })),
          };

          await putItem(TableNames.nuggets, groupedNugget);
        } catch (error) {
          console.error('Error generating synthesis:', error);
          // Fallback to simple aggregation if AI synthesis fails
          const allKeyPoints = validNuggets.flatMap(n => n.keyPoints || []);
          combinedSummary = `Analyzed ${validNuggets.length} articles. Key topics covered: ${validNuggets.map(n => n.title || n.rawTitle).filter(Boolean).join(', ')}`;
          combinedKeyPoints = allKeyPoints.slice(0, 5);
          combinedQuestion = 'Based on these insights, what specific aspect would you like to explore further?';
        }
      } else {
        // Use cached synthesis
        combinedSummary = cachedSynthesis.summary;
        combinedKeyPoints = cachedSynthesis.keyPoints || [];
        combinedQuestion = cachedSynthesis.question || 'Based on these insights, what specific aspect would you like to explore further?';
      }
    }

    const response: SessionResponse = {
      sessionId: session.sessionId,
      nuggets: [{
        nuggetId: groupedNuggetId,
        sourceUrl: '',
        sourceType: 'grouped',
        title: sessionTitle,
        category: validNuggets[0]?.category || 'mixed',
        status: allProcessed ? 'processed' : 'processing',
        createdAt: new Date().toISOString(),
        timesReviewed: 0,
        isGrouped: true,
        sourceUrls: validNuggets.map(n => n.sourceUrl),
        summary: combinedSummary,
        keyPoints: combinedKeyPoints,
        question: combinedQuestion,
        individualSummaries: validNuggets.map(nugget => ({
          nuggetId: nugget.nuggetId,
          title: nugget.title || nugget.rawTitle || 'Untitled',
          sourceUrl: nugget.sourceUrl,
          summary: nugget.summary || 'Processing...',
          keyPoints: nugget.keyPoints || [],
        })),
      }],
    };

    return {
      statusCode: 200,
      body: JSON.stringify({
        ...response,
        processingComplete: allProcessed,
        processedCount,
        totalCount: validNuggets.length,
      }),
    };
  } catch (error) {
    console.error('Error in getSessionStatus:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}
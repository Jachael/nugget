import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { queryItems, putItem, TableNames } from '../lib/dynamo';
import { Nugget, Session, SessionResponse } from '../lib/models';
import { invokeSummariseNugget } from '../lib/invoke';

interface SmartSessionRequest {
  query: string; // Natural language query like "tech from this week"
  limit?: number; // Max nuggets to process (default 5)
}

interface ParsedQuery {
  category?: string;
  timeFilter?: 'today' | 'week' | 'month';
  contentType?: 'quick' | 'deep' | 'any';
}

/**
 * Parse natural language query into filters
 */
function parseQuery(query: string): ParsedQuery {
  const lowerQuery = query.toLowerCase();
  const parsed: ParsedQuery = {};

  // Detect categories
  const categories = {
    tech: ['tech', 'technology', 'software', 'ai', 'coding'],
    career: ['career', 'job', 'work', 'professional'],
    finance: ['finance', 'money', 'market', 'investment', 'crypto'],
    health: ['health', 'fitness', 'wellness', 'medical'],
    science: ['science', 'research', 'study'],
    business: ['business', 'startup', 'entrepreneur'],
    sport: ['sport', 'sports', 'game', 'match'],
  };

  for (const [category, keywords] of Object.entries(categories)) {
    if (keywords.some(keyword => lowerQuery.includes(keyword))) {
      parsed.category = category;
      break;
    }
  }

  // Detect time filters
  if (lowerQuery.includes('today') || lowerQuery.includes("today's")) {
    parsed.timeFilter = 'today';
  } else if (lowerQuery.includes('week') || lowerQuery.includes('weekly')) {
    parsed.timeFilter = 'week';
  } else if (lowerQuery.includes('month') || lowerQuery.includes('monthly')) {
    parsed.timeFilter = 'month';
  }

  // Detect content type
  if (lowerQuery.includes('quick') || lowerQuery.includes('short') || lowerQuery.includes('5 min')) {
    parsed.contentType = 'quick';
  } else if (lowerQuery.includes('deep') || lowerQuery.includes('detailed') || lowerQuery.includes('long')) {
    parsed.contentType = 'deep';
  }

  return parsed;
}

/**
 * Filter nuggets based on parsed query
 */
function filterNuggets(nuggets: Nugget[], query: ParsedQuery): Nugget[] {
  return nuggets.filter(nugget => {
    // Only unprocessed nuggets
    if (nugget.summary) return false;

    // Category filter
    if (query.category) {
      // Check if nugget category matches
      if (nugget.category !== query.category) {
        // Also check title and description for category keywords
        const content = `${nugget.rawTitle} ${nugget.rawDescription || ''}`.toLowerCase();
        const categoryKeywords = {
          tech: ['tech', 'software', 'ai', 'app', 'digital'],
          career: ['career', 'job', 'work', 'hire', 'interview'],
          finance: ['money', 'stock', 'invest', 'market', 'crypto'],
          health: ['health', 'fitness', 'medical', 'wellness'],
          science: ['science', 'research', 'study', 'discover'],
          business: ['business', 'company', 'startup', 'revenue'],
          sport: ['sport', 'game', 'team', 'player', 'match'],
        };

        const keywords = categoryKeywords[query.category as keyof typeof categoryKeywords] || [];
        if (!keywords.some(keyword => content.includes(keyword))) {
          return false;
        }
      }
    }

    // Time filter
    if (query.timeFilter) {
      const now = Date.now() / 1000;
      const nuggetAge = now - nugget.createdAt;
      const day = 86400; // seconds in a day

      switch (query.timeFilter) {
        case 'today':
          if (nuggetAge > day) return false;
          break;
        case 'week':
          if (nuggetAge > day * 7) return false;
          break;
        case 'month':
          if (nuggetAge > day * 30) return false;
          break;
      }
    }

    // Content type filter (estimate based on raw text length)
    if (query.contentType && nugget.rawText) {
      const wordCount = nugget.rawText.split(/\s+/).length;

      switch (query.contentType) {
        case 'quick':
          if (wordCount > 500) return false;
          break;
        case 'deep':
          if (wordCount < 500) return false;
          break;
      }
    }

    return true;
  });
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

    const request: SmartSessionRequest = JSON.parse(event.body);

    if (!request.query) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Query is required' }),
      };
    }

    const limit = request.limit || 5;

    // Parse the query
    const parsedQuery = parseQuery(request.query);

    // Get all unprocessed nuggets for the user
    const nuggets = await queryItems<Nugget>({
      TableName: TableNames.nuggets,
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId,
      },
    });

    // Filter based on query
    const matchingNuggets = filterNuggets(nuggets, parsedQuery);

    if (matchingNuggets.length === 0) {
      return {
        statusCode: 404,
        body: JSON.stringify({
          error: 'No matching unprocessed content found',
          suggestion: 'Try a broader query or save more content first'
        }),
      };
    }

    // Sort by priority and take the limit
    const nuggetsToProcess = matchingNuggets
      .sort((a, b) => b.priorityScore - a.priorityScore)
      .slice(0, limit);

    // Create session
    const sessionId = uuidv4();
    const now = Date.now() / 1000;
    const today = new Date().toISOString().split('T')[0];

    const session: Session = {
      userId,
      sessionId,
      date: today,
      startedAt: now,
      nuggetIds: nuggetsToProcess.map(n => n.nuggetId),
      completedCount: 0,
    };

    await putItem(TableNames.sessions, session);

    // Process nuggets in parallel
    const processPromises = nuggetsToProcess.map(nugget =>
      invokeSummariseNugget(nugget.nuggetId, userId)
    );

    await Promise.allSettled(processPromises);

    // Transform to response format with processed summaries
    const response: SessionResponse = {
      sessionId: session.sessionId,
      nuggets: nuggetsToProcess.map(nugget => ({
        nuggetId: nugget.nuggetId,
        sourceUrl: nugget.sourceUrl,
        sourceType: nugget.sourceType,
        title: nugget.rawTitle,
        category: nugget.category,
        status: nugget.status,
        createdAt: new Date(nugget.createdAt * 1000).toISOString(),
        timesReviewed: nugget.timesReviewed,
        // These will be populated by the summarization Lambda
        summary: 'Processing...',
        keyPoints: [],
        question: 'Processing...',
      })),
    };

    return {
      statusCode: 200,
      body: JSON.stringify({
        ...response,
        query: request.query,
        parsed: parsedQuery,
        totalMatches: matchingNuggets.length,
        processed: nuggetsToProcess.length,
      }),
    };
  } catch (error) {
    console.error('Error in createSmartSession handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}
import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { queryItems, putItem, TableNames } from '../lib/dynamo';
import { Nugget, Session, SessionResponse, NuggetResponse } from '../lib/models';

interface SmartSessionRequest {
  query: string; // Natural language query like "catch me up on tech"
  limit?: number; // Max nuggets to return (default 10)
}

interface ParsedQuery {
  category?: string;
  timeFilter?: 'today' | 'yesterday' | 'week' | 'month';
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
    tech: ['tech', 'technology', 'software', 'ai', 'coding', 'programming', 'developer'],
    career: ['career', 'job', 'work', 'professional', 'hiring'],
    finance: ['finance', 'money', 'market', 'investment', 'crypto', 'stocks', 'trading'],
    health: ['health', 'fitness', 'wellness', 'medical', 'nutrition'],
    science: ['science', 'research', 'study', 'discovery'],
    business: ['business', 'startup', 'entrepreneur', 'company'],
    sport: ['sport', 'sports', 'game', 'match', 'football', 'soccer', 'basketball'],
    news: ['news', 'headlines', 'breaking', 'current events'],
    entertainment: ['entertainment', 'movies', 'music', 'tv', 'celebrity'],
  };

  for (const [category, keywords] of Object.entries(categories)) {
    if (keywords.some(keyword => lowerQuery.includes(keyword))) {
      parsed.category = category;
      break;
    }
  }

  // Detect time filters - check yesterday before today to avoid false matches
  if (lowerQuery.includes('yesterday') || lowerQuery.includes("yesterday's")) {
    parsed.timeFilter = 'yesterday';
  } else if (lowerQuery.includes('today') || lowerQuery.includes("today's")) {
    parsed.timeFilter = 'today';
  } else if (lowerQuery.includes('week') || lowerQuery.includes('weekly') || lowerQuery.includes('this week')) {
    parsed.timeFilter = 'week';
  } else if (lowerQuery.includes('month') || lowerQuery.includes('monthly') || lowerQuery.includes('this month')) {
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
 * Filter nuggets based on parsed query - only UNREAD PROCESSED nuggets
 */
function filterNuggets(nuggets: Nugget[], query: ParsedQuery): Nugget[] {
  return nuggets.filter(nugget => {
    // Only processed nuggets (have a summary)
    if (!nugget.summary) return false;

    // Only unread nuggets (timesReviewed === 0)
    if (nugget.timesReviewed > 0) return false;

    // Only inbox status
    if (nugget.status !== 'inbox') return false;

    // Category filter
    if (query.category) {
      // Check if nugget category matches (case insensitive)
      const nuggetCategory = nugget.category?.toLowerCase();
      if (nuggetCategory !== query.category.toLowerCase()) {
        // Also check title for category keywords as fallback
        const title = (nugget.title || nugget.rawTitle || '').toLowerCase();
        const categoryKeywords = {
          tech: ['tech', 'software', 'ai', 'app', 'digital', 'code'],
          career: ['career', 'job', 'work', 'hire', 'interview'],
          finance: ['money', 'stock', 'invest', 'market', 'crypto', 'finance'],
          health: ['health', 'fitness', 'medical', 'wellness'],
          science: ['science', 'research', 'study', 'discover'],
          business: ['business', 'company', 'startup', 'revenue'],
          sport: ['sport', 'game', 'team', 'player', 'match', 'football', 'soccer'],
          news: ['news', 'headline', 'breaking'],
          entertainment: ['movie', 'music', 'tv', 'celebrity', 'entertainment'],
        };

        const keywords = categoryKeywords[query.category as keyof typeof categoryKeywords] || [];
        if (!keywords.some(keyword => title.includes(keyword))) {
          return false;
        }
      }
    }

    // Time filter - use calendar days
    if (query.timeFilter) {
      const nuggetDate = new Date(nugget.createdAt * 1000);
      const now = new Date();

      // Get start of today (midnight)
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      // Get start of yesterday
      const yesterdayStart = new Date(todayStart);
      yesterdayStart.setDate(yesterdayStart.getDate() - 1);
      // Get start of this week (Monday)
      const weekStart = new Date(todayStart);
      weekStart.setDate(weekStart.getDate() - weekStart.getDay() + (weekStart.getDay() === 0 ? -6 : 1));
      // Get start of this month
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

      switch (query.timeFilter) {
        case 'today':
          if (nuggetDate < todayStart) return false;
          break;
        case 'yesterday':
          // Nugget must be from yesterday or today (recent)
          if (nuggetDate < yesterdayStart) return false;
          break;
        case 'week':
          if (nuggetDate < weekStart) return false;
          break;
        case 'month':
          if (nuggetDate < monthStart) return false;
          break;
      }
    }

    return true;
  });
}

/**
 * Convert a Nugget to NuggetResponse format
 */
function toNuggetResponse(nugget: Nugget): NuggetResponse {
  return {
    nuggetId: nugget.nuggetId,
    sourceUrl: nugget.sourceUrl,
    sourceType: nugget.sourceType,
    title: nugget.title || nugget.rawTitle || '',
    category: nugget.category,
    status: nugget.status,
    createdAt: new Date(nugget.createdAt * 1000).toISOString(),
    timesReviewed: nugget.timesReviewed,
    summary: nugget.summary,
    keyPoints: nugget.keyPoints,
    question: nugget.question,
    isGrouped: nugget.isGrouped,
    sourceUrls: nugget.sourceUrls,
    individualSummaries: nugget.individualSummaries,
  };
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

    const limit = request.limit || 10;

    // Parse the query
    const parsedQuery = parseQuery(request.query);

    console.log(`Smart session query: "${request.query}" -> parsed:`, parsedQuery);

    // Get all nuggets for the user
    const nuggets = await queryItems<Nugget>({
      TableName: TableNames.nuggets,
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId,
      },
    });

    console.log(`Found ${nuggets.length} total nuggets for user`);

    // Filter to unread processed nuggets matching the query
    const matchingNuggets = filterNuggets(nuggets, parsedQuery);

    console.log(`Found ${matchingNuggets.length} matching unread processed nuggets`);

    if (matchingNuggets.length === 0) {
      // Build a helpful message
      let message = "You're all caught up!";
      if (parsedQuery.category) {
        message = `No unread ${parsedQuery.category} nuggets found.`;
      }
      if (parsedQuery.timeFilter) {
        const timeLabel = parsedQuery.timeFilter === 'today' ? 'from today' :
                         parsedQuery.timeFilter === 'yesterday' ? 'from yesterday' :
                         parsedQuery.timeFilter === 'week' ? 'this week' :
                         'this month';
        message = `No unread nuggets ${timeLabel}${parsedQuery.category ? ` in ${parsedQuery.category}` : ''}.`;
      }

      return {
        statusCode: 200,
        body: JSON.stringify({
          sessionId: null,
          nuggets: [],
          message,
          query: request.query,
          parsed: parsedQuery,
          totalMatches: 0,
        }),
      };
    }

    // Sort by creation date (newest first) and take the limit
    const nuggetsToReturn = matchingNuggets
      .sort((a, b) => b.createdAt - a.createdAt)
      .slice(0, limit);

    // Create a session for tracking
    const sessionId = uuidv4();
    const now = Date.now() / 1000;
    const today = new Date().toISOString().split('T')[0];

    const session: Session = {
      userId,
      sessionId,
      date: today,
      startedAt: now,
      nuggetIds: nuggetsToReturn.map(n => n.nuggetId),
      completedCount: 0,
    };

    await putItem(TableNames.sessions, session);

    // Convert nuggets to response format
    const nuggetResponses = nuggetsToReturn.map(toNuggetResponse);

    const response: SessionResponse = {
      sessionId: session.sessionId,
      nuggets: nuggetResponses,
    };

    return {
      statusCode: 200,
      body: JSON.stringify({
        ...response,
        query: request.query,
        parsed: parsedQuery,
        totalMatches: matchingNuggets.length,
        returned: nuggetsToReturn.length,
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

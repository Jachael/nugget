import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { queryItems, putItem, updateItem, TableNames } from '../lib/dynamo';
import { Nugget, Session, SessionResponse } from '../lib/models';

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

    // DON'T process individual nuggets - we want only the grouped nugget
    // Mark the original nuggets as being part of a session so they don't show as unprocessed
    const updatePromises = nuggetsToProcess.map(nugget =>
      updateItem(
        TableNames.nuggets,
        { userId, nuggetId: nugget.nuggetId },
        {
          status: 'archived', // Archive them since they're now part of a grouped session
          sessionId: sessionId
        }
      )
    );

    await Promise.all(updatePromises);

    // For now, just use the nuggets as-is without processing
    const validUpdatedNuggets = nuggetsToProcess;

    // Group the nuggets into a combined session
    // This creates a single "super nugget" that contains all the matched articles
    const groupedNuggetId = `group-${sessionId}`;

    // Generate a better title for the grouped nugget
    let groupTitle = request.query;
    if (parsedQuery.category && parsedQuery.timeFilter) {
      const timeLabel = parsedQuery.timeFilter === 'today' ? "Today's" :
                       parsedQuery.timeFilter === 'week' ? 'This Week in' :
                       'This Month in';
      groupTitle = `${timeLabel} ${parsedQuery.category.charAt(0).toUpperCase() + parsedQuery.category.slice(1)}`;
    }

    // Create and save the grouped nugget to the database immediately
    const groupedNugget: Nugget = {
      userId,
      nuggetId: groupedNuggetId,
      sourceUrl: '', // No single source for grouped nuggets
      sourceType: 'other',
      title: groupTitle,
      rawTitle: groupTitle,
      category: parsedQuery.category || 'mixed',
      status: 'inbox', // Mark as inbox since it's ready to be processed
      createdAt: now,
      priorityScore: 100, // High priority for grouped nuggets
      timesReviewed: 0,
      processingState: 'ready', // Mark as ready since it's a grouped nugget
      // Mark as grouped and include all source URLs
      isGrouped: true,
      sourceUrls: validUpdatedNuggets.map(n => n.sourceUrl),
      // Create a richer, more detailed summary
      summary: `You have ${validUpdatedNuggets.length} curated articles matching "${request.query}". This collection covers ${
        parsedQuery.category ? `the latest in ${parsedQuery.category}` : 'diverse topics'
      }${parsedQuery.timeFilter ? ` from ${parsedQuery.timeFilter === 'today' ? 'today' :
        parsedQuery.timeFilter === 'week' ? 'this week' : 'this month'}` : ''
      }. Here's your personalized digest with key insights, trends, and actionable takeaways from each article.`,
      keyPoints: validUpdatedNuggets.map(n => {
        const title = n.rawTitle || 'Untitled';
        const description = n.rawDescription ? ` - ${n.rawDescription.substring(0, 100)}...` : '';
        return `${title}${description}`;
      }),
      question: `Which aspect of ${parsedQuery.category || 'these topics'} interests you most?`,
      // Include individual summaries for each article (even if they're not processed yet)
      individualSummaries: validUpdatedNuggets.map(nugget => {
        const title = nugget.title || nugget.rawTitle || 'Untitled';
        const description = nugget.rawDescription || '';
        let summary = nugget.summary;

        // Create a more detailed summary if one doesn't exist
        if (!summary && description) {
          summary = `${description.substring(0, 200)}${description.length > 200 ? '...' : ''}`;
        } else if (!summary) {
          summary = `Article: "${title}" - Ready for in-depth analysis`;
        }

        return {
          nuggetId: nugget.nuggetId,
          title: title,
          sourceUrl: nugget.sourceUrl,
          summary: summary,
          keyPoints: nugget.keyPoints || (description ? [
            `Source: ${nugget.sourceUrl.includes('linkedin') ? 'LinkedIn' :
                     nugget.sourceUrl.includes('twitter') ? 'Twitter/X' :
                     new URL(nugget.sourceUrl).hostname.replace('www.', '')}`,
            `Topic: ${nugget.category || 'General'}`
          ] : []),
        };
      }),
    };

    // Save the grouped nugget to the database immediately
    await putItem(TableNames.nuggets, groupedNugget);

    const response: SessionResponse = {
      sessionId: session.sessionId,
      nuggets: [{
        nuggetId: groupedNugget.nuggetId,
        sourceUrl: groupedNugget.sourceUrl,
        sourceType: 'grouped',
        title: groupedNugget.title || '',
        category: groupedNugget.category,
        status: 'ready',
        createdAt: new Date(groupedNugget.createdAt * 1000).toISOString(),
        timesReviewed: 0,
        isGrouped: true,
        sourceUrls: groupedNugget.sourceUrls,
        summary: groupedNugget.summary,
        keyPoints: groupedNugget.keyPoints,
        question: groupedNugget.question,
        individualSummaries: groupedNugget.individualSummaries,
      }],
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
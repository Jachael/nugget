import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { getItem, putItem, updateItem, TableNames } from '../lib/dynamo';
import { Nugget, CreateNuggetInput, NuggetResponse, User, DailyUsage } from '../lib/models';
import { computePriorityScore } from '../lib/priority';
import { scrapeUrl } from '../lib/scraper';
import { getEffectiveTier, getDailyNuggetLimit } from '../lib/subscription';

// Get today's date in UTC as YYYY-MM-DD
function getTodayUTC(): string {
  return new Date().toISOString().split('T')[0];
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

    const input: CreateNuggetInput = JSON.parse(event.body);

    // Validate input
    if (!input.sourceUrl || !input.sourceType) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'sourceUrl and sourceType are required' }),
      };
    }

    const validSourceTypes = ['url', 'tweet', 'linkedin', 'youtube', 'other'];
    if (!validSourceTypes.includes(input.sourceType)) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Invalid sourceType' }),
      };
    }

    // Reject Twitter/X URLs
    if (input.sourceType === 'tweet' ||
        input.sourceUrl.includes('twitter.com/') ||
        input.sourceUrl.includes('x.com/')) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          error: 'Twitter/X URLs are not supported. Due to platform restrictions, we cannot extract content from tweets.'
        }),
      };
    }

    // Get user to check tier limits
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    // Check daily nugget limit for free tier
    const dailyLimit = getDailyNuggetLimit(user);
    const today = getTodayUTC();
    const currentUsage = user.dailyUsage;

    // Reset usage if it's a new day or doesn't exist
    let todayNuggetsCreated = 0;
    if (currentUsage && currentUsage.date === today) {
      todayNuggetsCreated = currentUsage.nuggetsCreated || 0;
    }

    // Check if limit reached (skip for unlimited tiers where dailyLimit is -1)
    if (dailyLimit !== -1 && todayNuggetsCreated >= dailyLimit) {
      const tier = getEffectiveTier(user);
      return {
        statusCode: 429,
        body: JSON.stringify({
          error: 'Daily nugget limit reached',
          code: 'DAILY_LIMIT_REACHED',
          limit: dailyLimit,
          used: todayNuggetsCreated,
          tier: tier,
          message: `You've reached your daily limit of ${dailyLimit} nuggets. Upgrade to Pro for more!`
        }),
      };
    }

    // Create nugget
    const now = Date.now() / 1000;
    const nuggetId = uuidv4();

    // Scrape content from URL (free, no AI cost)
    let scrapedContent;
    try {
      scrapedContent = await scrapeUrl(input.sourceUrl);
      console.log('Successfully scraped content from:', input.sourceUrl);
    } catch (error) {
      console.error('Failed to scrape URL:', error);
      // Continue with manual input if scraping fails
      scrapedContent = null;
    }

    const nugget: Nugget = {
      userId,
      nuggetId,
      sourceUrl: input.sourceUrl,
      sourceType: input.sourceType,
      rawTitle: scrapedContent?.title || input.rawTitle || 'Untitled',
      rawText: scrapedContent?.content || input.rawText,
      rawDescription: scrapedContent?.description,
      status: 'inbox',
      processingState: 'scraped', // New: indicate it's only been scraped, not AI processed
      category: scrapedContent?.suggestedCategory || input.category,
      priorityScore: computePriorityScore(now, 0),
      createdAt: now,
      timesReviewed: 0,
    };

    await putItem(TableNames.nuggets, nugget);

    // Update daily usage tracking
    const newUsage: DailyUsage = {
      date: today,
      nuggetsCreated: (currentUsage?.date === today ? currentUsage.nuggetsCreated : 0) + 1,
      swipeSessionsStarted: currentUsage?.date === today ? currentUsage.swipeSessionsStarted : 0,
    };

    await updateItem(
      TableNames.users,
      { userId },
      { dailyUsage: newUsage }
    );

    // NO automatic AI processing - user will trigger this manually or via session creation

    // Return response
    const response: NuggetResponse = {
      nuggetId: nugget.nuggetId,
      sourceUrl: nugget.sourceUrl,
      sourceType: nugget.sourceType,
      title: nugget.rawTitle,
      category: nugget.category,
      status: nugget.status,
      createdAt: new Date(nugget.createdAt * 1000).toISOString(),
      timesReviewed: nugget.timesReviewed,
    };

    return {
      statusCode: 201,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in createNugget handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

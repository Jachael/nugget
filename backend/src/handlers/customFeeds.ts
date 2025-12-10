import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, ScanCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb';
import { extractUserId } from '../lib/auth';
import { getItem, TableNames } from '../lib/dynamo';
import { User, CustomRSSFeed } from '../lib/models';
import { getEffectiveTier, getMaxCustomRSSFeeds } from '../lib/subscription';
import Parser from 'rss-parser';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const rssParser = new Parser();

const CUSTOM_FEEDS_TABLE = process.env.NUGGET_CUSTOM_FEEDS_TABLE || 'nugget-custom-feeds-dev';

interface AddCustomFeedRequest {
  url: string;
  name?: string;
  category?: string;
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }) };
    }

    const method = event.requestContext.http.method;
    const path = event.rawPath;

    // Check Ultimate tier for all custom feed operations
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      return { statusCode: 404, body: JSON.stringify({ error: 'User not found' }) };
    }
    const tier = getEffectiveTier(user);

    if (tier !== 'ultimate') {
      return {
        statusCode: 403,
        body: JSON.stringify({
          error: 'Ultimate subscription required',
          code: 'ULTIMATE_REQUIRED',
          message: 'Custom RSS feeds are only available to Ultimate subscribers.'
        }),
      };
    }

    // POST /v1/feeds/custom - Add custom feed
    if (method === 'POST' && path === '/v1/feeds/custom') {
      return await addCustomFeed(userId, event, user);
    }

    // GET /v1/feeds/custom - List custom feeds
    if (method === 'GET' && path === '/v1/feeds/custom') {
      return await listCustomFeeds(userId);
    }

    // DELETE /v1/feeds/custom/{feedId}
    if (method === 'DELETE') {
      const feedId = event.pathParameters?.feedId;
      return await deleteCustomFeed(userId, feedId);
    }

    // POST /v1/feeds/custom/validate - Validate a feed URL
    if (method === 'POST' && path === '/v1/feeds/custom/validate') {
      return await validateFeedUrl(event);
    }

    return { statusCode: 404, body: JSON.stringify({ error: 'Not found' }) };
  } catch (error) {
    console.error('Custom feeds handler error:', error);
    return { statusCode: 500, body: JSON.stringify({ error: 'Internal server error' }) };
  }
}

async function addCustomFeed(userId: string, event: APIGatewayProxyEventV2, user: User): Promise<APIGatewayProxyResultV2> {
  if (!event.body) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Request body required' }) };
  }

  const body: AddCustomFeedRequest = JSON.parse(event.body);
  const { url, name, category } = body;

  if (!url) {
    return { statusCode: 400, body: JSON.stringify({ error: 'URL is required' }) };
  }

  // Check limit
  const maxFeeds = getMaxCustomRSSFeeds(user);
  const currentFeeds = await getUserCustomFeedCount(userId);

  if (maxFeeds !== -1 && currentFeeds >= maxFeeds) {
    return {
      statusCode: 429,
      body: JSON.stringify({
        error: 'Custom feed limit reached',
        code: 'CUSTOM_FEED_LIMIT',
        limit: maxFeeds,
        message: `You've reached your limit of ${maxFeeds} custom feeds.`
      }),
    };
  }

  // Validate and parse the RSS feed
  let feedInfo;
  try {
    feedInfo = await rssParser.parseURL(url);
  } catch (parseError) {
    return {
      statusCode: 400,
      body: JSON.stringify({
        error: 'Invalid RSS feed',
        message: 'Could not parse the URL as a valid RSS/Atom feed. Please check the URL and try again.'
      }),
    };
  }

  const feedId = `custom_${uuidv4()}`;
  const now = Date.now();

  const customFeed: CustomRSSFeed = {
    userId,
    feedId,
    url: url.trim(),
    name: name?.trim() || feedInfo.title || 'Custom Feed',
    description: feedInfo.description?.substring(0, 500),
    iconUrl: feedInfo.image?.url,
    category: category || 'general',
    createdAt: now,
    isValid: true,
  };

  await docClient.send(new PutCommand({
    TableName: CUSTOM_FEEDS_TABLE,
    Item: customFeed,
  }));

  return {
    statusCode: 201,
    body: JSON.stringify({
      feedId: customFeed.feedId,
      url: customFeed.url,
      name: customFeed.name,
      description: customFeed.description,
      iconUrl: customFeed.iconUrl,
      category: customFeed.category,
      createdAt: new Date(customFeed.createdAt).toISOString(),
      articleCount: feedInfo.items?.length || 0,
    }),
  };
}

async function listCustomFeeds(userId: string): Promise<APIGatewayProxyResultV2> {
  const command = new ScanCommand({
    TableName: CUSTOM_FEEDS_TABLE,
    FilterExpression: 'userId = :userId',
    ExpressionAttributeValues: { ':userId': userId },
  });

  const result = await docClient.send(command);
  const feeds = (result.Items || []) as CustomRSSFeed[];

  return {
    statusCode: 200,
    body: JSON.stringify({
      feeds: feeds.map(feed => ({
        feedId: feed.feedId,
        url: feed.url,
        name: feed.name,
        description: feed.description,
        iconUrl: feed.iconUrl,
        category: feed.category,
        createdAt: new Date(feed.createdAt).toISOString(),
        lastFetchedAt: feed.lastFetchedAt ? new Date(feed.lastFetchedAt).toISOString() : null,
        isValid: feed.isValid,
      })),
      count: feeds.length,
    }),
  };
}

async function deleteCustomFeed(userId: string, feedId: string | undefined): Promise<APIGatewayProxyResultV2> {
  if (!feedId) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Feed ID required' }) };
  }

  // Verify ownership
  const existingFeed = await docClient.send(new GetCommand({
    TableName: CUSTOM_FEEDS_TABLE,
    Key: { userId, feedId },
  }));

  if (!existingFeed.Item) {
    return { statusCode: 404, body: JSON.stringify({ error: 'Custom feed not found' }) };
  }

  await docClient.send(new DeleteCommand({
    TableName: CUSTOM_FEEDS_TABLE,
    Key: { userId, feedId },
  }));

  return {
    statusCode: 200,
    body: JSON.stringify({ success: true, message: 'Custom feed removed' }),
  };
}

async function validateFeedUrl(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  if (!event.body) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Request body required' }) };
  }

  const { url } = JSON.parse(event.body);
  if (!url) {
    return { statusCode: 400, body: JSON.stringify({ error: 'URL is required' }) };
  }

  try {
    const feedInfo = await rssParser.parseURL(url);

    return {
      statusCode: 200,
      body: JSON.stringify({
        isValid: true,
        title: feedInfo.title,
        description: feedInfo.description?.substring(0, 300),
        iconUrl: feedInfo.image?.url,
        articleCount: feedInfo.items?.length || 0,
        latestArticle: feedInfo.items?.[0]?.title,
      }),
    };
  } catch (error) {
    return {
      statusCode: 200,
      body: JSON.stringify({
        isValid: false,
        error: 'Could not parse as RSS/Atom feed',
      }),
    };
  }
}

async function getUserCustomFeedCount(userId: string): Promise<number> {
  const command = new ScanCommand({
    TableName: CUSTOM_FEEDS_TABLE,
    FilterExpression: 'userId = :userId',
    ExpressionAttributeValues: { ':userId': userId },
    Select: 'COUNT',
  });

  const result = await docClient.send(command);
  return result.Count || 0;
}

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, ScanCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { extractUserId } from '../lib/auth';
import { getItem, TableNames } from '../lib/dynamo';
import { User, FeedbackItem, FeedbackVote } from '../lib/models';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const FEEDBACK_TABLE = process.env.NUGGET_FEEDBACK_TABLE || 'nugget-feedback-dev';
const FEEDBACK_VOTES_TABLE = process.env.NUGGET_FEEDBACK_VOTES_TABLE || 'nugget-feedback-votes-dev';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
};

interface CreateFeedbackRequest {
  title: string;
  description: string;
  category: 'feature' | 'bug' | 'improvement';
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const method = event.requestContext.http.method;
    const path = event.rawPath;

    // Handle OPTIONS preflight
    if (method === 'OPTIONS') {
      return { statusCode: 200, headers: CORS_HEADERS, body: '' };
    }

    // POST /v1/feedback - Create feedback (auth required)
    if (method === 'POST' && path === '/v1/feedback') {
      return await createFeedback(event);
    }

    // GET /v1/feedback - List all feedback (public)
    if (method === 'GET' && path === '/v1/feedback') {
      return await listFeedback(event);
    }

    // GET /v1/feedback/{feedbackId} - Get single item
    if (method === 'GET' && path.match(/\/v1\/feedback\/[^/]+$/)) {
      const feedbackId = event.pathParameters?.feedbackId;
      return await getFeedback(feedbackId, event);
    }

    // POST /v1/feedback/{feedbackId}/vote - Toggle vote (auth required)
    if (method === 'POST' && path.includes('/vote')) {
      const feedbackId = event.pathParameters?.feedbackId;
      return await toggleVote(feedbackId, event);
    }

    // PUT /v1/feedback/{feedbackId} - Update status (admin only)
    if (method === 'PUT') {
      const feedbackId = event.pathParameters?.feedbackId;
      return await updateFeedbackStatus(feedbackId, event);
    }

    return {
      statusCode: 404,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Not found' }),
    };
  } catch (error) {
    console.error('Feedback handler error:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

async function createFeedback(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const userId = await extractUserId(event);
  if (!userId) {
    return { statusCode: 401, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Unauthorized' }) };
  }

  if (!event.body) {
    return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Request body required' }) };
  }

  const body: CreateFeedbackRequest = JSON.parse(event.body);
  const { title, description, category } = body;

  if (!title || !description || !category) {
    return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Title, description, and category required' }) };
  }

  if (!['feature', 'bug', 'improvement'].includes(category)) {
    return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Invalid category' }) };
  }

  // Get user display name
  const user = await getItem<User>(TableNames.users, { userId });
  const displayName = user?.firstName || user?.name || 'Anonymous';

  const now = Date.now();
  const feedback: FeedbackItem = {
    feedbackId: uuidv4(),
    userId,
    userDisplayName: displayName,
    title: title.trim(),
    description: description.trim(),
    category,
    status: 'open',
    voteCount: 1, // Creator auto-votes
    createdAt: now,
    updatedAt: now,
  };

  // Save feedback
  await docClient.send(new PutCommand({
    TableName: FEEDBACK_TABLE,
    Item: feedback,
  }));

  // Auto-vote for creator
  const vote: FeedbackVote = {
    feedbackId: feedback.feedbackId,
    odinguserId: userId,
    votedAt: now,
  };

  await docClient.send(new PutCommand({
    TableName: FEEDBACK_VOTES_TABLE,
    Item: vote,
  }));

  return {
    statusCode: 201,
    headers: CORS_HEADERS,
    body: JSON.stringify({
      feedbackId: feedback.feedbackId,
      title: feedback.title,
      category: feedback.category,
      status: feedback.status,
      voteCount: feedback.voteCount,
      createdAt: new Date(feedback.createdAt).toISOString(),
    }),
  };
}

async function listFeedback(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  // Get optional filter params
  const category = event.queryStringParameters?.category;
  const status = event.queryStringParameters?.status;
  const sortBy = event.queryStringParameters?.sort || 'votes'; // 'votes' or 'recent'

  // Get current user for checking their votes
  const userId = await extractUserId(event);

  // Scan all feedback
  const command = new ScanCommand({
    TableName: FEEDBACK_TABLE,
  });

  const result = await docClient.send(command);
  let items = (result.Items || []) as FeedbackItem[];

  // Apply filters
  if (category) {
    items = items.filter(i => i.category === category);
  }
  if (status) {
    items = items.filter(i => i.status === status);
  }

  // Sort
  if (sortBy === 'votes') {
    items.sort((a, b) => b.voteCount - a.voteCount);
  } else {
    items.sort((a, b) => b.createdAt - a.createdAt);
  }

  // Check user's votes if authenticated
  let userVotes: Set<string> = new Set();
  if (userId) {
    const votesCommand = new ScanCommand({
      TableName: FEEDBACK_VOTES_TABLE,
      FilterExpression: 'odinguserId = :userId',
      ExpressionAttributeValues: { ':userId': userId },
    });
    const votesResult = await docClient.send(votesCommand);
    userVotes = new Set((votesResult.Items || []).map((v: any) => v.feedbackId));
  }

  return {
    statusCode: 200,
    headers: CORS_HEADERS,
    body: JSON.stringify({
      feedback: items.map(item => ({
        feedbackId: item.feedbackId,
        title: item.title,
        description: item.description,
        category: item.category,
        status: item.status,
        voteCount: item.voteCount,
        userDisplayName: item.userDisplayName,
        hasVoted: userVotes.has(item.feedbackId),
        createdAt: new Date(item.createdAt).toISOString(),
      })),
      total: items.length,
    }),
  };
}

async function getFeedback(feedbackId: string | undefined, event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  if (!feedbackId) {
    return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Feedback ID required' }) };
  }

  const command = new GetCommand({
    TableName: FEEDBACK_TABLE,
    Key: { feedbackId },
  });

  const result = await docClient.send(command);
  if (!result.Item) {
    return { statusCode: 404, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Feedback not found' }) };
  }

  const item = result.Item as FeedbackItem;

  // Check if user has voted
  const userId = await extractUserId(event);
  let hasVoted = false;
  if (userId) {
    const voteCommand = new GetCommand({
      TableName: FEEDBACK_VOTES_TABLE,
      Key: { feedbackId, odinguserId: userId },
    });
    const voteResult = await docClient.send(voteCommand);
    hasVoted = !!voteResult.Item;
  }

  return {
    statusCode: 200,
    headers: CORS_HEADERS,
    body: JSON.stringify({
      feedbackId: item.feedbackId,
      title: item.title,
      description: item.description,
      category: item.category,
      status: item.status,
      voteCount: item.voteCount,
      userDisplayName: item.userDisplayName,
      hasVoted,
      createdAt: new Date(item.createdAt).toISOString(),
      updatedAt: new Date(item.updatedAt).toISOString(),
    }),
  };
}

async function toggleVote(feedbackId: string | undefined, event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const userId = await extractUserId(event);
  if (!userId) {
    return { statusCode: 401, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Unauthorized' }) };
  }

  if (!feedbackId) {
    return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Feedback ID required' }) };
  }

  // Check if already voted
  const voteCommand = new GetCommand({
    TableName: FEEDBACK_VOTES_TABLE,
    Key: { feedbackId, odinguserId: userId },
  });
  const voteResult = await docClient.send(voteCommand);
  const hasVoted = !!voteResult.Item;

  if (hasVoted) {
    // Remove vote
    const { DeleteCommand } = await import('@aws-sdk/lib-dynamodb');
    await docClient.send(new DeleteCommand({
      TableName: FEEDBACK_VOTES_TABLE,
      Key: { feedbackId, odinguserId: userId },
    }));

    // Decrement vote count
    await docClient.send(new UpdateCommand({
      TableName: FEEDBACK_TABLE,
      Key: { feedbackId },
      UpdateExpression: 'SET voteCount = voteCount - :one',
      ExpressionAttributeValues: { ':one': 1 },
    }));

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({ voted: false, message: 'Vote removed' }),
    };
  } else {
    // Add vote
    const vote: FeedbackVote = {
      feedbackId,
      odinguserId: userId,
      votedAt: Date.now(),
    };

    await docClient.send(new PutCommand({
      TableName: FEEDBACK_VOTES_TABLE,
      Item: vote,
    }));

    // Increment vote count
    await docClient.send(new UpdateCommand({
      TableName: FEEDBACK_TABLE,
      Key: { feedbackId },
      UpdateExpression: 'SET voteCount = voteCount + :one',
      ExpressionAttributeValues: { ':one': 1 },
    }));

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({ voted: true, message: 'Vote added' }),
    };
  }
}

async function updateFeedbackStatus(feedbackId: string | undefined, event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  // In production, add admin auth check
  const userId = await extractUserId(event);
  if (!userId) {
    return { statusCode: 401, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Unauthorized' }) };
  }

  if (!feedbackId) {
    return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Feedback ID required' }) };
  }

  if (!event.body) {
    return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Request body required' }) };
  }

  const { status } = JSON.parse(event.body);
  if (!['open', 'planned', 'in-progress', 'completed', 'declined'].includes(status)) {
    return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Invalid status' }) };
  }

  await docClient.send(new UpdateCommand({
    TableName: FEEDBACK_TABLE,
    Key: { feedbackId },
    UpdateExpression: 'SET #status = :status, updatedAt = :now',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: {
      ':status': status,
      ':now': Date.now(),
    },
  }));

  return {
    statusCode: 200,
    headers: CORS_HEADERS,
    body: JSON.stringify({ success: true, status }),
  };
}

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, ScanCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { WaitlistEntry } from '../lib/models';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const WAITLIST_TABLE = process.env.NUGGET_WAITLIST_TABLE || 'nugget-waitlist-dev';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS',
};

interface JoinWaitlistRequest {
  email: string;
  source?: string;
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  // Handle CORS preflight
  const method = event.requestContext.http.method;
  if (method === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: '',
    };
  }

  const path = event.rawPath;

  try {
    // POST /v1/waitlist - Join waitlist (public)
    if (method === 'POST' && !path.includes('/admin')) {
      return await joinWaitlist(event);
    }

    // Admin endpoints (would need auth check in production)
    // GET /v1/waitlist/admin - List all entries
    if (method === 'GET' && path.includes('/admin')) {
      return await listWaitlist();
    }

    // PUT /v1/waitlist/admin/{email} - Update status
    if (method === 'PUT' && path.includes('/admin')) {
      return await updateWaitlistEntry(event);
    }

    return {
      statusCode: 404,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Not found' }),
    };
  } catch (error) {
    console.error('Waitlist error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};

async function joinWaitlist(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  if (!event.body) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Missing request body' }),
    };
  }

  const body: JoinWaitlistRequest = JSON.parse(event.body);
  const { email, source } = body;

  if (!email) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Email is required' }),
    };
  }

  // Basic email validation
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Invalid email format' }),
    };
  }

  const normalizedEmail = email.toLowerCase().trim();

  // Check if already on waitlist
  const existingCommand = new GetCommand({
    TableName: WAITLIST_TABLE,
    Key: { email: normalizedEmail },
  });

  const existing = await docClient.send(existingCommand);

  if (existing.Item) {
    // Already on waitlist - return success but indicate already registered
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        message: "You're already on the waitlist! We'll notify you when a spot opens up.",
        alreadyRegistered: true,
      }),
    };
  }

  // Get current waitlist count for position
  const countCommand = new ScanCommand({
    TableName: WAITLIST_TABLE,
    Select: 'COUNT',
  });
  const countResult = await docClient.send(countCommand);
  const position = (countResult.Count || 0) + 1;

  // Add to waitlist
  const entry: WaitlistEntry = {
    email: normalizedEmail,
    signedUpAt: Date.now(),
    status: 'pending',
    source: source || 'landing',
  };

  const putCommand = new PutCommand({
    TableName: WAITLIST_TABLE,
    Item: entry,
  });

  await docClient.send(putCommand);

  return {
    statusCode: 201,
    headers: corsHeaders,
    body: JSON.stringify({
      success: true,
      message: "You're on the list! We'll email you when a spot opens up.",
      position,
    }),
  };
}

async function listWaitlist(): Promise<APIGatewayProxyResultV2> {
  // In production, add admin auth check here
  const command = new ScanCommand({
    TableName: WAITLIST_TABLE,
  });

  const result = await docClient.send(command);

  // Sort by signedUpAt
  const entries = (result.Items || []) as WaitlistEntry[];
  entries.sort((a, b) => a.signedUpAt - b.signedUpAt);

  return {
    statusCode: 200,
    headers: corsHeaders,
    body: JSON.stringify({
      total: entries.length,
      pending: entries.filter(e => e.status === 'pending').length,
      invited: entries.filter(e => e.status === 'invited').length,
      joined: entries.filter(e => e.status === 'joined').length,
      entries: entries.map((e, index) => ({
        email: e.email,
        position: index + 1,
        status: e.status,
        signedUpAt: new Date(e.signedUpAt).toISOString(),
        invitedAt: e.invitedAt ? new Date(e.invitedAt).toISOString() : null,
        source: e.source,
      })),
    }),
  };
}

async function updateWaitlistEntry(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  // In production, add admin auth check here
  const email = event.pathParameters?.email;
  if (!email) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Email parameter required' }),
    };
  }

  if (!event.body) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Missing request body' }),
    };
  }

  const body = JSON.parse(event.body);
  const { status } = body;

  if (!status || !['pending', 'invited', 'joined'].includes(status)) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Invalid status' }),
    };
  }

  const updateExpression = status === 'invited'
    ? 'SET #status = :status, invitedAt = :invitedAt'
    : 'SET #status = :status';

  const expressionValues: Record<string, any> = {
    ':status': status,
  };

  if (status === 'invited') {
    expressionValues[':invitedAt'] = Date.now();
  }

  const command = new UpdateCommand({
    TableName: WAITLIST_TABLE,
    Key: { email: decodeURIComponent(email).toLowerCase() },
    UpdateExpression: updateExpression,
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: expressionValues,
    ReturnValues: 'ALL_NEW',
  });

  const result = await docClient.send(command);

  return {
    statusCode: 200,
    headers: corsHeaders,
    body: JSON.stringify({
      success: true,
      entry: result.Attributes,
    }),
  };
}

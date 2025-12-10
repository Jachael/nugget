import { APIGatewayProxyHandler, APIGatewayProxyEvent } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { getItem, putItem, TableNames } from '../lib/dynamo';
import { Nugget } from '../lib/models';
import { verifyAccessToken } from '../lib/auth';

const SHARED_NUGGETS_TABLE = process.env.NUGGET_SHARED_NUGGETS_TABLE || `nugget-shared-nuggets-${process.env.STAGE || 'dev'}`;

interface SharedNugget {
  shareId: string;
  nuggetId: string;
  userId: string;
  title?: string;
  category?: string;
  summary?: string;
  keyPoints?: string[];
  question?: string;
  isGrouped?: boolean;
  sourceUrls?: string[];
  individualSummaries?: {
    nuggetId: string;
    title: string;
    summary: string;
    keyPoints: string[];
    sourceUrl: string;
  }[];
  createdAt: string;
  expiresAt?: number; // TTL - optional expiration
}

/**
 * POST /v1/nuggets/{nuggetId}/share
 * Creates a shareable link for a nugget
 */
export const handler: APIGatewayProxyHandler = async (event: APIGatewayProxyEvent) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  try {
    // Verify authentication
    const authHeader = event.headers.Authorization || event.headers.authorization;
    if (!authHeader) {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Missing authorization header' }),
      };
    }

    const token = authHeader.replace('Bearer ', '');
    let userId: string;
    try {
      const decoded = verifyAccessToken(token);
      userId = decoded.userId;
    } catch {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Invalid token' }),
      };
    }
    const nuggetId = event.pathParameters?.nuggetId;

    if (!nuggetId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Missing nuggetId' }),
      };
    }

    // Get the nugget - nuggets table uses composite key (nuggetId + usrId for GSI, but PK is nuggetId)
    // Actually nuggets table has nuggetId as PK only based on the schema
    const nugget = await getItem<Nugget>(TableNames.nuggets, { nuggetId, userId });

    if (!nugget) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Nugget not found' }),
      };
    }

    // Generate share ID
    const shareId = uuidv4().split('-')[0]; // Short 8-char ID

    // Create shared nugget record
    const sharedNugget: SharedNugget = {
      shareId,
      nuggetId: nugget.nuggetId,
      userId,
      title: nugget.title,
      category: nugget.category,
      summary: nugget.summary,
      keyPoints: nugget.keyPoints,
      question: nugget.question,
      isGrouped: nugget.isGrouped,
      sourceUrls: nugget.sourceUrls,
      individualSummaries: nugget.individualSummaries,
      createdAt: new Date().toISOString(),
      // Optional: Set TTL for 30 days
      // expiresAt: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60),
    };

    await putItem(SHARED_NUGGETS_TABLE, sharedNugget);

    const shareUrl = `https://nuggetdotcom.com/n/${shareId}`;

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        shareId,
        shareUrl,
        message: 'Nugget shared successfully',
      }),
    };
  } catch (error) {
    console.error('Error sharing nugget:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Failed to share nugget' }),
    };
  }
};

/**
 * GET /v1/shared/{shareId}
 * Public endpoint to get a shared nugget (no auth required)
 */
export const getSharedNuggetHandler: APIGatewayProxyHandler = async (event) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  try {
    const shareId = event.pathParameters?.shareId;

    if (!shareId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Missing shareId' }),
      };
    }

    const sharedNugget = await getItem<SharedNugget>(SHARED_NUGGETS_TABLE, { shareId });

    if (!sharedNugget) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Shared nugget not found or has expired' }),
      };
    }

    // Return nugget data without sensitive info
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        shareId: sharedNugget.shareId,
        title: sharedNugget.title,
        category: sharedNugget.category,
        summary: sharedNugget.summary,
        keyPoints: sharedNugget.keyPoints,
        question: sharedNugget.question,
        isGrouped: sharedNugget.isGrouped,
        sourceUrls: sharedNugget.sourceUrls,
        individualSummaries: sharedNugget.individualSummaries,
        createdAt: sharedNugget.createdAt,
      }),
    };
  } catch (error) {
    console.error('Error getting shared nugget:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Failed to get shared nugget' }),
    };
  }
};

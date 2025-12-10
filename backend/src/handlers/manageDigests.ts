import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { getItem, putItem, updateItem, queryItems, deleteItem, TableNames } from '../lib/dynamo';
import { User, CustomDigest, CreateDigestInput, UpdateDigestInput, DigestResponse, DigestFrequency } from '../lib/models';
import { getEffectiveTier, canCreateCustomDigests } from '../lib/subscription';

const MAX_DIGESTS_PER_USER = 10;
const DEFAULT_ARTICLES_PER_DIGEST = 5;
const DEFAULT_FREQUENCY: DigestFrequency = 'with_schedule';
const VALID_FREQUENCIES: DigestFrequency[] = ['with_schedule', 'once_daily', 'twice_daily', 'three_times_daily'];
const VALID_ARTICLE_COUNTS = [3, 5, 10, 15, 20];

/**
 * Convert CustomDigest to API response format
 */
function toDigestResponse(digest: CustomDigest): DigestResponse {
  return {
    digestId: digest.digestId,
    name: digest.name,
    feedIds: digest.feedIds,
    isEnabled: digest.isEnabled,
    lastGeneratedAt: digest.lastGeneratedAt
      ? new Date(digest.lastGeneratedAt * 1000).toISOString()
      : undefined,
    createdAt: new Date(digest.createdAt * 1000).toISOString(),
    articlesPerDigest: digest.articlesPerDigest ?? DEFAULT_ARTICLES_PER_DIGEST,
    frequency: digest.frequency ?? DEFAULT_FREQUENCY,
  };
}

/**
 * POST /v1/digests - Create a new custom digest
 * Requires Ultimate subscription
 */
export async function createDigest(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    // Check user has Ultimate subscription
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    if (!canCreateCustomDigests(user)) {
      return {
        statusCode: 403,
        body: JSON.stringify({
          error: 'Custom digests require an Ultimate subscription',
          upgradeRequired: true,
        }),
      };
    }

    // Parse request
    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body required' }),
      };
    }

    const input: CreateDigestInput = JSON.parse(event.body);

    // Validate input
    if (!input.name || input.name.trim().length === 0) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Digest name is required' }),
      };
    }

    if (!input.feedIds || input.feedIds.length === 0) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'At least one feed is required' }),
      };
    }

    if (input.feedIds.length > 10) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Maximum 10 feeds per digest' }),
      };
    }

    // Validate articlesPerDigest if provided
    if (input.articlesPerDigest !== undefined && !VALID_ARTICLE_COUNTS.includes(input.articlesPerDigest)) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          error: `Invalid articlesPerDigest. Must be one of: ${VALID_ARTICLE_COUNTS.join(', ')}`,
          validCounts: VALID_ARTICLE_COUNTS,
        }),
      };
    }

    // Validate frequency if provided
    if (input.frequency !== undefined && !VALID_FREQUENCIES.includes(input.frequency)) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          error: `Invalid frequency. Must be one of: ${VALID_FREQUENCIES.join(', ')}`,
          validFrequencies: VALID_FREQUENCIES,
        }),
      };
    }

    // Check user hasn't exceeded digest limit
    const existingDigests = await queryItems<CustomDigest>({
      TableName: TableNames.customDigests,
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId,
      },
    });

    if (existingDigests.length >= MAX_DIGESTS_PER_USER) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          error: `Maximum ${MAX_DIGESTS_PER_USER} custom digests allowed`,
          limit: MAX_DIGESTS_PER_USER,
        }),
      };
    }

    // Create digest
    const now = Math.floor(Date.now() / 1000);
    const digestId = `digest-${uuidv4()}`;

    const digest: CustomDigest = {
      userId,
      digestId,
      name: input.name.trim(),
      feedIds: input.feedIds,
      createdAt: now,
      updatedAt: now,
      isEnabled: true,
      articlesPerDigest: input.articlesPerDigest ?? DEFAULT_ARTICLES_PER_DIGEST,
      frequency: input.frequency ?? DEFAULT_FREQUENCY,
    };

    await putItem(TableNames.customDigests, digest);

    console.log(`Created custom digest: ${digestId} for user ${userId}`);

    return {
      statusCode: 201,
      body: JSON.stringify({
        message: 'Custom digest created',
        digest: toDigestResponse(digest),
      }),
    };
  } catch (error) {
    console.error('Error creating digest:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

/**
 * GET /v1/digests - List user's custom digests
 * Requires Ultimate subscription
 */
export async function listDigests(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    // Check user has Ultimate subscription
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    const effectiveTier = getEffectiveTier(user);
    if (effectiveTier !== 'ultimate') {
      return {
        statusCode: 200,
        body: JSON.stringify({
          digests: [],
          tier: effectiveTier,
          upgradeRequired: true,
          message: 'Custom digests require an Ultimate subscription',
        }),
      };
    }

    // Get user's digests
    const digests = await queryItems<CustomDigest>({
      TableName: TableNames.customDigests,
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId,
      },
    });

    return {
      statusCode: 200,
      body: JSON.stringify({
        digests: digests.map(toDigestResponse),
        tier: effectiveTier,
        limit: MAX_DIGESTS_PER_USER,
      }),
    };
  } catch (error) {
    console.error('Error listing digests:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

/**
 * PUT /v1/digests/{digestId} - Update a custom digest
 * Requires Ultimate subscription
 */
export async function updateDigest(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const digestId = event.pathParameters?.digestId;
    if (!digestId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Digest ID required' }),
      };
    }

    // Check user has Ultimate subscription
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user || !canCreateCustomDigests(user)) {
      return {
        statusCode: 403,
        body: JSON.stringify({
          error: 'Custom digests require an Ultimate subscription',
          upgradeRequired: true,
        }),
      };
    }

    // Get existing digest
    const digest = await getItem<CustomDigest>(TableNames.customDigests, { userId, digestId });
    if (!digest) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'Digest not found' }),
      };
    }

    // Parse request
    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body required' }),
      };
    }

    const input: UpdateDigestInput = JSON.parse(event.body);
    const now = Math.floor(Date.now() / 1000);
    const updates: Record<string, unknown> = { updatedAt: now };

    if (input.name !== undefined) {
      if (input.name.trim().length === 0) {
        return {
          statusCode: 400,
          body: JSON.stringify({ error: 'Digest name cannot be empty' }),
        };
      }
      updates.name = input.name.trim();
    }

    if (input.feedIds !== undefined) {
      if (input.feedIds.length === 0) {
        return {
          statusCode: 400,
          body: JSON.stringify({ error: 'At least one feed is required' }),
        };
      }
      if (input.feedIds.length > 10) {
        return {
          statusCode: 400,
          body: JSON.stringify({ error: 'Maximum 10 feeds per digest' }),
        };
      }
      updates.feedIds = input.feedIds;
    }

    if (input.isEnabled !== undefined) {
      updates.isEnabled = input.isEnabled;
    }

    if (input.articlesPerDigest !== undefined) {
      if (!VALID_ARTICLE_COUNTS.includes(input.articlesPerDigest)) {
        return {
          statusCode: 400,
          body: JSON.stringify({
            error: `Invalid articlesPerDigest. Must be one of: ${VALID_ARTICLE_COUNTS.join(', ')}`,
            validCounts: VALID_ARTICLE_COUNTS,
          }),
        };
      }
      updates.articlesPerDigest = input.articlesPerDigest;
    }

    if (input.frequency !== undefined) {
      if (!VALID_FREQUENCIES.includes(input.frequency)) {
        return {
          statusCode: 400,
          body: JSON.stringify({
            error: `Invalid frequency. Must be one of: ${VALID_FREQUENCIES.join(', ')}`,
            validFrequencies: VALID_FREQUENCIES,
          }),
        };
      }
      updates.frequency = input.frequency;
    }

    await updateItem(TableNames.customDigests, { userId, digestId }, updates);

    // Get updated digest
    const updatedDigest = await getItem<CustomDigest>(TableNames.customDigests, { userId, digestId });

    console.log(`Updated custom digest: ${digestId} for user ${userId}`);

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Digest updated',
        digest: updatedDigest ? toDigestResponse(updatedDigest) : null,
      }),
    };
  } catch (error) {
    console.error('Error updating digest:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

/**
 * DELETE /v1/digests/{digestId} - Delete a custom digest
 * Requires Ultimate subscription
 */
export async function deleteDigest(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const digestId = event.pathParameters?.digestId;
    if (!digestId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Digest ID required' }),
      };
    }

    // Check user has Ultimate subscription
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user || !canCreateCustomDigests(user)) {
      return {
        statusCode: 403,
        body: JSON.stringify({
          error: 'Custom digests require an Ultimate subscription',
          upgradeRequired: true,
        }),
      };
    }

    // Get existing digest
    const digest = await getItem<CustomDigest>(TableNames.customDigests, { userId, digestId });
    if (!digest) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'Digest not found' }),
      };
    }

    // Delete digest
    await deleteItem(TableNames.customDigests, { userId, digestId });

    console.log(`Deleted custom digest: ${digestId} for user ${userId}`);

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Digest deleted',
        digestId,
      }),
    };
  } catch (error) {
    console.error('Error deleting digest:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

/**
 * Main handler that routes to appropriate function based on HTTP method
 */
export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const method = event.requestContext.http.method;
  const hasDigestId = event.pathParameters?.digestId;

  switch (method) {
    case 'POST':
      return createDigest(event);
    case 'GET':
      return listDigests(event);
    case 'PUT':
      if (!hasDigestId) {
        return {
          statusCode: 400,
          body: JSON.stringify({ error: 'Digest ID required for update' }),
        };
      }
      return updateDigest(event);
    case 'DELETE':
      if (!hasDigestId) {
        return {
          statusCode: 400,
          body: JSON.stringify({ error: 'Digest ID required for delete' }),
        };
      }
      return deleteDigest(event);
    default:
      return {
        statusCode: 405,
        body: JSON.stringify({ error: 'Method not allowed' }),
      };
  }
}

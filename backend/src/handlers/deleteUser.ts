import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand, BatchWriteCommand } from '@aws-sdk/lib-dynamodb';
import { extractUserId } from '../lib/auth';
import { TableNames } from '../lib/dynamo';

const dynamoClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(dynamoClient);

/**
 * Delete user account and all associated data
 */
export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    // Get userId from token
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    console.log(`Deleting account for user: ${userId}`);

    // Delete all user's nuggets
    const nuggetsQuery = await docClient.send(
      new QueryCommand({
        TableName: TableNames.nuggets,
        KeyConditionExpression: 'userId = :userId',
        ExpressionAttributeValues: {
          ':userId': userId,
        },
      })
    );

    if (nuggetsQuery.Items && nuggetsQuery.Items.length > 0) {
      // Batch delete nuggets (DynamoDB allows max 25 items per batch)
      const chunks = [];
      for (let i = 0; i < nuggetsQuery.Items.length; i += 25) {
        chunks.push(nuggetsQuery.Items.slice(i, i + 25));
      }

      for (const chunk of chunks) {
        const deleteRequests = chunk.map((nugget) => ({
          DeleteRequest: {
            Key: {
              userId: nugget.userId,
              nuggetId: nugget.nuggetId,
            },
          },
        }));

        await docClient.send(
          new BatchWriteCommand({
            RequestItems: {
              [TableNames.nuggets]: deleteRequests,
            },
          })
        );
      }

      console.log(`Deleted ${nuggetsQuery.Items.length} nuggets for user ${userId}`);
    }

    // Delete all user's sessions
    const sessionsQuery = await docClient.send(
      new QueryCommand({
        TableName: TableNames.sessions,
        KeyConditionExpression: 'userId = :userId',
        ExpressionAttributeValues: {
          ':userId': userId,
        },
      })
    );

    if (sessionsQuery.Items && sessionsQuery.Items.length > 0) {
      // Batch delete sessions
      const chunks = [];
      for (let i = 0; i < sessionsQuery.Items.length; i += 25) {
        chunks.push(sessionsQuery.Items.slice(i, i + 25));
      }

      for (const chunk of chunks) {
        const deleteRequests = chunk.map((session) => ({
          DeleteRequest: {
            Key: {
              userId: session.userId,
              sessionId: session.sessionId,
            },
          },
        }));

        await docClient.send(
          new BatchWriteCommand({
            RequestItems: {
              [TableNames.sessions]: deleteRequests,
            },
          })
        );
      }

      console.log(`Deleted ${sessionsQuery.Items.length} sessions for user ${userId}`);
    }

    // Finally, delete the user record
    await docClient.send(
      new BatchWriteCommand({
        RequestItems: {
          [TableNames.users]: [
            {
              DeleteRequest: {
                Key: {
                  userId: userId,
                },
              },
            },
          ],
        },
      })
    );

    console.log(`Successfully deleted user account: ${userId}`);

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Account successfully deleted',
      }),
    };
  } catch (error) {
    console.error('Error deleting user account:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Failed to delete account' }),
    };
  }
}
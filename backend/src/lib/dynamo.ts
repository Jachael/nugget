import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  QueryCommand,
  UpdateCommand,
  DeleteCommand,
  QueryCommandInput,
} from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'eu-west-1' });
export const dynamoDb = DynamoDBDocumentClient.from(client);

export const TableNames = {
  users: process.env.NUGGET_USERS_TABLE!,
  nuggets: process.env.NUGGET_NUGGETS_TABLE!,
  sessions: process.env.NUGGET_SESSIONS_TABLE!,
  schedules: process.env.NUGGET_SCHEDULES_TABLE!,
  deviceTokens: process.env.NUGGET_DEVICE_TOKENS_TABLE!,
};

export async function getItem<T>(tableName: string, key: Record<string, unknown>): Promise<T | null> {
  const result = await dynamoDb.send(new GetCommand({
    TableName: tableName,
    Key: key,
  }));
  return (result.Item as T) || null;
}

export async function putItem<T>(tableName: string, item: T): Promise<void> {
  await dynamoDb.send(new PutCommand({
    TableName: tableName,
    Item: item as Record<string, unknown>,
  }));
}

export async function updateItem(
  tableName: string,
  key: Record<string, unknown>,
  updates: Record<string, unknown>
): Promise<void> {
  const updateExpression = 'SET ' + Object.keys(updates).map((_k, i) => `#field${i} = :val${i}`).join(', ');
  const expressionAttributeNames: Record<string, string> = {};
  const expressionAttributeValues: Record<string, unknown> = {};

  Object.keys(updates).forEach((k, i) => {
    expressionAttributeNames[`#field${i}`] = k;
    expressionAttributeValues[`:val${i}`] = updates[k];
  });

  await dynamoDb.send(new UpdateCommand({
    TableName: tableName,
    Key: key,
    UpdateExpression: updateExpression,
    ExpressionAttributeNames: expressionAttributeNames,
    ExpressionAttributeValues: expressionAttributeValues,
  }));
}

export async function queryItems<T>(params: QueryCommandInput): Promise<T[]> {
  const result = await dynamoDb.send(new QueryCommand(params));
  return (result.Items as T[]) || [];
}

export async function deleteItem(tableName: string, key: Record<string, unknown>): Promise<void> {
  await dynamoDb.send(new DeleteCommand({
    TableName: tableName,
    Key: key,
  }));
}

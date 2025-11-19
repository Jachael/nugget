import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';

const lambda = new LambdaClient({ region: process.env.AWS_REGION || 'eu-west-1' });

/**
 * Invoke the summariseNugget Lambda function asynchronously
 */
export async function invokeSummariseNugget(
  nuggetId: string,
  userId: string
): Promise<void> {
  const functionName = `nugget-${process.env.STAGE || 'dev'}-summariseNugget`;

  await lambda.send(new InvokeCommand({
    FunctionName: functionName,
    InvocationType: 'Event', // Async invocation
    Payload: Buffer.from(JSON.stringify({
      userId,
      nuggetId,
    })),
  }));
}
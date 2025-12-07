import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, updateItem, TableNames } from '../lib/dynamo';
import { User } from '../lib/models';
import {
  verifyAppleReceipt,
  getTierFromProductId,
  calculateExpirationDate,
} from '../lib/subscription';

interface VerifySubscriptionRequest {
  receiptData: string;
  transactionId: string;
  productId: string;
}

interface VerifySubscriptionResponse {
  success: boolean;
  tier: string;
  expiresAt?: string;
  error?: string;
}

export async function handler(
  event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyResultV2> {
  try {
    // Authenticate user
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    console.log('Verifying subscription for user:', userId);

    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body is required' }),
      };
    }

    const body: VerifySubscriptionRequest = JSON.parse(event.body);

    if (!body.receiptData || !body.transactionId || !body.productId) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          error: 'receiptData, transactionId, and productId are required',
        }),
      };
    }

    // Get user from database
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    // Verify the receipt with Apple
    const verification = await verifyAppleReceipt(body.receiptData);

    if (!verification.valid) {
      console.error('Receipt verification failed:', verification.error);

      // For development/testing, we can allow a bypass mode
      // In production, this should always fail if verification fails
      if (process.env.STAGE === 'dev' || process.env.STAGE === 'local') {
        console.log('DEV MODE: Allowing subscription without verification');

        // Determine tier from product ID
        const tier = getTierFromProductId(body.productId);

        // Calculate expiration date (1 month from now)
        const expirationDate = calculateExpirationDate();

        // Update user subscription
        await updateItem(
          TableNames.users,
          { userId },
          {
            subscriptionTier: tier,
            subscriptionExpiresAt: expirationDate,
            originalTransactionId: body.transactionId,
            lastReceiptVerification: Date.now(),
          }
        );

        console.log(`✅ DEV: Updated user subscription to ${tier}`);

        const response: VerifySubscriptionResponse = {
          success: true,
          tier,
          expiresAt: expirationDate,
        };

        return {
          statusCode: 200,
          body: JSON.stringify(response),
        };
      }

      const response: VerifySubscriptionResponse = {
        success: false,
        tier: 'free',
        error: verification.error || 'Receipt verification failed',
      };

      return {
        statusCode: 400,
        body: JSON.stringify(response),
      };
    }

    // Verification successful - update user subscription
    const tier = getTierFromProductId(verification.productId || body.productId);
    const expirationDate = verification.expirationDate || calculateExpirationDate();

    await updateItem(
      TableNames.users,
      { userId },
      {
        subscriptionTier: tier,
        subscriptionExpiresAt: expirationDate,
        originalTransactionId: verification.transactionId || body.transactionId,
        lastReceiptVerification: Date.now(),
      }
    );

    console.log(`✅ Updated user subscription to ${tier}, expires: ${expirationDate}`);

    const response: VerifySubscriptionResponse = {
      success: true,
      tier,
      expiresAt: expirationDate,
    };

    return {
      statusCode: 200,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in verifySubscription handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

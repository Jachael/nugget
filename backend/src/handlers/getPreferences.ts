import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, TableNames } from '../lib/dynamo';
import { User, PreferencesResponse } from '../lib/models';

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
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

    // Return preferences with defaults if not set
    // Check both top-level subscriptionTier (set by StoreKit verification) and preferences.subscriptionTier
    const subscriptionTier = user.subscriptionTier || user.preferences?.subscriptionTier || 'free';

    const response: PreferencesResponse = {
      interests: user.preferences?.interests || [],
      dailyNuggetLimit: user.preferences?.dailyNuggetLimit || 1,
      subscriptionTier,
      customCategories: user.preferences?.customCategories,
      categoryWeights: user.preferences?.categoryWeights,
      onboardingCompleted: user.onboardingCompleted || false,
    };

    return {
      statusCode: 200,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in getPreferences handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

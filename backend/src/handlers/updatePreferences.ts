import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { updateItem, TableNames } from '../lib/dynamo';
import { UpdatePreferencesInput, PreferencesResponse, UserPreferences } from '../lib/models';

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body is required' }),
      };
    }

    const input: UpdatePreferencesInput = JSON.parse(event.body);

    // Validate dailyNuggetLimit based on subscription tier
    if (input.dailyNuggetLimit !== undefined) {
      const tier = input.subscriptionTier || 'free';
      if (tier === 'free' && input.dailyNuggetLimit > 1) {
        return {
          statusCode: 400,
          body: JSON.stringify({ error: 'Free tier limited to 1 nugget per day' }),
        };
      }
      if (input.dailyNuggetLimit < 1 || input.dailyNuggetLimit > 20) {
        return {
          statusCode: 400,
          body: JSON.stringify({ error: 'Daily nugget limit must be between 1 and 20' }),
        };
      }
    }

    // Build preferences update
    const preferences: Partial<UserPreferences> = {};
    if (input.interests !== undefined) preferences.interests = input.interests;
    if (input.dailyNuggetLimit !== undefined) preferences.dailyNuggetLimit = input.dailyNuggetLimit;
    if (input.subscriptionTier !== undefined) preferences.subscriptionTier = input.subscriptionTier;
    if (input.customCategories !== undefined) preferences.customCategories = input.customCategories;
    if (input.categoryWeights !== undefined) preferences.categoryWeights = input.categoryWeights;

    // Update user preferences in database
    await updateItem(
      TableNames.users,
      { userId },
      {
        preferences,
        onboardingCompleted: true, // Mark onboarding as completed
      }
    );

    // Return updated preferences
    const response: PreferencesResponse = {
      interests: input.interests || [],
      dailyNuggetLimit: input.dailyNuggetLimit || 1,
      subscriptionTier: input.subscriptionTier || 'free',
      customCategories: input.customCategories,
      categoryWeights: input.categoryWeights,
      onboardingCompleted: true,
    };

    return {
      statusCode: 200,
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error('Error in updatePreferences handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

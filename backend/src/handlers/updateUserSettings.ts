import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { extractUserId } from '../lib/auth';
import { getItem, updateItem, TableNames } from '../lib/dynamo';
import { User, UserSettings, UpdateUserSettingsInput } from '../lib/models';
import { getEffectiveTier, canConfigureNotifications } from '../lib/subscription';

/**
 * PUT /v1/settings
 * Update user settings including notification preferences
 * Advanced notification filtering requires Ultimate subscription
 */
export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    // Get user
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    // Parse request
    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Request body required' }),
      };
    }

    const input: UpdateUserSettingsInput = JSON.parse(event.body);
    const effectiveTier = getEffectiveTier(user);
    const hasAdvancedNotifications = canConfigureNotifications(user);

    // Build settings update
    const currentSettings = user.settings || {};
    const updatedSettings: UserSettings = { ...currentSettings };

    // Basic notification toggle (available to all users)
    if (input.notificationsEnabled !== undefined) {
      updatedSettings.notificationsEnabled = input.notificationsEnabled;
    }

    // Advanced notification settings (Ultimate only)
    if (hasAdvancedNotifications) {
      if (input.notifyOnAllNuggets !== undefined) {
        updatedSettings.notifyOnAllNuggets = input.notifyOnAllNuggets;
      }

      if (input.notifyCategories !== undefined) {
        // Validate categories
        if (input.notifyCategories.length > 10) {
          return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Maximum 10 notification categories allowed' }),
          };
        }
        updatedSettings.notifyCategories = input.notifyCategories;
      }

      if (input.notifyFeeds !== undefined) {
        // Validate feed IDs
        if (input.notifyFeeds.length > 10) {
          return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Maximum 10 notification feeds allowed' }),
          };
        }
        updatedSettings.notifyFeeds = input.notifyFeeds;
      }

      if (input.notifyDigests !== undefined) {
        // Validate digest IDs
        if (input.notifyDigests.length > 10) {
          return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Maximum 10 notification digests allowed' }),
          };
        }
        updatedSettings.notifyDigests = input.notifyDigests;
      }

      if (input.readerModeEnabled !== undefined) {
        updatedSettings.readerModeEnabled = input.readerModeEnabled;
      }

      if (input.offlineEnabled !== undefined) {
        updatedSettings.offlineEnabled = input.offlineEnabled;
      }
    } else {
      // Non-Ultimate users trying to set advanced settings
      if (input.notifyOnAllNuggets !== undefined ||
          input.notifyCategories !== undefined ||
          input.notifyFeeds !== undefined ||
          input.notifyDigests !== undefined) {
        return {
          statusCode: 403,
          body: JSON.stringify({
            error: 'Advanced notification settings require an Ultimate subscription',
            upgradeRequired: true,
          }),
        };
      }
    }

    // Update user settings
    await updateItem(TableNames.users, { userId }, {
      settings: updatedSettings,
    });

    console.log(`Updated settings for user ${userId}:`, updatedSettings);

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Settings updated',
        settings: updatedSettings,
        tier: effectiveTier,
        hasAdvancedNotifications,
      }),
    };
  } catch (error) {
    console.error('Error updating user settings:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

/**
 * GET /v1/settings
 * Get current user settings
 */
export async function getSettingsHandler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    // Get user
    const user = await getItem<User>(TableNames.users, { userId });
    if (!user) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'User not found' }),
      };
    }

    const effectiveTier = getEffectiveTier(user);
    const hasAdvancedNotifications = canConfigureNotifications(user);

    // Return default settings if none exist
    const settings: UserSettings = user.settings || {
      notificationsEnabled: true,
      notifyOnAllNuggets: true,
    };

    return {
      statusCode: 200,
      body: JSON.stringify({
        settings,
        tier: effectiveTier,
        hasAdvancedNotifications,
      }),
    };
  } catch (error) {
    console.error('Error getting user settings:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

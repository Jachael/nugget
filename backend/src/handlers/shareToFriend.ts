import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { getItem, putItem, queryItems, updateItem, TableNames } from '../lib/dynamo';
import { User, Nugget, FriendSharedNugget } from '../lib/models';
import { sendPushNotification, NotificationType, PushNotificationPayload } from '../lib/notifications';

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  try {
    const userId = await extractUserId(event);
    if (!userId) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const method = event.requestContext.http.method;
    const path = event.rawPath;

    // POST /v1/nuggets/{nuggetId}/share-to-friends - Share a nugget to friends
    if (method === 'POST' && path.includes('/share-to-friends')) {
      const nuggetId = event.pathParameters?.nuggetId;
      return await shareNuggetToFriends(userId, nuggetId, event);
    }

    // GET /v1/shared-with-me - Get nuggets shared with me
    if (method === 'GET' && path === '/v1/shared-with-me') {
      return await getSharedWithMe(userId);
    }

    // POST /v1/shared-with-me/{shareId}/read - Mark shared nugget as read
    if (method === 'POST' && path.includes('/read')) {
      const shareId = event.pathParameters?.shareId;
      return await markSharedAsRead(userId, shareId);
    }

    return {
      statusCode: 404,
      body: JSON.stringify({ error: 'Not found' }),
    };
  } catch (error) {
    console.error('ShareToFriend handler error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

async function shareNuggetToFriends(
  userId: string,
  nuggetId: string | undefined,
  event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyResultV2> {
  if (!nuggetId) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Nugget ID required' }) };
  }

  if (!event.body) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Request body required' }) };
  }

  const { friendIds } = JSON.parse(event.body) as { friendIds: string[] };
  if (!friendIds || !Array.isArray(friendIds) || friendIds.length === 0) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Friend IDs required' }) };
  }

  // Get current user
  const currentUser = await getItem<User>(TableNames.users, { userId });
  if (!currentUser) {
    return { statusCode: 404, body: JSON.stringify({ error: 'User not found' }) };
  }

  // Verify all friends are actually friends
  const validFriendIds = friendIds.filter(fid => currentUser.friends?.includes(fid));
  if (validFriendIds.length === 0) {
    return { statusCode: 400, body: JSON.stringify({ error: 'No valid friends in the list' }) };
  }

  // Get the nugget to share
  const nugget = await getItem<Nugget>(TableNames.nuggets, { userId, nuggetId });
  if (!nugget) {
    return { statusCode: 404, body: JSON.stringify({ error: 'Nugget not found' }) };
  }

  const senderDisplayName = currentUser.firstName || currentUser.name || 'A friend';
  const now = Date.now();
  const sharedCount = { success: 0, failed: 0 };

  // Share to each friend
  for (const friendId of validFriendIds) {
    try {
      const shareId = uuidv4();

      const sharedNugget: FriendSharedNugget = {
        recipientUserId: friendId,
        shareId,
        nuggetId,
        senderUserId: userId,
        senderDisplayName,
        sharedAt: now,
        isRead: false,
        // Denormalized data for display without extra lookups
        nuggetTitle: nugget.rawTitle || nugget.title,
        nuggetSummary: nugget.summary,
        nuggetSourceUrl: nugget.sourceUrl,
        nuggetCategory: nugget.category,
      };

      await putItem(TableNames.friendSharedNuggets, sharedNugget);
      sharedCount.success++;

      // Send push notification to friend
      try {
        const friend = await getItem<User>(TableNames.users, { userId: friendId });
        if (friend?.settings?.notificationsEnabled !== false) {
          const payload: PushNotificationPayload = {
            title: `${senderDisplayName} shared a nugget`,
            body: nugget.rawTitle || nugget.summary?.substring(0, 100) || 'Check out this nugget!',
            data: {
              type: 'FRIEND_SHARE',
              shareId,
              senderUserId: userId,
            },
          };
          await sendPushNotification(friendId, NotificationType.NEW_CONTENT, payload);
          console.log(`Sent share notification to friend ${friendId}`);
        }
      } catch (notifError) {
        console.error(`Failed to send notification to friend ${friendId}:`, notifError);
        // Don't fail the share if notification fails
      }
    } catch (shareError) {
      console.error(`Failed to share to friend ${friendId}:`, shareError);
      sharedCount.failed++;
    }
  }

  return {
    statusCode: 200,
    body: JSON.stringify({
      success: true,
      message: `Shared with ${sharedCount.success} friend(s)`,
      sharedCount: sharedCount.success,
      failedCount: sharedCount.failed,
    }),
  };
}

async function getSharedWithMe(userId: string): Promise<APIGatewayProxyResultV2> {
  // Query all shared nuggets where recipientUserId = userId
  const sharedNuggets = await queryItems<FriendSharedNugget>({
    TableName: TableNames.friendSharedNuggets,
    KeyConditionExpression: 'recipientUserId = :userId',
    ExpressionAttributeValues: {
      ':userId': userId,
    },
  });

  // Sort by sharedAt descending (most recent first)
  sharedNuggets.sort((a, b) => b.sharedAt - a.sharedAt);

  // Count unread
  const unreadCount = sharedNuggets.filter(n => !n.isRead).length;

  return {
    statusCode: 200,
    body: JSON.stringify({
      sharedNuggets: sharedNuggets.map(sn => ({
        shareId: sn.shareId,
        nuggetId: sn.nuggetId,
        senderUserId: sn.senderUserId,
        senderDisplayName: sn.senderDisplayName,
        sharedAt: new Date(sn.sharedAt).toISOString(),
        isRead: sn.isRead,
        title: sn.nuggetTitle,
        summary: sn.nuggetSummary,
        sourceUrl: sn.nuggetSourceUrl,
        category: sn.nuggetCategory,
      })),
      total: sharedNuggets.length,
      unreadCount,
    }),
  };
}

async function markSharedAsRead(
  userId: string,
  shareId: string | undefined
): Promise<APIGatewayProxyResultV2> {
  if (!shareId) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Share ID required' }) };
  }

  // Get the shared nugget to verify ownership
  const sharedNugget = await getItem<FriendSharedNugget>(TableNames.friendSharedNuggets, {
    recipientUserId: userId,
    shareId,
  });

  if (!sharedNugget) {
    return { statusCode: 404, body: JSON.stringify({ error: 'Shared nugget not found' }) };
  }

  // Mark as read
  await updateItem(
    TableNames.friendSharedNuggets,
    { recipientUserId: userId, shareId },
    { isRead: true }
  );

  return {
    statusCode: 200,
    body: JSON.stringify({ success: true }),
  };
}

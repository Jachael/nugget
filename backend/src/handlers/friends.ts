import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { extractUserId } from '../lib/auth';
import { getItem, updateItem, TableNames } from '../lib/dynamo';
import { User, FriendRequest } from '../lib/models';
import { getMaxFriendsLimit } from '../lib/subscription';
import { sendPushNotification, NotificationType, PushNotificationPayload } from '../lib/notifications';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, ScanCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

// Generate friend code (8 chars, no ambiguous characters)
function generateFriendCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No 0/O, 1/I/l
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

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

    // GET /v1/friends - List friends
    if (method === 'GET' && path === '/v1/friends') {
      return await listFriends(userId);
    }

    // GET /v1/friends/code - Get my friend code
    if (method === 'GET' && path === '/v1/friends/code') {
      return await getFriendCode(userId);
    }

    // POST /v1/friends/add - Send friend request by code
    if (method === 'POST' && path === '/v1/friends/add') {
      return await sendFriendRequest(userId, event);
    }

    // GET /v1/friends/requests - List pending requests
    if (method === 'GET' && path === '/v1/friends/requests') {
      return await listFriendRequests(userId);
    }

    // POST /v1/friends/requests/{requestId}/accept
    if (method === 'POST' && path.includes('/accept')) {
      const requestId = event.pathParameters?.requestId;
      return await acceptFriendRequest(userId, requestId);
    }

    // POST /v1/friends/requests/{requestId}/decline
    if (method === 'POST' && path.includes('/decline')) {
      const requestId = event.pathParameters?.requestId;
      return await declineFriendRequest(userId, requestId);
    }

    // DELETE /v1/friends/{friendId} - Remove friend
    if (method === 'DELETE') {
      const friendId = event.pathParameters?.friendId;
      return await removeFriend(userId, friendId);
    }

    return {
      statusCode: 404,
      body: JSON.stringify({ error: 'Not found' }),
    };
  } catch (error) {
    console.error('Friends handler error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
}

async function listFriends(userId: string): Promise<APIGatewayProxyResultV2> {
  const user = await getItem<User>(TableNames.users, { userId });
  if (!user) {
    return { statusCode: 404, body: JSON.stringify({ error: 'User not found' }) };
  }

  const friendIds = user.friends || [];

  // Get friend details
  const friends = await Promise.all(
    friendIds.map(async (friendId) => {
      const friend = await getItem<User>(TableNames.users, { userId: friendId });
      if (friend) {
        return {
          userId: friend.userId,
          displayName: friend.firstName || friend.name || 'Friend',
          friendCode: friend.friendCode,
        };
      }
      return null;
    })
  );

  return {
    statusCode: 200,
    body: JSON.stringify({
      friends: friends.filter(f => f !== null),
      count: friends.filter(f => f !== null).length,
    }),
  };
}

async function getFriendCode(userId: string): Promise<APIGatewayProxyResultV2> {
  const user = await getItem<User>(TableNames.users, { userId });
  if (!user) {
    return { statusCode: 404, body: JSON.stringify({ error: 'User not found' }) };
  }

  // Generate code if doesn't exist
  if (!user.friendCode) {
    const friendCode = generateFriendCode();
    await updateItem(
      TableNames.users,
      { userId },
      { friendCode }
    );
    return {
      statusCode: 200,
      body: JSON.stringify({ friendCode }),
    };
  }

  return {
    statusCode: 200,
    body: JSON.stringify({ friendCode: user.friendCode }),
  };
}

async function sendFriendRequest(userId: string, event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  if (!event.body) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Request body required' }) };
  }

  const { friendCode } = JSON.parse(event.body);
  if (!friendCode) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Friend code required' }) };
  }

  const currentUser = await getItem<User>(TableNames.users, { userId });
  if (!currentUser) {
    return { statusCode: 404, body: JSON.stringify({ error: 'User not found' }) };
  }

  // Check friend limit
  const maxFriends = getMaxFriendsLimit(currentUser);
  const currentFriends = currentUser.friends?.length || 0;
  if (maxFriends !== -1 && currentFriends >= maxFriends) {
    return {
      statusCode: 429,
      body: JSON.stringify({
        error: 'Friend limit reached',
        code: 'FRIEND_LIMIT_REACHED',
        limit: maxFriends,
        message: `You've reached your limit of ${maxFriends} friends. Upgrade to add more!`
      }),
    };
  }

  // Find user by friend code via scan (would use GSI in production)
  const allUsers = await getAllUsersByFriendCode(friendCode.toUpperCase());

  if (!allUsers || allUsers.length === 0) {
    return { statusCode: 404, body: JSON.stringify({ error: 'Friend code not found' }) };
  }

  const targetUser = allUsers[0];

  // Can't add yourself
  if (targetUser.userId === userId) {
    return { statusCode: 400, body: JSON.stringify({ error: "Can't add yourself as a friend" }) };
  }

  // Check if already friends
  if (currentUser.friends?.includes(targetUser.userId)) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Already friends' }) };
  }

  // Check if request already pending
  const existingRequest = targetUser.friendRequests?.find(
    r => r.fromUserId === userId && r.status === 'pending'
  );
  if (existingRequest) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Friend request already sent' }) };
  }

  // Create friend request
  const request: FriendRequest = {
    requestId: uuidv4(),
    fromUserId: userId,
    fromDisplayName: currentUser.firstName || currentUser.name || 'A user',
    requestedAt: Date.now(),
    status: 'pending',
  };

  const existingRequests = targetUser.friendRequests || [];
  await updateItem(
    TableNames.users,
    { userId: targetUser.userId },
    { friendRequests: [...existingRequests, request] }
  );

  // Send push notification to target user
  try {
    if (targetUser.settings?.notificationsEnabled !== false) {
      const payload: PushNotificationPayload = {
        title: 'New Friend Request',
        body: `${request.fromDisplayName} wants to be your friend`,
        data: {
          type: 'FRIEND_REQUEST',
          fromUserId: userId,
          requestId: request.requestId,
        },
      };
      await sendPushNotification(targetUser.userId, NotificationType.NEW_CONTENT, payload);
      console.log(`Sent friend request notification to ${targetUser.userId}`);
    }
  } catch (notifError) {
    console.error('Failed to send friend request notification:', notifError);
    // Don't fail the request if notification fails
  }

  return {
    statusCode: 200,
    body: JSON.stringify({
      success: true,
      message: 'Friend request sent!',
    }),
  };
}

async function listFriendRequests(userId: string): Promise<APIGatewayProxyResultV2> {
  const user = await getItem<User>(TableNames.users, { userId });
  if (!user) {
    return { statusCode: 404, body: JSON.stringify({ error: 'User not found' }) };
  }

  const pendingRequests = (user.friendRequests || [])
    .filter(r => r.status === 'pending')
    .map(r => ({
      requestId: r.requestId,
      fromDisplayName: r.fromDisplayName,
      requestedAt: new Date(r.requestedAt).toISOString(),
    }));

  return {
    statusCode: 200,
    body: JSON.stringify({ requests: pendingRequests }),
  };
}

async function acceptFriendRequest(userId: string, requestId?: string): Promise<APIGatewayProxyResultV2> {
  if (!requestId) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Request ID required' }) };
  }

  const user = await getItem<User>(TableNames.users, { userId });
  if (!user) {
    return { statusCode: 404, body: JSON.stringify({ error: 'User not found' }) };
  }

  const request = user.friendRequests?.find(r => r.requestId === requestId);
  if (!request) {
    return { statusCode: 404, body: JSON.stringify({ error: 'Request not found' }) };
  }

  if (request.status !== 'pending') {
    return { statusCode: 400, body: JSON.stringify({ error: 'Request already processed' }) };
  }

  // Update request status and add to friends list (both users)
  const updatedRequests = (user.friendRequests || []).map(r =>
    r.requestId === requestId ? { ...r, status: 'accepted' as const } : r
  );
  const currentFriends = user.friends || [];

  // Add to current user's friends
  await updateItem(
    TableNames.users,
    { userId },
    {
      friendRequests: updatedRequests,
      friends: [...currentFriends, request.fromUserId],
    }
  );

  // Add to requester's friends
  const requester = await getItem<User>(TableNames.users, { userId: request.fromUserId });
  if (requester) {
    const requesterFriends = requester.friends || [];
    await updateItem(
      TableNames.users,
      { userId: request.fromUserId },
      { friends: [...requesterFriends, userId] }
    );

    // Send notification to requester that their request was accepted
    try {
      if (requester.settings?.notificationsEnabled !== false) {
        const accepterName = user.firstName || user.name || 'Someone';
        const payload: PushNotificationPayload = {
          title: 'Friend Request Accepted',
          body: `${accepterName} accepted your friend request`,
          data: {
            type: 'FRIEND_REQUEST_ACCEPTED',
            friendUserId: userId,
          },
        };
        await sendPushNotification(request.fromUserId, NotificationType.NEW_CONTENT, payload);
        console.log(`Sent friend request accepted notification to ${request.fromUserId}`);
      }
    } catch (notifError) {
      console.error('Failed to send friend request accepted notification:', notifError);
    }
  }

  return {
    statusCode: 200,
    body: JSON.stringify({ success: true, message: 'Friend request accepted!' }),
  };
}

async function declineFriendRequest(userId: string, requestId?: string): Promise<APIGatewayProxyResultV2> {
  if (!requestId) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Request ID required' }) };
  }

  const user = await getItem<User>(TableNames.users, { userId });
  if (!user) {
    return { statusCode: 404, body: JSON.stringify({ error: 'User not found' }) };
  }

  const updatedRequests = (user.friendRequests || []).map(r =>
    r.requestId === requestId ? { ...r, status: 'declined' as const } : r
  );

  await updateItem(
    TableNames.users,
    { userId },
    { friendRequests: updatedRequests }
  );

  return {
    statusCode: 200,
    body: JSON.stringify({ success: true }),
  };
}

async function removeFriend(userId: string, friendId?: string): Promise<APIGatewayProxyResultV2> {
  if (!friendId) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Friend ID required' }) };
  }

  const user = await getItem<User>(TableNames.users, { userId });
  if (!user) {
    return { statusCode: 404, body: JSON.stringify({ error: 'User not found' }) };
  }

  // Remove from current user's friends
  const updatedFriends = (user.friends || []).filter(f => f !== friendId);
  await updateItem(
    TableNames.users,
    { userId },
    { friends: updatedFriends }
  );

  // Remove from other user's friends too
  const friend = await getItem<User>(TableNames.users, { userId: friendId });
  if (friend) {
    const friendUpdated = (friend.friends || []).filter(f => f !== userId);
    await updateItem(
      TableNames.users,
      { userId: friendId },
      { friends: friendUpdated }
    );
  }

  return {
    statusCode: 200,
    body: JSON.stringify({ success: true }),
  };
}

// Helper to find user by friend code (would use GSI in production)
async function getAllUsersByFriendCode(friendCode: string): Promise<User[]> {
  const command = new ScanCommand({
    TableName: TableNames.users,
    FilterExpression: 'friendCode = :code',
    ExpressionAttributeValues: { ':code': friendCode },
  });

  const result = await docClient.send(command);
  return (result.Items || []) as User[];
}

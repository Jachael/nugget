import jwt from 'jsonwebtoken';
import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { verifyCognitoToken, getCognitoUserId } from './cognito';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-production';
const JWT_EXPIRY = '7d';

export interface TokenPayload {
  userId: string;
  iat?: number;
  exp?: number;
}

/**
 * Generate a JWT access token for a user
 */
export function generateAccessToken(userId: string): string {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: JWT_EXPIRY });
}

/**
 * Verify and decode a JWT access token
 */
export function verifyAccessToken(token: string): TokenPayload {
  return jwt.verify(token, JWT_SECRET) as TokenPayload;
}

/**
 * Extract userId from Authorization header in API Gateway event
 * Supports both Cognito tokens and legacy JWT tokens
 */
export async function extractUserId(event: APIGatewayProxyEventV2): Promise<string | null> {
  const authHeader = event.headers?.authorization || event.headers?.Authorization;
  if (!authHeader) {
    return null;
  }

  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return null;
  }

  const token = parts[1];

  // Try Cognito verification first
  try {
    const cognitoUser = await verifyCognitoToken(token);
    if (cognitoUser) {
      return getCognitoUserId(cognitoUser.sub);
    }
  } catch (error) {
    // Not a Cognito token, try legacy JWT
  }

  // Fall back to legacy JWT verification
  try {
    const payload = verifyAccessToken(token);
    return payload.userId;
  } catch (error) {
    console.error('Token verification failed:', error);
    return null;
  }
}

/**
 * Verify Apple ID token (stub for MVP/local testing)
 * In production, this should validate against Apple's public keys
 */
export async function verifyAppleToken(idToken: string): Promise<{ sub: string } | null> {
  // For local/dev testing, accept any token that looks like a mock token
  if (process.env.STAGE === 'dev' && idToken.startsWith('mock_')) {
    return { sub: idToken };
  }

  // In production, implement proper Apple token verification:
  // 1. Decode the JWT header to get the key ID
  // 2. Fetch Apple's public keys from https://appleid.apple.com/auth/keys
  // 3. Verify the signature using the appropriate public key
  // 4. Validate claims (iss, aud, exp, etc.)
  // 5. Return the subject (sub) claim

  // For now, we'll accept the token as-is for development
  try {
    const decoded = jwt.decode(idToken) as { sub?: string } | null;
    if (decoded && decoded.sub) {
      return { sub: decoded.sub };
    }
  } catch (error) {
    console.error('Error decoding Apple token:', error);
  }

  return null;
}

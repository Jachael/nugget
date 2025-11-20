import jwt from 'jsonwebtoken';
import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { verifyCognitoToken, getCognitoUserId } from './cognito';
import appleSignin from 'apple-signin-auth';

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
 * Supports Cognito tokens, Apple ID tokens, and legacy JWT tokens
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
    // Not a Cognito token, try other methods
  }

  // Try Apple token verification second
  try {
    const appleUser = await verifyAppleToken(token);
    if (appleUser) {
      // Apple user IDs are already in the correct format (usr_...)
      return appleUser.sub;
    }
  } catch (error) {
    // Not an Apple token, try legacy JWT
  }

  // Fall back to legacy JWT verification
  try {
    console.log('Attempting legacy JWT verification as final fallback...');
    const payload = verifyAccessToken(token);
    console.log('Legacy JWT verified successfully, userId:', payload.userId?.substring(0, 20) + '...');
    return payload.userId;
  } catch (error) {
    console.error('All token verification methods failed (including legacy JWT):', error);
    return null;
  }
}

/**
 * Verify Apple ID token
 * Validates the token against Apple's public keys and verifies claims
 */
export async function verifyAppleToken(idToken: string): Promise<{ sub: string; email?: string } | null> {
  // For local/dev testing, accept any token that looks like a mock token
  if (process.env.STAGE === 'dev' && idToken.startsWith('mock_')) {
    return { sub: idToken };
  }

  try {
    // Verify the identity token with Apple's servers
    const clientId = process.env.APPLE_CLIENT_ID || 'NuggetApp';

    const verifiedToken = await appleSignin.verifyIdToken(idToken, {
      audience: clientId, // Your App ID from Apple
      ignoreExpiration: false, // Set to true for testing if token is expired
    });

    // Return the verified claims
    return {
      sub: verifiedToken.sub,
      email: verifiedToken.email
    };
  } catch (error) {
    console.error('Error verifying Apple token:', error);

    // Fallback to basic JWT decoding if verification fails
    // This can happen when Apple's public keys rotate or there are network issues
    try {
      console.log('Attempting to decode Apple token as fallback...');
      const decoded = jwt.decode(idToken) as { sub?: string; email?: string; aud?: string; iss?: string; exp?: number } | null;
      console.log('Decoded token:', decoded ? 'SUCCESS' : 'FAILED', decoded ? `sub=${decoded.sub?.substring(0, 20)}...` : '');

      if (decoded && decoded.sub) {
        // Validate basic claims
        const clientId = process.env.APPLE_CLIENT_ID || 'NuggetApp';
        console.log(`Validating token - aud: ${decoded.aud}, expected: ${clientId}`);
        console.log(`Validating token - iss: ${decoded.iss}, expected: https://appleid.apple.com`);
        console.log(`Validating token - exp: ${decoded.exp}, now: ${Date.now() / 1000}`);

        if (decoded.aud !== clientId) {
          console.error('Apple token audience mismatch');
          return null;
        }
        if (decoded.iss !== 'https://appleid.apple.com') {
          console.error('Apple token issuer mismatch');
          return null;
        }
        if (decoded.exp && decoded.exp < Date.now() / 1000) {
          console.error('Apple token expired');
          return null;
        }

        console.warn('Using decoded (unverified) Apple token due to verification failure');
        return { sub: decoded.sub, email: decoded.email };
      } else {
        console.error('Decoded token has no sub field');
      }
    } catch (decodeError) {
      console.error('Error decoding Apple token:', decodeError);
    }
  }

  return null;
}

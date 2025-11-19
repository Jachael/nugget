import { CognitoJwtVerifier } from 'aws-jwt-verify';

const USER_POOL_ID = process.env.COGNITO_USER_POOL_ID || 'eu-west-1_1zILS9mOj';
const CLIENT_ID = process.env.COGNITO_CLIENT_ID || '6roa95ol200brl6tsrlnkckpd6';

// Create a verifier instance
const verifier = CognitoJwtVerifier.create({
  userPoolId: USER_POOL_ID,
  tokenUse: 'id',
  clientId: CLIENT_ID,
});

export interface CognitoUser {
  sub: string;
  email?: string;
  name?: string;
  email_verified?: boolean;
}

/**
 * Verify a Cognito ID token
 */
export async function verifyCognitoToken(token: string): Promise<CognitoUser | null> {
  try {
    const payload = await verifier.verify(token);
    return {
      sub: payload.sub,
      email: payload.email as string | undefined,
      name: payload.name as string | undefined,
      email_verified: payload.email_verified as boolean | undefined,
    };
  } catch (error) {
    console.error('Token verification failed:', error);
    return null;
  }
}

/**
 * Extract user ID from Cognito token
 */
export function getCognitoUserId(cognitoSub: string): string {
  // Use Cognito sub as the basis for our internal user ID
  return `usr_${cognitoSub}`;
}
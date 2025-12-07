import { User } from './models';

export type SubscriptionTier = 'free' | 'plus' | 'pro';

export interface SubscriptionLimits {
  dailyNuggetLimit: number;
  hasAutoProcess: boolean;
  hasRSSSupport: boolean;
  hasPriorityProcessing: boolean;
}

export const SUBSCRIPTION_LIMITS: Record<SubscriptionTier, SubscriptionLimits> = {
  free: {
    dailyNuggetLimit: 3,
    hasAutoProcess: false,
    hasRSSSupport: false,
    hasPriorityProcessing: false,
  },
  plus: {
    dailyNuggetLimit: 10,
    hasAutoProcess: true,
    hasRSSSupport: false,
    hasPriorityProcessing: false,
  },
  pro: {
    dailyNuggetLimit: Number.MAX_SAFE_INTEGER,
    hasAutoProcess: true,
    hasRSSSupport: true,
    hasPriorityProcessing: true,
  },
};

export const PRODUCT_ID_TO_TIER: Record<string, SubscriptionTier> = {
  'com.nugget.plus': 'plus',
  'com.nugget.pro': 'pro',
};

/**
 * Get the subscription tier from product ID
 */
export function getTierFromProductId(productId: string): SubscriptionTier {
  return PRODUCT_ID_TO_TIER[productId] || 'free';
}

/**
 * Get the limits for a subscription tier
 */
export function getLimitsForTier(tier: SubscriptionTier): SubscriptionLimits {
  return SUBSCRIPTION_LIMITS[tier];
}

/**
 * Check if a user's subscription is active
 */
export function isSubscriptionActive(user: User): boolean {
  if (!user.subscriptionTier || user.subscriptionTier === 'free') {
    return false;
  }

  if (!user.subscriptionExpiresAt) {
    return false;
  }

  const expirationDate = new Date(user.subscriptionExpiresAt);
  const now = new Date();

  return expirationDate > now;
}

/**
 * Get the effective subscription tier for a user
 * (returns 'free' if subscription is expired)
 */
export function getEffectiveTier(user: User): SubscriptionTier {
  if (!user.subscriptionTier) {
    return 'free';
  }

  if (user.subscriptionTier === 'free') {
    return 'free';
  }

  if (!isSubscriptionActive(user)) {
    return 'free';
  }

  return user.subscriptionTier;
}

/**
 * Check if user has access to a feature
 */
export function hasFeatureAccess(user: User, feature: keyof SubscriptionLimits): boolean {
  const tier = getEffectiveTier(user);
  const limits = getLimitsForTier(tier);

  const featureValue = limits[feature];
  if (typeof featureValue === 'boolean') {
    return featureValue;
  }

  return false;
}

/**
 * Get daily nugget limit for user
 */
export function getDailyNuggetLimit(user: User): number {
  const tier = getEffectiveTier(user);
  const limits = getLimitsForTier(tier);
  return limits.dailyNuggetLimit;
}

/**
 * Verify Apple App Store receipt (stub - needs actual implementation)
 * In production, this should call Apple's App Store Server API
 */
export async function verifyAppleReceipt(receiptData: string): Promise<{
  valid: boolean;
  transactionId?: string;
  productId?: string;
  expirationDate?: string;
  error?: string;
}> {
  try {
    // TODO: Implement actual Apple App Store Server API verification
    // For now, this is a stub that would need to be replaced with actual Apple verification
    // See: https://developer.apple.com/documentation/appstoreserverapi

    console.log('Receipt verification called - stub implementation');

    // In production, you would:
    // 1. Decode the receipt data
    // 2. Call Apple's verifyReceipt endpoint or use App Store Server API
    // 3. Validate the response
    // 4. Extract subscription information

    return {
      valid: false,
      error: 'Receipt verification not implemented - requires Apple App Store Server API integration',
    };
  } catch (error) {
    console.error('Receipt verification error:', error);
    return {
      valid: false,
      error: 'Receipt verification failed',
    };
  }
}

/**
 * Calculate subscription expiration date based on purchase
 * Apple subscriptions are monthly by default
 */
export function calculateExpirationDate(purchaseDate: Date = new Date()): string {
  const expirationDate = new Date(purchaseDate);
  expirationDate.setMonth(expirationDate.getMonth() + 1);
  return expirationDate.toISOString();
}

/**
 * Check if receipt verification is needed (once per day)
 */
export function shouldVerifyReceipt(user: User): boolean {
  if (!user.lastReceiptVerification) {
    return true;
  }

  const lastVerification = new Date(user.lastReceiptVerification);
  const now = new Date();
  const daysSinceLastVerification = Math.floor(
    (now.getTime() - lastVerification.getTime()) / (1000 * 60 * 60 * 24)
  );

  return daysSinceLastVerification >= 1;
}

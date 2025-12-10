import { User, SubscriptionTier } from './models';

export type AutoProcessMode = 'none' | 'windows' | 'interval';

export interface SubscriptionLimits {
  dailyNuggetLimit: number;
  dailySwipeSessions: number; // -1 for unlimited
  hasAutoProcess: boolean;
  hasRSSSupport: boolean;
  hasPriorityProcessing: boolean;
  // New premium feature limits
  autoProcessMode: AutoProcessMode;
  maxRSSFeeds: number;
  maxCustomRSSFeeds: number; // Custom user-added feeds (Ultimate only)
  hasCustomDigests: boolean;
  hasOfflineMode: boolean;
  hasReaderMode: boolean;
  hasNotificationConfig: boolean;
  maxFriends: number; // -1 for unlimited
}

export const SUBSCRIPTION_LIMITS: Record<SubscriptionTier, SubscriptionLimits> = {
  free: {
    dailyNuggetLimit: 5,
    dailySwipeSessions: 3,
    hasAutoProcess: false,
    hasRSSSupport: false,
    hasPriorityProcessing: false,
    autoProcessMode: 'none',
    maxRSSFeeds: 0,
    maxCustomRSSFeeds: 0,
    hasCustomDigests: false,
    hasOfflineMode: false,
    hasReaderMode: false,
    hasNotificationConfig: false,
    maxFriends: 5,
  },
  pro: {
    dailyNuggetLimit: 50,
    dailySwipeSessions: -1, // Unlimited
    hasAutoProcess: true,
    hasRSSSupport: true,
    hasPriorityProcessing: false,
    autoProcessMode: 'windows', // Fixed 3x daily windows (morning, afternoon, evening)
    maxRSSFeeds: 10,
    maxCustomRSSFeeds: 0,
    hasCustomDigests: false,
    hasOfflineMode: false,
    hasReaderMode: true,
    hasNotificationConfig: false,
    maxFriends: 25,
  },
  ultimate: {
    dailyNuggetLimit: -1, // Unlimited
    dailySwipeSessions: -1, // Unlimited
    hasAutoProcess: true,
    hasRSSSupport: true,
    hasPriorityProcessing: true,
    autoProcessMode: 'interval', // User-configurable intervals (2, 4, 6, 8, 12 hours)
    maxRSSFeeds: 50,
    maxCustomRSSFeeds: 10,
    hasCustomDigests: true,
    hasOfflineMode: true,
    hasReaderMode: true,
    hasNotificationConfig: true,
    maxFriends: -1, // Unlimited
  },
};

export const PRODUCT_ID_TO_TIER: Record<string, SubscriptionTier> = {
  'com.nugget.pro': 'pro',
  'com.nugget.ultimate': 'ultimate',
};

/**
 * Get the subscription tier from product ID
 */
export function getTierFromProductId(productId: string): SubscriptionTier {
  return PRODUCT_ID_TO_TIER[productId] as SubscriptionTier || 'free';
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
export async function verifyAppleReceipt(_receiptData: string): Promise<{
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

/**
 * Get auto-process mode for user's tier
 */
export function getAutoProcessMode(user: User): AutoProcessMode {
  const tier = getEffectiveTier(user);
  const limits = getLimitsForTier(tier);
  return limits.autoProcessMode;
}

/**
 * Get max RSS feeds for user's tier
 */
export function getMaxRSSFeeds(user: User): number {
  const tier = getEffectiveTier(user);
  const limits = getLimitsForTier(tier);
  return limits.maxRSSFeeds;
}

/**
 * Check if user can create custom digests
 */
export function canCreateCustomDigests(user: User): boolean {
  const tier = getEffectiveTier(user);
  const limits = getLimitsForTier(tier);
  return limits.hasCustomDigests;
}

/**
 * Check if user has offline mode access
 */
export function hasOfflineModeAccess(user: User): boolean {
  const tier = getEffectiveTier(user);
  const limits = getLimitsForTier(tier);
  return limits.hasOfflineMode;
}

/**
 * Check if user has reader mode access
 */
export function hasReaderModeAccess(user: User): boolean {
  const tier = getEffectiveTier(user);
  const limits = getLimitsForTier(tier);
  return limits.hasReaderMode;
}

/**
 * Check if user can configure notifications
 */
export function canConfigureNotifications(user: User): boolean {
  const tier = getEffectiveTier(user);
  const limits = getLimitsForTier(tier);
  return limits.hasNotificationConfig;
}

/**
 * Get daily swipe session limit for user
 */
export function getDailySwipeSessionLimit(user: User): number {
  const tier = getEffectiveTier(user);
  const limits = getLimitsForTier(tier);
  return limits.dailySwipeSessions;
}

/**
 * Get max friends limit for user
 */
export function getMaxFriendsLimit(user: User): number {
  const tier = getEffectiveTier(user);
  const limits = getLimitsForTier(tier);
  return limits.maxFriends;
}

/**
 * Get max custom RSS feeds limit for user
 */
export function getMaxCustomRSSFeeds(user: User): number {
  const tier = getEffectiveTier(user);
  const limits = getLimitsForTier(tier);
  return limits.maxCustomRSSFeeds;
}

/**
 * Valid interval hours for Ultimate tier auto-processing
 */
export const VALID_INTERVAL_HOURS = [2, 4, 6, 8, 12] as const;

/**
 * Validate interval hours
 */
export function isValidIntervalHours(hours: number): boolean {
  return VALID_INTERVAL_HOURS.includes(hours as typeof VALID_INTERVAL_HOURS[number]);
}

/**
 * Pro tier processing windows (fixed times)
 */
export const PRO_PROCESSING_WINDOWS = {
  morning: { hour: 7, minute: 30 },   // 7:30 AM
  afternoon: { hour: 13, minute: 30 }, // 1:30 PM
  evening: { hour: 19, minute: 30 },   // 7:30 PM
} as const;

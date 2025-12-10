export type SubscriptionTier = 'free' | 'pro' | 'ultimate';

export interface UserPreferences {
  interests: string[]; // e.g., ['sport', 'finance', 'technology', 'career']
  dailyNuggetLimit: number; // 1 for free, more for paid
  subscriptionTier: SubscriptionTier;
  customCategories?: string[];
  categoryWeights?: Record<string, number>; // For premium: preference weighting
}

// User Settings for notifications and premium features
export interface UserSettings {
  notificationsEnabled?: boolean;
  // Notification preferences (Ultimate only)
  notifyOnAllNuggets?: boolean;
  notifyCategories?: string[]; // e.g., ["technology", "sport"]
  notifyFeeds?: string[]; // e.g., ["techcrunch", "hackernews"]
  notifyDigests?: string[]; // e.g., ["digest-123"]
  // Reader mode preference (Ultimate only)
  readerModeEnabled?: boolean;
  // Offline settings (Ultimate only)
  offlineEnabled?: boolean;
  offlineLimitMB?: number;
}

// Daily usage tracking
export interface DailyUsage {
  date: string; // YYYY-MM-DD format (UTC)
  nuggetsCreated: number;
  swipeSessionsStarted: number;
}

// Friend request model
export interface FriendRequest {
  requestId: string;
  fromUserId: string;
  fromDisplayName?: string;
  requestedAt: number;
  status: 'pending' | 'accepted' | 'declined';
}

export interface User {
  userId: string;
  appleSub?: string;
  googleSub?: string;
  cognitoSub?: string;
  email?: string;
  name?: string;
  firstName?: string;
  lastName?: string;
  picture?: string;
  createdAt: number;
  lastActiveDate: string;
  streak: number;
  preferences?: UserPreferences;
  onboardingCompleted?: boolean;
  settings?: UserSettings;
  // Subscription fields
  subscriptionTier?: SubscriptionTier;
  subscriptionExpiresAt?: string; // ISO date string
  originalTransactionId?: string;
  lastReceiptVerification?: number; // Timestamp of last verification
  // Auto-processing fields
  autoProcessEnabled?: boolean;
  processingScheduleId?: string;
  // Usage tracking (for free tier limits)
  dailyUsage?: DailyUsage;
  // Friends feature
  friendCode?: string; // 8-char unique code for adding friends
  friends?: string[]; // Array of friend userIds
  friendRequests?: FriendRequest[]; // Pending friend requests
}

export interface Nugget {
  userId: string;
  nuggetId: string;
  sourceUrl: string;
  sourceType: 'url' | 'tweet' | 'linkedin' | 'youtube' | 'rss' | 'other';
  rawTitle?: string;
  title?: string; // Processed/cleaned title
  rawText?: string;
  rawDescription?: string; // Meta description from scraping
  status: 'inbox' | 'digest' | 'completed' | 'archived';
  processingState: 'scraped' | 'processing' | 'ready'; // New: track AI processing state
  category?: string;
  summary?: string;
  keyPoints?: string[];
  question?: string;
  priorityScore: number;
  createdAt: number;
  lastReviewedAt?: number;
  timesReviewed: number;
  // Grouped nugget support
  isGrouped?: boolean; // True if this nugget combines multiple sources
  sourceNuggetIds?: string[]; // IDs of original nuggets that were grouped together
  sourceUrls?: string[]; // All URLs that were combined into this nugget
  individualSummaries?: Array<{
    nuggetId: string;
    title: string;
    summary: string;
    keyPoints: string[];
    sourceUrl: string;
  }>; // Individual summaries for each source in a grouped nugget
}

export interface Session {
  userId: string;
  sessionId: string;
  date: string;
  startedAt: number;
  completedAt?: number;
  nuggetIds: string[];
  completedCount: number;
  synthesis?: {
    summary: string;
    keyPoints: string[];
    question: string;
    generatedAt: number;
  };
}

export interface CreateNuggetInput {
  sourceUrl: string;
  sourceType: 'url' | 'tweet' | 'linkedin' | 'youtube' | 'other';
  rawTitle?: string;
  rawText?: string;
  category?: string;
}

export interface PatchNuggetInput {
  status?: 'inbox' | 'completed' | 'archived';
  category?: string;
}

export interface AuthResponse {
  userId: string;
  accessToken: string;
  streak: number;
  firstName?: string;
  subscriptionTier?: string;
  subscriptionExpiresAt?: string;
}

export interface NuggetResponse {
  nuggetId: string;
  sourceUrl: string;
  sourceType: string;
  title?: string;
  category?: string;
  status: string;
  summary?: string;
  keyPoints?: string[];
  question?: string;
  createdAt: string;
  lastReviewedAt?: string;
  timesReviewed: number;
  // Grouped nugget fields
  isGrouped?: boolean;
  sourceNuggetIds?: string[];
  sourceUrls?: string[];
  individualSummaries?: Array<{
    nuggetId: string;
    title: string;
    summary: string;
    keyPoints: string[];
    sourceUrl: string;
  }>;
}

export interface SessionResponse {
  sessionId: string;
  nuggets: NuggetResponse[];
}

export interface LLMSummarisationResult {
  title: string;
  summary: string;
  keyPoints: string[];
  question: string;
}

export interface UpdatePreferencesInput {
  interests?: string[];
  dailyNuggetLimit?: number;
  subscriptionTier?: SubscriptionTier;
  customCategories?: string[];
  categoryWeights?: Record<string, number>;
}

export interface PreferencesResponse {
  interests: string[];
  dailyNuggetLimit: number;
  subscriptionTier: SubscriptionTier;
  customCategories?: string[];
  categoryWeights?: Record<string, number>;
  onboardingCompleted: boolean;
}

// Predefined categories
export const DEFAULT_CATEGORIES = [
  'sport',
  'finance',
  'technology',
  'career',
  'health',
  'science',
  'business',
  'entertainment',
  'politics',
  'education'
] as const;

// RSS Feed Models
export interface UserFeedSubscription {
  userId: string;
  feedId: string; // Unique identifier for the feed subscription
  rssFeedId: string; // ID from RSS_CATALOG
  feedName: string;
  feedUrl: string;
  category: string;
  subscribedAt: number;
  isActive: boolean;
  lastFetchedAt?: number;
}

export interface FeedItem {
  title: string;
  link: string;
  pubDate?: string;
  content?: string;
  contentSnippet?: string;
  creator?: string;
  categories?: string[];
  isoDate?: string;
  guid?: string;
}

export interface ParsedFeed {
  feedId: string;
  feedName: string;
  items: FeedItem[];
  fetchedAt: number;
}

export interface RecapNugget {
  feedId: string;
  feedName: string;
  articles: Array<{
    title: string;
    link: string;
    snippet: string;
  }>;
  summary: string;
  keyPoints: string[];
  createdAt: number;
}

export interface SubscribeFeedInput {
  rssFeedId: string; // ID from RSS_CATALOG
  subscribe: boolean; // true to subscribe, false to unsubscribe
}

export interface FeedSubscriptionResponse {
  feedId: string;
  rssFeedId: string;
  feedName: string;
  category: string;
  isActive: boolean;
  subscribedAt: string;
}

export interface GetFeedsResponse {
  catalog: Array<{
    id: string;
    name: string;
    url: string;
    category: string;
    description: string;
    isPremium: boolean;
    isSubscribed: boolean;
  }>;
  subscriptions: FeedSubscriptionResponse[];
}

// Processing Schedule Models
export type ProcessingMode = 'windows' | 'interval';

export interface ProcessingSchedule {
  userId: string;
  scheduleId: string;
  frequency: 'daily' | 'twice_daily' | 'weekly' | 'interval';
  preferredTime: string; // "09:00" format (used for windows start time)
  timezone: string;
  enabled: boolean;
  lastRun?: string;
  nextRun?: string;
  createdAt: number;
  updatedAt: number;
  // New fields for tier-based processing
  processingMode?: ProcessingMode; // 'windows' for Pro, 'interval' for Ultimate
  intervalHours?: number; // 2, 4, 6, 8, or 12 hours (Ultimate only)
}

// Device Token Models
export interface DeviceToken {
  userId: string;
  deviceToken: string;
  platform: 'ios' | 'android';
  endpointArn?: string;
  createdAt: number;
  updatedAt: number;
}

// Fetched Article Tracking (for RSS deduplication)
export interface FetchedArticle {
  userId: string;
  articleId: string; // guid or hash of sourceUrl
  rssFeedId: string;
  sourceUrl: string;
  guid?: string;
  fetchedAt: number;
  nuggetId?: string; // If converted to nugget
  ttl: number; // TTL for auto-deletion (30 days)
}

// Custom Digest (Ultimate Only)
// Digest frequency options
export type DigestFrequency = 'with_schedule' | 'once_daily' | 'twice_daily' | 'three_times_daily';

export interface CustomDigest {
  userId: string;
  digestId: string;
  name: string; // User-defined name like "My Tech Roundup"
  feedIds: string[]; // Array of rssFeedId to combine
  createdAt: number;
  updatedAt: number;
  lastGeneratedAt?: number;
  isEnabled: boolean;
  // Configuration options
  articlesPerDigest?: number; // How many articles to include (default: 5)
  frequency?: DigestFrequency; // How often to generate (default: with_schedule)
}

// API Input/Response for Custom Digests
export interface CreateDigestInput {
  name: string;
  feedIds: string[];
  articlesPerDigest?: number;
  frequency?: DigestFrequency;
}

export interface UpdateDigestInput {
  name?: string;
  feedIds?: string[];
  isEnabled?: boolean;
  articlesPerDigest?: number;
  frequency?: DigestFrequency;
}

export interface DigestResponse {
  digestId: string;
  name: string;
  feedIds: string[];
  isEnabled: boolean;
  lastGeneratedAt?: string;
  createdAt: string;
  articlesPerDigest: number;
  frequency: DigestFrequency;
}

// API Input/Response for User Settings
export interface UpdateUserSettingsInput {
  notificationsEnabled?: boolean;
  notifyOnAllNuggets?: boolean;
  notifyCategories?: string[];
  notifyFeeds?: string[];
  notifyDigests?: string[];
  readerModeEnabled?: boolean;
  offlineEnabled?: boolean;
}

// Waitlist for TestFlight beta
export interface WaitlistEntry {
  email: string; // PK
  signedUpAt: number;
  status: 'pending' | 'invited' | 'joined';
  invitedAt?: number;
  source?: string; // 'landing', 'referral', etc.
}

// Feedback system
export interface FeedbackItem {
  feedbackId: string; // PK
  userId: string;
  userDisplayName?: string;
  title: string;
  description: string;
  category: 'feature' | 'bug' | 'improvement';
  status: 'open' | 'planned' | 'in-progress' | 'completed' | 'declined';
  voteCount: number;
  createdAt: number;
  updatedAt: number;
}

export interface FeedbackVote {
  feedbackId: string; // PK
  odinguserId: string; // SK
  votedAt: number;
}

// Custom RSS Feeds (Ultimate only)
export interface CustomRSSFeed {
  userId: string; // PK
  feedId: string; // SK
  url: string;
  name: string;
  description?: string;
  iconUrl?: string;
  category?: string;
  createdAt: number;
  lastFetchedAt?: number;
  isValid: boolean;
}

// Friend-shared nuggets (nuggets shared between friends)
export interface FriendSharedNugget {
  recipientUserId: string; // PK - who receives the share
  shareId: string; // SK - unique share ID
  nuggetId: string;
  senderUserId: string;
  senderDisplayName: string;
  sharedAt: number;
  isRead: boolean;
  // Denormalized nugget data for display
  nuggetTitle?: string;
  nuggetSummary?: string;
  nuggetSourceUrl?: string;
  nuggetCategory?: string;
}

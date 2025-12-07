export interface UserPreferences {
  interests: string[]; // e.g., ['sport', 'finance', 'technology', 'career']
  dailyNuggetLimit: number; // 1 for free, more for paid
  subscriptionTier: 'free' | 'premium';
  customCategories?: string[];
  categoryWeights?: Record<string, number>; // For premium: preference weighting
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
  settings?: Record<string, unknown>;
}

export interface Nugget {
  userId: string;
  nuggetId: string;
  sourceUrl: string;
  sourceType: 'url' | 'tweet' | 'linkedin' | 'youtube' | 'other';
  rawTitle?: string;
  title?: string; // Processed/cleaned title
  rawText?: string;
  rawDescription?: string; // Meta description from scraping
  status: 'inbox' | 'completed' | 'archived';
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
  subscriptionTier?: 'free' | 'premium';
  customCategories?: string[];
  categoryWeights?: Record<string, number>;
}

export interface PreferencesResponse {
  interests: string[];
  dailyNuggetLimit: number;
  subscriptionTier: 'free' | 'premium';
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

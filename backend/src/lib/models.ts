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
  cognitoSub?: string;
  email?: string;
  name?: string;
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

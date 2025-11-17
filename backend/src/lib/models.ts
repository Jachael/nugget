export interface User {
  userId: string;
  appleSub: string;
  createdAt: number;
  lastActiveDate: string;
  streak: number;
  settings?: Record<string, unknown>;
}

export interface Nugget {
  userId: string;
  nuggetId: string;
  sourceUrl: string;
  sourceType: 'url' | 'tweet' | 'linkedin' | 'youtube' | 'other';
  rawTitle?: string;
  rawText?: string;
  status: 'inbox' | 'completed' | 'archived';
  category?: string;
  summary?: string;
  keyPoints?: string[];
  question?: string;
  priorityScore: number;
  createdAt: number;
  lastReviewedAt?: number;
  timesReviewed: number;
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
}

export interface SessionResponse {
  sessionId: string;
  nuggets: NuggetResponse[];
}

export interface LLMSummarisationResult {
  summary: string;
  keyPoints: string[];
  question: string;
}

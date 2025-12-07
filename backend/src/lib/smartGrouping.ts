import { Nugget } from './models';

/**
 * Smart grouping logic for auto-processing
 * Groups nuggets by category/source similarity for better context
 */

export interface NuggetGroup {
  category: string;
  nuggets: Nugget[];
  score: number; // Similarity score for the group
}

const CATEGORY_KEYWORDS: Record<string, string[]> = {
  technology: ['tech', 'software', 'ai', 'artificial intelligence', 'code', 'programming', 'developer', 'app', 'startup', 'saas', 'cloud', 'web', 'mobile', 'computer', 'digital', 'cyber', 'data'],
  business: ['business', 'entrepreneur', 'company', 'market', 'revenue', 'profit', 'sales', 'strategy', 'management', 'ceo', 'startup', 'venture', 'investment', 'corporate'],
  finance: ['finance', 'money', 'stock', 'investment', 'bank', 'economy', 'trading', 'market', 'crypto', 'bitcoin', 'portfolio', 'fund', 'financial', 'investor'],
  science: ['science', 'research', 'study', 'discovery', 'experiment', 'scientist', 'physics', 'chemistry', 'biology', 'medical', 'clinical', 'academic'],
  health: ['health', 'fitness', 'wellness', 'medical', 'diet', 'nutrition', 'exercise', 'mental health', 'therapy', 'doctor', 'hospital', 'medicine', 'disease'],
  sport: ['sport', 'football', 'basketball', 'soccer', 'tennis', 'athlete', 'team', 'game', 'championship', 'fitness', 'training', 'coach'],
  career: ['career', 'job', 'work', 'employment', 'hiring', 'interview', 'resume', 'professional', 'workplace', 'leadership', 'skills'],
  culture: ['culture', 'art', 'music', 'film', 'movie', 'book', 'entertainment', 'celebrity', 'fashion', 'design', 'creative'],
  politics: ['politics', 'government', 'election', 'policy', 'law', 'congress', 'senate', 'president', 'political', 'vote', 'legislation'],
  education: ['education', 'learning', 'school', 'university', 'student', 'teacher', 'course', 'study', 'academic', 'training', 'degree'],
};

/**
 * Detect category based on content keywords
 */
export function detectCategory(nugget: Nugget): string {
  // If nugget already has a category, use it
  if (nugget.category) {
    return nugget.category;
  }

  const content = [
    nugget.title || '',
    nugget.rawTitle || '',
    nugget.summary || '',
    nugget.rawDescription || '',
    ...(nugget.keyPoints || []),
  ].join(' ').toLowerCase();

  const categoryScores: Record<string, number> = {};

  // Score each category based on keyword matches
  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    let score = 0;
    for (const keyword of keywords) {
      if (content.includes(keyword)) {
        score += 1;
      }
    }
    categoryScores[category] = score;
  }

  // Find category with highest score
  const topCategory = Object.entries(categoryScores)
    .filter(([_, score]) => score > 0)
    .sort((a, b) => b[1] - a[1])[0];

  return topCategory ? topCategory[0] : 'other';
}

/**
 * Calculate similarity between two nuggets based on:
 * - Category match
 * - Source domain match
 * - Content overlap
 */
export function calculateSimilarity(nugget1: Nugget, nugget2: Nugget): number {
  let score = 0;

  // Category similarity (40 points)
  const cat1 = nugget1.category || detectCategory(nugget1);
  const cat2 = nugget2.category || detectCategory(nugget2);
  if (cat1 === cat2) {
    score += 40;
  }

  // Source domain similarity (30 points)
  try {
    const domain1 = new URL(nugget1.sourceUrl).hostname.replace('www.', '');
    const domain2 = new URL(nugget2.sourceUrl).hostname.replace('www.', '');
    if (domain1 === domain2) {
      score += 30;
    }
  } catch (e) {
    // Invalid URLs, skip domain check
  }

  // Title/content overlap (30 points)
  const words1 = new Set(
    (nugget1.title || nugget1.rawTitle || '')
      .toLowerCase()
      .split(/\s+/)
      .filter(w => w.length > 3)
  );
  const words2 = new Set(
    (nugget2.title || nugget2.rawTitle || '')
      .toLowerCase()
      .split(/\s+/)
      .filter(w => w.length > 3)
  );

  const intersection = [...words1].filter(w => words2.has(w)).length;
  const union = new Set([...words1, ...words2]).size;

  if (union > 0) {
    score += Math.round((intersection / union) * 30);
  }

  return score; // 0-100 scale
}

/**
 * Group nuggets by category and similarity
 * Returns groups sorted by relevance
 */
export function groupNuggetsByCategory(nuggets: Nugget[]): NuggetGroup[] {
  if (nuggets.length === 0) {
    return [];
  }

  // First, assign categories to all nuggets
  const categorizedNuggets = nuggets.map(nugget => ({
    ...nugget,
    detectedCategory: nugget.category || detectCategory(nugget),
  }));

  // Group by category
  const categoryMap = new Map<string, typeof categorizedNuggets>();
  for (const nugget of categorizedNuggets) {
    const category = nugget.detectedCategory;
    if (!categoryMap.has(category)) {
      categoryMap.set(category, []);
    }
    categoryMap.get(category)!.push(nugget);
  }

  // Create groups with similarity scores
  const groups: NuggetGroup[] = [];
  for (const [category, categoryNuggets] of categoryMap.entries()) {
    // Calculate average similarity within the group
    let totalSimilarity = 0;
    let comparisons = 0;

    for (let i = 0; i < categoryNuggets.length; i++) {
      for (let j = i + 1; j < categoryNuggets.length; j++) {
        totalSimilarity += calculateSimilarity(categoryNuggets[i], categoryNuggets[j]);
        comparisons++;
      }
    }

    const avgSimilarity = comparisons > 0 ? totalSimilarity / comparisons : 50;

    groups.push({
      category,
      nuggets: categoryNuggets,
      score: avgSimilarity,
    });
  }

  // Sort by group size (larger groups first) and then by similarity
  groups.sort((a, b) => {
    if (a.nuggets.length !== b.nuggets.length) {
      return b.nuggets.length - a.nuggets.length;
    }
    return b.score - a.score;
  });

  return groups;
}

/**
 * Determine optimal batch sizes based on subscription tier
 */
export function getBatchLimitForTier(tier: 'free' | 'premium'): number {
  return tier === 'premium' ? 10 : 3;
}

/**
 * Smart batch nuggets for processing
 * Groups related content together while respecting batch limits
 */
export function createProcessingBatches(
  nuggets: Nugget[],
  subscriptionTier: 'free' | 'premium'
): Nugget[][] {
  const batchLimit = getBatchLimitForTier(subscriptionTier);
  const groups = groupNuggetsByCategory(nuggets);
  const batches: Nugget[][] = [];

  for (const group of groups) {
    // Split large groups into smaller batches
    for (let i = 0; i < group.nuggets.length; i += batchLimit) {
      const batch = group.nuggets.slice(i, i + batchLimit);
      batches.push(batch);
    }
  }

  return batches;
}

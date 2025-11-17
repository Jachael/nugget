import { computePriorityScore } from '../src/lib/priority';

describe('computePriorityScore', () => {
  const now = Date.now() / 1000;

  it('should return a positive score for a new nugget', () => {
    const createdAt = now - 86400; // 1 day ago
    const score = computePriorityScore(createdAt, 0);
    expect(score).toBeGreaterThan(0);
  });

  it('should increase score for older nuggets', () => {
    const oneDayAgo = now - 86400;
    const sevenDaysAgo = now - 7 * 86400;

    const scoreNew = computePriorityScore(oneDayAgo, 0);
    const scoreOld = computePriorityScore(sevenDaysAgo, 0);

    expect(scoreOld).toBeGreaterThan(scoreNew);
  });

  it('should decrease score for frequently reviewed nuggets', () => {
    const createdAt = now - 7 * 86400; // 7 days ago

    const scoreNeverReviewed = computePriorityScore(createdAt, 0);
    const scoreReviewedOnce = computePriorityScore(createdAt, 1);
    const scoreReviewedFiveTimes = computePriorityScore(createdAt, 5);

    expect(scoreNeverReviewed).toBeGreaterThan(scoreReviewedOnce);
    expect(scoreReviewedOnce).toBeGreaterThan(scoreReviewedFiveTimes);
  });

  it('should handle nuggets created just now', () => {
    const createdAt = now;
    const score = computePriorityScore(createdAt, 0);
    expect(score).toBeGreaterThan(0);
    expect(score).toBeLessThan(1); // Should be small for very new items
  });

  it('should apply review penalty correctly', () => {
    const createdAt = now - 86400; // 1 day ago
    const baseScore = computePriorityScore(createdAt, 0);
    const scoreTwoReviews = computePriorityScore(createdAt, 2);

    // With 2 reviews, penalty is 1 + 0.5 * 2 = 2, so score should be halved
    expect(scoreTwoReviews).toBeCloseTo(baseScore / 2, 5);
  });
});

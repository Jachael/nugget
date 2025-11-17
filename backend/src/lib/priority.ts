/**
 * Compute a priority score for a nugget based on its age and review history.
 * Higher scores indicate higher priority for inclusion in sessions.
 *
 * @param createdAt Unix timestamp (seconds) when the nugget was created
 * @param timesReviewed Number of times the nugget has been reviewed
 * @returns Priority score (higher = more priority)
 */
export function computePriorityScore(createdAt: number, timesReviewed: number): number {
  const now = Date.now() / 1000;
  const ageDays = Math.max((now - createdAt) / 86400, 1);
  const reviewPenalty = 1 + 0.5 * timesReviewed;
  return Math.log(ageDays + 1) / reviewPenalty;
}

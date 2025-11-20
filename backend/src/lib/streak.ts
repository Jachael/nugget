/**
 * Calculate user streak based on daily activity (nugget creation)
 * A streak is maintained if the user created at least one nugget each day
 */

export function formatDateKey(timestamp: number): string {
  const date = new Date(timestamp);
  return date.toISOString().split('T')[0]; // Returns YYYY-MM-DD
}

export function calculateStreak(nuggetTimestamps: number[]): { streak: number; lastActiveDate: string } {
  if (nuggetTimestamps.length === 0) {
    const today = formatDateKey(Date.now());
    return { streak: 0, lastActiveDate: today };
  }

  // Get unique dates from nugget creation timestamps
  const uniqueDates = new Set(nuggetTimestamps.map(ts => formatDateKey(ts)));
  const sortedDates = Array.from(uniqueDates).sort().reverse(); // Most recent first

  const today = formatDateKey(Date.now());
  const lastActiveDate = sortedDates[0];

  // If last activity wasn't today or yesterday, streak is broken
  const lastActivityDate = new Date(lastActiveDate);
  const todayDate = new Date(today);
  const diffTime = todayDate.getTime() - lastActivityDate.getTime();
  const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

  if (diffDays > 1) {
    // Streak is broken - last activity was more than yesterday
    return { streak: 0, lastActiveDate };
  }

  // Count consecutive days backwards from the most recent activity
  let streak = 1; // Start with 1 for the most recent day
  let currentDate = new Date(lastActiveDate);

  for (let i = 1; i < sortedDates.length; i++) {
    const prevDate = new Date(sortedDates[i]);
    const daysDiff = Math.floor((currentDate.getTime() - prevDate.getTime()) / (1000 * 60 * 60 * 24));

    if (daysDiff === 1) {
      // Consecutive day found
      streak++;
      currentDate = prevDate;
    } else {
      // Gap found, streak ends
      break;
    }
  }

  return { streak, lastActiveDate };
}

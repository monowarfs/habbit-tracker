/// Ranking metric for the household leaderboard (`docs/superpowers/specs/
/// 06-gamification/12-household-leaderboard-IMPLEMENTATION-PLAN.md`).
enum LeaderboardMetric {
  /// Longest current streak across every module the profile uses.
  currentStreak,

  /// % of the last 7 days where every module the profile actively uses
  /// was complete that day.
  weeklyCompletion,

  /// Cross-module XP level (`core/gamification/level_curve.dart`).
  level,
}

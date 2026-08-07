import 'package:habit_tracker/core/gamification/leaderboard/leaderboard_metric.dart';
import 'package:habit_tracker/core/gamification/level_curve.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// A computed leaderboard score, plus the module ids it was actually
/// computed from — used to detect zero comparable overlap between two
/// profiles (`06-household-leaderboard-design.md`'s "different modules
/// per profile" edge case). Empty for [LeaderboardMetric.level], which
/// is always comparable (XP is cross-module by construction).
typedef ScoreResult = ({num value, Set<String> activeModuleIds});

/// Computes a profile's leaderboard score for a given [LeaderboardMetric],
/// reusing each module's existing [HabitModule.dayStatus] plus the pure
/// `core/reports` streak helpers — no new tracking, only cross-profile
/// reads (per both merged specs' "no new domain logic" framing).
class ScoreComputer {
  /// Creates a computer over [modules] (typically
  /// `visibleHabitModulesProvider`'s list) and [xpRepository].
  const ScoreComputer({required this.modules, required this.xpRepository});

  /// Every module to consider — the leaderboard is cross-module.
  final List<HabitModule> modules;

  /// Source of truth for [LeaderboardMetric.level].
  final XpRepository xpRepository;

  /// Computes [profileId]'s score for [metric] as of [today].
  Future<ScoreResult> computeScore({
    required String profileId,
    required LeaderboardMetric metric,
    required LocalDate today,
  }) {
    switch (metric) {
      case LeaderboardMetric.currentStreak:
        return _currentStreakScore(profileId, today);
      case LeaderboardMetric.weeklyCompletion:
        return _weeklyCompletionScore(profileId, today);
      case LeaderboardMetric.level:
        return _levelScore(profileId);
    }
  }

  /// Longest current streak (`core/reports`' [currentStreak]) across
  /// every module the profile has any data in, looking back 90 days.
  Future<ScoreResult> _currentStreakScore(
    String profileId,
    LocalDate today,
  ) async {
    final range = DateRange(start: today.addDays(-90), end: today);
    var best = 0;
    final activeModuleIds = <String>{};
    for (final module in modules) {
      final status = await module.dayStatus(range, profileId: profileId);
      if (_hasAnyData(status)) activeModuleIds.add(module.id);
      final streak = currentStreak(status, today);
      if (streak > best) best = streak;
    }
    return (value: best, activeModuleIds: activeModuleIds);
  }

  /// % of the last 7 days where every module the profile actively uses
  /// (has any non-`none` day status in that window) was `complete` or
  /// `paused` that day. A profile with no active module in the window
  /// scores 0 with an empty `activeModuleIds`.
  Future<ScoreResult> _weeklyCompletionScore(
    String profileId,
    LocalDate today,
  ) async {
    final range = DateRange(start: today.addDays(-6), end: today);
    final activeModuleIds = <String>{};
    final activeStatuses = <Map<LocalDate, ModuleDayStatus>>[];
    for (final module in modules) {
      final status = await module.dayStatus(range, profileId: profileId);
      if (_hasAnyData(status)) {
        activeModuleIds.add(module.id);
        activeStatuses.add(status);
      }
    }
    if (activeStatuses.isEmpty) {
      return (value: 0, activeModuleIds: activeModuleIds);
    }
    var completeDays = 0;
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      final dayComplete = activeStatuses.every((status) {
        final kind = status[day]?.kind;
        return kind == ModuleDayStatusKind.complete ||
            kind == ModuleDayStatusKind.paused;
      });
      if (dayComplete) completeDays++;
      day = day.addDays(1);
    }
    return (value: completeDays / 7 * 100, activeModuleIds: activeModuleIds);
  }

  Future<ScoreResult> _levelScore(String profileId) async {
    final totalXp = await xpRepository.totalXp(profileId: profileId);
    return (value: LevelCurve.levelForXp(totalXp), activeModuleIds: <String>{});
  }

  bool _hasAnyData(Map<LocalDate, ModuleDayStatus> status) =>
      status.values.any((s) => s.kind != ModuleDayStatusKind.none);
}

import 'package:clock/clock.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';

/// Milestone definitions for tenure-based achievements.
const tenureMilestones = [
  TenureMilestone(key: 'tenure_1_year', days: 365),
  TenureMilestone(key: 'tenure_2_year', days: 730),
];

/// A tenure milestone definition.
class TenureMilestone {
  /// Creates a milestone.
  const TenureMilestone({required this.key, required this.days});

  /// The achievement key (e.g. `'tenure_1_year'`).
  final String key;

  /// The number of days required.
  final int days;
}

/// Evaluates tenure milestones against [installDate].
/// Awards any un-awarded milestones where
/// (now - installDate) >= milestone.days.
/// Cross-module: moduleId = 'core'.
Future<void> evaluateTenureMilestones({
  required DateTime installDate,
  required AchievementRepository repository,
  DateTime? now,
}) async {
  final effectiveNow = now ?? clock.now();
  final daysSinceInstall = effectiveNow.difference(installDate).inDays;

  for (final milestone in tenureMilestones) {
    if (daysSinceInstall < milestone.days) continue;

    // Check if already evaluated (even if not unlocked).
    final existing = await repository.byKey(milestone.key);
    if (existing != null) continue;

    // Award the badge immediately (current == target).
    await repository.upsertProgress(
      moduleId: 'core',
      key: milestone.key,
      current: milestone.days,
      target: milestone.days,
      now: effectiveNow,
    );
  }
}

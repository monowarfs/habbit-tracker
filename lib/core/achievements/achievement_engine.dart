import 'package:clock/clock.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

/// Evaluates one module's [HabitModule.achievementDefinitions] against
/// live data and persists progress/unlock state (D-16). Called by each
/// module's own controller right after a write commits — never on a
/// timer, never scanning every module at once.
class AchievementEngine {
  /// Creates an engine over [modules], persisting through [repository].
  const AchievementEngine({required this.repository, required this.modules});

  /// Where progress/unlock state is stored.
  final AchievementRepository repository;

  /// Every registered module — [evaluate] looks up the one matching its
  /// `moduleId` argument and reads its `achievementDefinitions`.
  final List<HabitModule> modules;

  /// Re-evaluates every achievement [moduleId] contributes.
  Future<void> evaluate(String moduleId) async {
    final module = modules.firstWhere((m) => m.id == moduleId);
    final now = clock.now();
    for (final definition in module.achievementDefinitions) {
      final progress = await definition.currentProgress();
      await repository.upsertProgress(
        moduleId: moduleId,
        key: definition.key,
        current: progress.clamp(0, definition.target),
        target: definition.target,
        now: now,
      );
    }
  }
}

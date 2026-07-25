import 'dart:async';

import 'package:clock/clock.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

/// An event emitted when an achievement is unlocked.
class AchievementEvent {
  /// Creates an achievement event.
  const AchievementEvent({
    required this.moduleId,
    required this.key,
    required this.justUnlocked,
  });

  /// The module that owns this achievement.
  final String moduleId;

  /// The achievement key.
  final String key;

  /// Whether this was a fresh unlock (not just a progress update).
  final bool justUnlocked;
}

/// Evaluates one module's [HabitModule.achievementDefinitions] against
/// live data and persists progress/unlock state (D-16). Called by each
/// module's own controller right after a write commits — never on a
/// timer, never scanning every module at once.
class AchievementEngine {
  /// Creates an engine over [modules], persisting through [repository].
  AchievementEngine({required this.repository, required this.modules});

  /// Where progress/unlock state is stored.
  final AchievementRepository repository;

  /// Every registered module — [evaluate] looks up the one matching its
  /// `moduleId` argument and reads its `achievementDefinitions`.
  final List<HabitModule> modules;

  /// Stream of achievement events (unlocks).
  final _eventController = StreamController<AchievementEvent>.broadcast();

  /// Stream of achievement events.
  Stream<AchievementEvent> get events => _eventController.stream;

  /// Re-evaluates every achievement [moduleId] contributes.
  Future<void> evaluate(String moduleId) async {
    final module = modules.firstWhere((m) => m.id == moduleId);
    final now = clock.now();
    for (final definition in module.achievementDefinitions) {
      final progress = await definition.currentProgress();
      final existing = await repository.byKey(definition.key);
      final wasAlreadyUnlocked = existing?.unlockedAt != null;
      await repository.upsertProgress(
        moduleId: moduleId,
        key: definition.key,
        current: progress.clamp(0, definition.target),
        target: definition.target,
        now: now,
      );
      final justUnlocked = !wasAlreadyUnlocked && progress >= definition.target;
      if (justUnlocked) {
        _eventController.add(
          AchievementEvent(
            moduleId: moduleId,
            key: definition.key,
            justUnlocked: true,
          ),
        );
      }
    }
  }

  /// Disposes the event controller.
  void dispose() {
    _eventController.close();
  }
}

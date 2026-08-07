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
    required this.profileId,
  });

  /// The module that owns this achievement.
  final String moduleId;

  /// The achievement key.
  final String key;

  /// Whether this was a fresh unlock (not just a progress update).
  final bool justUnlocked;

  /// The profile this evaluation ran for (family/multi-profile) — consumers
  /// like `XpAwardListener` use this rather than re-resolving the active
  /// profile themselves, since it can race a profile switch otherwise.
  final String profileId;
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

  /// Re-evaluates every achievement [moduleId] contributes, for [profileId].
  Future<void> evaluate(String moduleId, {required String profileId}) async {
    final module = modules.firstWhere((m) => m.id == moduleId);
    final now = clock.now();
    for (final definition in module.achievementDefinitions) {
      final progress = await definition.currentProgress();
      final existing = await repository.byKey(
        definition.key,
        profileId: profileId,
      );
      final wasAlreadyUnlocked = existing?.unlockedAt != null;
      await repository.upsertProgress(
        moduleId: moduleId,
        key: definition.key,
        current: progress.clamp(0, definition.target),
        target: definition.target,
        now: now,
        profileId: profileId,
      );
      final justUnlocked = !wasAlreadyUnlocked && progress >= definition.target;
      if (justUnlocked) {
        _eventController.add(
          AchievementEvent(
            moduleId: moduleId,
            key: definition.key,
            justUnlocked: true,
            profileId: profileId,
          ),
        );
      }
    }
  }

  /// Disposes the event controller.
  void dispose() {
    unawaited(_eventController.close());
  }
}

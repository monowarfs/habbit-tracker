import 'package:clock/clock.dart';
import 'package:habit_tracker/core/recalibration/recalibration_repository.dart';
import 'package:habit_tracker/core/recalibration/recalibration_trigger.dart';

/// Orchestration for recalibration prompts.
class RecalibrationService {
  /// Creates a service.
  const RecalibrationService({
    required this.repository,
    required this.sessionTracker,
  });

  /// Repository for marker CRUD.
  final RecalibrationRepository repository;

  /// Session-level prompt cap tracker.
  final RecalibrationSessionTracker sessionTracker;

  /// Checks if a recalibration prompt is due for [moduleId].
  Future<bool> isDue(String moduleId, {required bool enabled}) async {
    if (!sessionTracker.canShowMore) return false;

    final marker = await repository.forModule(moduleId);
    final action = checkRecalibration(
      lastGoalEditedAt: DateTime.fromMillisecondsSinceEpoch(
        marker.lastGoalEditedAt,
        isUtc: true,
      ),
      lastShownAt: DateTime.fromMillisecondsSinceEpoch(
        marker.lastShownAt,
        isUtc: true,
      ),
      consecutiveDismissals: marker.consecutiveDismissals,
      now: clock.now(),
      recalibrationEnabled: enabled,
    );
    return action == RecalibrationAction.showPrompt;
  }

  /// Marks the prompt as shown.
  Future<void> onPromptShown(String moduleId) async {
    await repository.markShown(moduleId);
    sessionTracker.recordShown();
  }

  /// Handles "Still right" dismissal.
  Future<void> onConfirmed(String moduleId) async {
    await repository.markConfirmed(moduleId);
  }

  /// Handles "Remind later" dismissal.
  Future<void> onDeferred(String moduleId) async {
    await repository.markDeferred(moduleId);
  }

  /// Records a goal edit (resets timer).
  Future<void> onGoalEdited(String moduleId) async {
    await repository.markGoalEdited(moduleId);
  }
}

/// Tracks how many recalibration prompts have been shown this app session.
/// Resets on app restart.
class RecalibrationSessionTracker {
  int _shownCount = 0;

  /// Whether more prompts can be shown this session.
  bool get canShowMore => _shownCount < maxPromptsPerSession;

  /// Records that a prompt was shown.
  void recordShown() => _shownCount++;
}

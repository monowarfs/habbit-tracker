/// The action to take when checking the recalibration trigger.
enum RecalibrationAction {
  /// No recalibration due.
  none,

  /// Show the recalibration prompt.
  showPrompt,
}

/// Maximum prompts per app session (cap at 2 per spec).
const maxPromptsPerSession = 2;

/// Pure logic: checks whether a recalibration prompt should be shown.
///
/// Fires when:
/// - Goal hasn't been edited in 90+ days
/// - Prompt hasn't been shown in 30+ days (with fatigue backoff)
RecalibrationAction checkRecalibration({
  required DateTime lastGoalEditedAt,
  required DateTime lastShownAt,
  required int consecutiveDismissals,
  required DateTime now,
  required bool recalibrationEnabled,
}) {
  if (!recalibrationEnabled) {
    return RecalibrationAction.none;
  }

  final daysSinceEdit = now.difference(lastGoalEditedAt).inDays;
  if (daysSinceEdit < 90) {
    return RecalibrationAction.none;
  }

  final daysSinceShown = now.difference(lastShownAt).inDays;

  // Fatigue backoff: extend interval based on consecutive dismissals.
  var minDaysSinceShown = 30;
  if (consecutiveDismissals >= 5) {
    minDaysSinceShown = 90;
  } else if (consecutiveDismissals >= 3) {
    minDaysSinceShown = 60;
  }

  if (daysSinceShown < minDaysSinceShown) {
    return RecalibrationAction.none;
  }

  return RecalibrationAction.showPrompt;
}

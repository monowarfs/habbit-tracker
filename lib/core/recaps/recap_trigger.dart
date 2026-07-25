/// The action to take when checking the yearly recap trigger.
enum RecapTriggerAction {
  /// No recap due.
  none,

  /// Show the yearly recap full-screen.
  showRecap,

  /// Show a "not enough data" fallback.
  notEnoughData,
}

/// Result of checking the yearly recap trigger.
class YearRecapTriggerResult {
  /// Creates a trigger result.
  const YearRecapTriggerResult({
    required this.action,
    this.yearNumber,
  });

  /// The action to take.
  final RecapTriggerAction action;

  /// The year number to generate a recap for, if [action] is
  /// [RecapTriggerAction.showRecap].
  final int? yearNumber;
}

/// Pure logic: checks whether a yearly recap should be triggered.
///
/// Returns a [YearRecapTriggerResult] indicating whether to show the
/// recap, show a "not enough data" fallback, or do nothing.
YearRecapTriggerResult checkYearlyRecapTrigger({
  required DateTime? installDate,
  required int lastRecapYear,
  required DateTime now,
  required bool recapEnabled,
}) {
  if (!recapEnabled) {
    return const YearRecapTriggerResult(action: RecapTriggerAction.none);
  }

  if (installDate == null) {
    return const YearRecapTriggerResult(action: RecapTriggerAction.none);
  }

  final daysSinceInstall = now.difference(installDate).inDays;
  if (daysSinceInstall < 365) {
    return const YearRecapTriggerResult(action: RecapTriggerAction.none);
  }

  final currentYearNumber = (daysSinceInstall / 365).floor();
  if (currentYearNumber <= lastRecapYear) {
    return const YearRecapTriggerResult(action: RecapTriggerAction.none);
  }

  // A recap is due. The generator will determine if there's enough data.
  return YearRecapTriggerResult(
    action: RecapTriggerAction.showRecap,
    yearNumber: currentYearNumber,
  );
}

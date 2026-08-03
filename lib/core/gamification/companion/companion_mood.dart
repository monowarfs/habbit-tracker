import 'package:habit_tracker/core/modules/habit_module.dart';

/// The virtual companion's mood, derived from recent day-completion history.
enum CompanionMood {
  /// 5-7 of the last 7 days complete.
  thriving,

  /// 3-4 of the last 7 days complete.
  happy,

  /// 1-2 of the last 7 days complete, or fewer than 3 days of data exist.
  neutral,

  /// 0 of the last 7 days complete. Shown instead of a lower "sad" state
  /// for emotional safety — the companion always looks like it wants to
  /// help, even after a long gap.
  worried,
}

/// Derives the companion's mood from recent [ModuleDayStatus] entries
/// across all modules (last 7 days).
CompanionMood deriveCompanionMood(List<ModuleDayStatus> recentDays) {
  if (recentDays.length < 3) return CompanionMood.neutral;
  final completeCount = recentDays
      .where((d) => d.kind == ModuleDayStatusKind.complete)
      .length;
  return switch (completeCount) {
    >= 5 => CompanionMood.thriving,
    >= 3 => CompanionMood.happy,
    >= 1 => CompanionMood.neutral,
    _ => CompanionMood.worried,
  };
}

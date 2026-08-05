import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// Detects a "combo day" — every active module fully complete for the
/// same day. Pure read-time detection off `HabitModule.dayStatus()`, no
/// new tracking table: a day either qualifies or it doesn't, computed
/// fresh each time from data every module already persists.
class ComboDetector {
  /// Creates a detector.
  const ComboDetector();

  /// Whether every module in [modules] is complete for [date]. Always
  /// `false` for fewer than 2 modules — a single-module user has nothing
  /// to combo across (the plan's "single-module user handling" edge
  /// case).
  Future<bool> isComboDay({
    required LocalDate date,
    required List<HabitModule> modules,
  }) async {
    if (modules.length < 2) return false;
    final completed = await completedModuleCount(date: date, modules: modules);
    return completed == modules.length;
  }

  /// How many of [modules] are complete for [date].
  Future<int> completedModuleCount({
    required LocalDate date,
    required List<HabitModule> modules,
  }) async {
    var completed = 0;
    for (final module in modules) {
      final statuses = await module.dayStatus(
        DateRange(start: date, end: date),
      );
      if (statuses[date]?.kind == ModuleDayStatusKind.complete) completed++;
    }
    return completed;
  }
}

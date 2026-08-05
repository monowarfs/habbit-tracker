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

  /// How many of [modules] are complete for [date]. Queries all modules
  /// in parallel — matches `_DayCompletionIndicator`'s own
  /// `Future.wait`-based `dayStatus()` fan-out (PR #80 review finding).
  Future<int> completedModuleCount({
    required LocalDate date,
    required List<HabitModule> modules,
  }) async {
    final results = await Future.wait(
      modules.map(
        (module) => module.dayStatus(DateRange(start: date, end: date)),
      ),
    );
    return results
        .where(
          (statuses) => statuses[date]?.kind == ModuleDayStatusKind.complete,
        )
        .length;
  }
}

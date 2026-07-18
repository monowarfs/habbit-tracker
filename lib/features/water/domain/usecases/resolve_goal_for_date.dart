import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';

/// Resolves which goal applied on a given local day, per the append-only
/// goal-history rule (FR-W-04, D-01): "the row with the latest
/// `effectiveFrom` that is `<=` that day's local midnight."
class ResolveGoalForDateUseCase {
  /// Creates the use case.
  const ResolveGoalForDateUseCase();

  /// Resolves the applicable goal for [date] from [goals] (any order).
  ///
  /// If [date] is earlier than every goal's effective date (a day before
  /// the user ever set one), the earliest goal is returned — there is no
  /// "no goal" state once at least one goal exists.
  WaterGoal execute(List<WaterGoal> goals, LocalDate date) {
    assert(goals.isNotEmpty, 'at least one goal must exist');
    final sorted = [...goals]
      ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
    var applicable = sorted.first;
    for (final goal in sorted) {
      final effectiveDay = localDayKey(goal.effectiveFrom);
      if (effectiveDay.compareTo(date) <= 0) {
        applicable = goal;
      } else {
        break;
      }
    }
    return applicable;
  }
}

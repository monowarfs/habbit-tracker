import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// Result of goal attainment calculation.
class GoalAttainmentResult {
  /// Creates a goal attainment result.
  const GoalAttainmentResult({
    required this.metDays,
    required this.totalDays,
    required this.rate,
  });

  /// Days where goal was met.
  final int metDays;

  /// Total active days (excluding no-data days).
  final int totalDays;

  /// Goal attainment rate (0.0 to 1.0).
  final double rate;
}

/// Counts days where goal was met vs total active days.
class GoalAttainmentUseCase {
  /// Calculates goal attainment from day-status data.
  ///
  /// Days with `kind == none` (before the module was first used) or
  /// `kind == paused` are excluded from the denominator, matching
  /// `day_status_streaks.dart`'s streak calculators — paused days
  /// neither count nor break attainment.
  GoalAttainmentResult calculate({
    required Map<LocalDate, ModuleDayStatus> dayStatus,
  }) {
    final activeDays = dayStatus.values
        .where(
          (s) =>
              s.kind != ModuleDayStatusKind.none &&
              s.kind != ModuleDayStatusKind.paused,
        )
        .length;
    final metDays = dayStatus.values
        .where((s) => s.kind == ModuleDayStatusKind.complete)
        .length;

    return GoalAttainmentResult(
      metDays: metDays,
      totalDays: activeDays,
      rate: activeDays > 0 ? metDays / activeDays : 0,
    );
  }
}

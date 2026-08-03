import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/exercise/domain/entities/exercise_log.dart';

/// One ISO week's (Monday-start) total exercise minutes.
class WeeklyMinutesPoint {
  /// Creates a weekly-minutes point.
  const WeeklyMinutesPoint({
    required this.weekStart,
    required this.totalMinutes,
  });

  /// The Monday this week's bucket starts on.
  final LocalDate weekStart;

  /// Sum of `durationMinutes` across every workout logged that week.
  final int totalMinutes;
}

/// Buckets workouts into weekly total-minutes points for the stats
/// chart, oldest first. A week with no logged workouts still gets a
/// point (0 minutes) — the chart should show the gap, not skip it.
class AggregateWeeklyMinutesUseCase {
  /// Creates the aggregator (stateless — a pure function wrapper).
  const AggregateWeeklyMinutesUseCase();

  /// Buckets [logs] between [start] and [end] (inclusive) into weekly
  /// points.
  List<WeeklyMinutesPoint> execute({
    required List<ExerciseLog> logs,
    required LocalDate start,
    required LocalDate end,
  }) {
    final totalsByWeekStart = <LocalDate, int>{};
    final weekOrder = <LocalDate>[];

    var day = _weekStartFor(start);
    final lastWeekStart = _weekStartFor(end);
    while (day.compareTo(lastWeekStart) <= 0) {
      totalsByWeekStart[day] = 0;
      weekOrder.add(day);
      day = day.addDays(7);
    }

    for (final log in logs) {
      final weekStart = _weekStartFor(localDayKey(log.loggedAt));
      if (!totalsByWeekStart.containsKey(weekStart)) continue;
      totalsByWeekStart[weekStart] =
          totalsByWeekStart[weekStart]! + log.durationMinutes;
    }

    return [
      for (final weekStart in weekOrder)
        WeeklyMinutesPoint(
          weekStart: weekStart,
          totalMinutes: totalsByWeekStart[weekStart]!,
        ),
    ];
  }

  LocalDate _weekStartFor(LocalDate day) {
    final weekday = day.toDateTimeUtc().weekday; // 1=Mon..7=Sun
    return day.addDays(-(weekday - 1));
  }
}

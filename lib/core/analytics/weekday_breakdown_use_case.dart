import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// Statistics for a single weekday.
class WeekdayStats {
  /// Creates weekday stats.
  const WeekdayStats({
    required this.weekday,
    required this.completionRate,
    required this.totalDays,
    required this.completedDays,
  });

  /// The weekday (0=Monday, 6=Sunday).
  final int weekday;

  /// Completion rate (0.0 to 1.0).
  final double completionRate;

  /// Total days with data for this weekday.
  final int totalDays;

  /// Days completed for this weekday.
  final int completedDays;
}

/// Aggregates day-status data by weekday and calculates completion rates.
class WeekdayBreakdownUseCase {
  /// Computes per-weekday completion rates from day-status data.
  List<WeekdayStats> compute({
    required Map<LocalDate, ModuleDayStatus> dayStatus,
  }) {
    final buckets = List.generate(7, (_) => _Bucket());

    for (final entry in dayStatus.entries) {
      final weekday = entry.key.toDateTimeUtc().weekday - 1; // 0=Mon
      buckets[weekday].total++;
      if (entry.value.kind == ModuleDayStatusKind.complete) {
        buckets[weekday].completed++;
      }
    }

    return List.generate(7, (i) {
      final bucket = buckets[i];
      return WeekdayStats(
        weekday: i,
        completionRate:
            bucket.total > 0 ? bucket.completed / bucket.total : 0,
        totalDays: bucket.total,
        completedDays: bucket.completed,
      );
    });
  }
}

class _Bucket {
  int total = 0;
  int completed = 0;
}

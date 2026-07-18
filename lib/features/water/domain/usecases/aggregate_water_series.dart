import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

part 'aggregate_water_series.freezed.dart';

/// The bucket width for [AggregateWaterSeriesUseCase].
enum WaterAggregationPeriod {
  /// One bucket per calendar day.
  daily,

  /// One bucket per ISO week (Monday-start).
  weekly,

  /// One bucket per calendar month.
  monthly,
}

/// One bucket's total in an aggregated series.
@freezed
sealed class WaterSeriesPoint with _$WaterSeriesPoint {
  /// Creates a series point.
  const factory WaterSeriesPoint({
    required LocalDate bucketStart,
    required int totalMl,
  }) = _WaterSeriesPoint;
}

/// Buckets a day-by-day totals map into daily/weekly/monthly series for
/// the stats charts (FR-W-08).
class AggregateWaterSeriesUseCase {
  /// Buckets [dailyTotalsMl] (day -> total) between [start] and [end]
  /// (inclusive) into [period]-wide points, sorted oldest first. A day
  /// absent from [dailyTotalsMl] contributes 0.
  List<WaterSeriesPoint> execute({
    required Map<LocalDate, int> dailyTotalsMl,
    required LocalDate start,
    required LocalDate end,
    required WaterAggregationPeriod period,
  }) {
    final buckets = <LocalDate, int>{};
    final bucketOrder = <LocalDate>[];

    var day = start;
    while (day.compareTo(end) <= 0) {
      final bucketStart = _bucketStartFor(day, period);
      if (!buckets.containsKey(bucketStart)) {
        buckets[bucketStart] = 0;
        bucketOrder.add(bucketStart);
      }
      buckets[bucketStart] = buckets[bucketStart]! + (dailyTotalsMl[day] ?? 0);
      day = day.addDays(1);
    }

    return [
      for (final bucketStart in bucketOrder)
        WaterSeriesPoint(
          bucketStart: bucketStart,
          totalMl: buckets[bucketStart]!,
        ),
    ];
  }

  LocalDate _bucketStartFor(LocalDate day, WaterAggregationPeriod period) {
    switch (period) {
      case WaterAggregationPeriod.daily:
        return day;
      case WaterAggregationPeriod.weekly:
        final weekday = day.toDateTimeUtc().weekday; // 1=Mon..7=Sun
        return day.addDays(-(weekday - 1));
      case WaterAggregationPeriod.monthly:
        return LocalDate(day.year, day.month, 1);
    }
  }
}

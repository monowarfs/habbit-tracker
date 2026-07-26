import 'package:flutter/material.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';

/// The Reports screen's period granularity (FR-C-12). [custom] and
/// [allTime] are premium-gated (`docs/superpowers/specs/04-premium/
/// 08-extended-stats-range-multi-year-trends-design.md`) — the free
/// [week]/[month]/[year] views are unrestricted for every user.
enum ReportPeriod {
  /// One bar per day, 7 days.
  week,

  /// One bar per day, the whole calendar month.
  month,

  /// One bar per calendar month, 12 months.
  year,

  /// A user-picked date range, any span.
  custom,

  /// From the user's install date to today.
  allTime,
}

/// One module's contribution to a Reports period — its chart series plus
/// its longest-streak record (FR-C-14).
typedef ModuleReport = ({
  String moduleId,
  String displayName,
  Color accentColor,
  List<BarChartPoint> points,
  int longestStreak,
});

/// Builds each enabled module's [ModuleReport] for a requested period,
/// anchored at any day within that period. A module with no
/// data anywhere in the period is omitted — the caller renders that as
/// an empty state, not a zero-filled chart (FR-C-12).
class AggregateReportUseCase {
  /// Creates the use case.
  const AggregateReportUseCase();

  /// Computes every [modules] entry's report for [period]. [customRange]
  /// is required for [ReportPeriod.custom]/[ReportPeriod.allTime] (the
  /// caller resolves what that range actually is — a picked range, or
  /// install-date-to-today) and ignored otherwise.
  Future<List<ModuleReport>> execute({
    required List<HabitModule> modules,
    required ReportPeriod period,
    required LocalDate periodAnchor,
    DateRange? customRange,
  }) async {
    final range = _resolveRange(period, periodAnchor, customRange);
    final reports = <ModuleReport>[];
    for (final module in modules) {
      final dayStatus = await module.dayStatus(range);
      final hasData = dayStatus.values.any(
        (s) => s.kind != ModuleDayStatusKind.none,
      );
      if (!hasData) continue;
      reports.add((
        moduleId: module.id,
        displayName: module.metadata.displayName,
        accentColor: module.metadata.accentColor,
        points: _bucketPoints(dayStatus, period, range),
        longestStreak: longestStreak(dayStatus),
      ));
    }
    return reports;
  }

  DateRange _resolveRange(
    ReportPeriod period,
    LocalDate anchor,
    DateRange? customRange,
  ) {
    switch (period) {
      case ReportPeriod.week:
        final weekday = anchor.toDateTimeUtc().weekday;
        final start = anchor.addDays(-(weekday - 1));
        return DateRange(start: start, end: start.addDays(6));
      case ReportPeriod.month:
        final start = LocalDate(anchor.year, anchor.month, 1);
        final end = LocalDate(anchor.year, anchor.month + 1, 1).addDays(-1);
        return DateRange(start: start, end: end);
      case ReportPeriod.year:
        return DateRange(
          start: LocalDate(anchor.year, 1, 1),
          end: LocalDate(anchor.year, 12, 31),
        );
      case ReportPeriod.custom:
      case ReportPeriod.allTime:
        if (customRange == null) {
          throw ArgumentError(
            'customRange is required for ReportPeriod.$period',
          );
        }
        return customRange;
    }
  }

  static const _monthLabels = [
    'J',
    'F',
    'M',
    'A',
    'M',
    'J',
    'J',
    'A',
    'S',
    'O',
    'N',
    'D',
  ];

  List<BarChartPoint> _bucketPoints(
    Map<LocalDate, ModuleDayStatus> dayStatus,
    ReportPeriod period,
    DateRange range,
  ) {
    switch (period) {
      case ReportPeriod.week:
      case ReportPeriod.month:
        final points = <BarChartPoint>[];
        var day = range.start;
        while (day.compareTo(range.end) <= 0) {
          final value = dayStatus[day]?.value ?? 0;
          points.add(
            BarChartPoint(label: '${day.day}', value: value.toDouble()),
          );
          day = day.addDays(1);
        }
        return points;
      case ReportPeriod.year:
        final totalsByMonth = List<double>.filled(12, 0);
        dayStatus.forEach((day, status) {
          totalsByMonth[day.month - 1] += status.value.toDouble();
        });
        return [
          for (var i = 0; i < 12; i++)
            BarChartPoint(label: _monthLabels[i], value: totalsByMonth[i]),
        ];
      case ReportPeriod.custom:
      case ReportPeriod.allTime:
        return _bucketBySpan(dayStatus, range);
    }
  }

  /// Multi-year ranges bucketed daily would be an unreadable/expensive
  /// chart (a 5-year range is ~1,825 daily bars) — pick a granularity
  /// from the range's actual span instead, per the design doc's
  /// "Performance considerations" section: monthly up to a year,
  /// quarterly up to 5 years, yearly beyond that.
  List<BarChartPoint> _bucketBySpan(
    Map<LocalDate, ModuleDayStatus> dayStatus,
    DateRange range,
  ) {
    final spanDays =
        range.end
            .toDateTimeUtc()
            .difference(range.start.toDateTimeUtc())
            .inDays +
        1;
    if (spanDays <= 366) return _bucketByMonth(dayStatus, range);
    if (spanDays <= 366 * 5) return _bucketByQuarter(dayStatus, range);
    return _bucketByYear(dayStatus, range);
  }

  List<BarChartPoint> _bucketByMonth(
    Map<LocalDate, ModuleDayStatus> dayStatus,
    DateRange range,
  ) {
    final totals = <String, double>{};
    dayStatus.forEach((day, status) {
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}';
      totals[key] = (totals[key] ?? 0) + status.value.toDouble();
    });
    final points = <BarChartPoint>[];
    var month = LocalDate(range.start.year, range.start.month, 1);
    while (month.compareTo(range.end) <= 0) {
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      points.add(
        BarChartPoint(
          label: _monthLabels[month.month - 1],
          value: totals[key] ?? 0,
        ),
      );
      month = month.addMonths(1);
    }
    return points;
  }

  List<BarChartPoint> _bucketByQuarter(
    Map<LocalDate, ModuleDayStatus> dayStatus,
    DateRange range,
  ) {
    final totals = <String, double>{};
    dayStatus.forEach((day, status) {
      final quarter = ((day.month - 1) ~/ 3) + 1;
      final key = '${day.year}-Q$quarter';
      totals[key] = (totals[key] ?? 0) + status.value.toDouble();
    });
    final points = <BarChartPoint>[];
    var year = range.start.year;
    var quarter = ((range.start.month - 1) ~/ 3) + 1;
    final endYear = range.end.year;
    final endQuarter = ((range.end.month - 1) ~/ 3) + 1;
    while (year < endYear || (year == endYear && quarter <= endQuarter)) {
      final key = '$year-Q$quarter';
      points.add(
        BarChartPoint(
          label: "Q$quarter'${year % 100}",
          value: totals[key] ?? 0,
        ),
      );
      quarter += 1;
      if (quarter > 4) {
        quarter = 1;
        year += 1;
      }
    }
    return points;
  }

  List<BarChartPoint> _bucketByYear(
    Map<LocalDate, ModuleDayStatus> dayStatus,
    DateRange range,
  ) {
    final totals = <int, double>{};
    dayStatus.forEach((day, status) {
      totals[day.year] = (totals[day.year] ?? 0) + status.value.toDouble();
    });
    return [
      for (var year = range.start.year; year <= range.end.year; year++)
        BarChartPoint(label: '$year', value: totals[year] ?? 0),
    ];
  }
}

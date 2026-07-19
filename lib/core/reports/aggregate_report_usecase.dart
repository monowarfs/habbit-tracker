import 'package:flutter/material.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';

/// The Reports screen's period granularity (FR-C-12).
enum ReportPeriod {
  /// One bar per day, 7 days.
  week,

  /// One bar per day, the whole calendar month.
  month,

  /// One bar per calendar month, 12 months.
  year,
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

  /// Computes every [modules] entry's report for [period].
  Future<List<ModuleReport>> execute({
    required List<HabitModule> modules,
    required ReportPeriod period,
    required LocalDate periodAnchor,
  }) async {
    final range = _rangeForPeriod(period, periodAnchor);
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

  DateRange _rangeForPeriod(ReportPeriod period, LocalDate anchor) {
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
    if (period != ReportPeriod.year) {
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
    }
    final totalsByMonth = List<double>.filled(12, 0);
    dayStatus.forEach((day, status) {
      totalsByMonth[day.month - 1] += status.value.toDouble();
    });
    return [
      for (var i = 0; i < 12; i++)
        BarChartPoint(label: _monthLabels[i], value: totalsByMonth[i]),
    ];
  }
}

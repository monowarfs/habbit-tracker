import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:meta/meta.dart';

/// One module's current-period series paired against the same period one
/// year prior, for the "vs. Last Year" comparison chart
/// (`docs/superpowers/specs/08-analytics/
/// 06-comparison-to-past-self-design.md`). [currentPoints] and
/// [lastYearPoints] are always the same length and index-aligned — a
/// calendar-length mismatch between the two years (e.g. February having
/// 28 days one year and 29 the other) is clipped down to the shorter of
/// the two rather than shown misaligned.
@immutable
class YearComparison {
  /// Creates a year comparison result.
  const YearComparison({
    required this.currentPoints,
    required this.lastYearPoints,
    required this.currentRange,
    required this.lastYearRange,
  });

  /// This period's series.
  final List<BarChartPoint> currentPoints;

  /// The same period one year prior's series.
  final List<BarChartPoint> lastYearPoints;

  /// The date range [currentPoints] was computed over.
  final DateRange currentRange;

  /// The date range [lastYearPoints] was computed over.
  final DateRange lastYearRange;
}

/// Fetches a module's current-period `dayStatus` alongside the same
/// period one year prior, for the "vs. Last Year" comparison screen.
/// Reuses [AggregateReportUseCase]'s own range resolution and bucketing
/// rather than re-deriving either — the only new logic here is anchoring
/// the second fetch a year back and clipping both series to a common
/// length.
class YearComparisonUseCase {
  /// Creates the use case.
  const YearComparisonUseCase();

  static const _reportUseCase = AggregateReportUseCase();

  /// Fetches [module]'s [period] centered on [periodAnchor], and the same
  /// period one year prior. Only [ReportPeriod.week]/[month]/[year] have
  /// a natural "same period last year" — this isn't a general
  /// compare-any-two-periods tool (design doc's non-goals).
  Future<YearComparison> fetch({
    required HabitModule module,
    required LocalDate periodAnchor,
    required ReportPeriod period,
  }) async {
    final currentRange = _reportUseCase.rangeForPeriod(period, periodAnchor);
    final lastYearAnchor = LocalDate(
      periodAnchor.year - 1,
      periodAnchor.month,
      periodAnchor.day,
    );
    final lastYearRange = _reportUseCase.rangeForPeriod(
      period,
      lastYearAnchor,
    );

    final current = await module.dayStatus(currentRange);
    final lastYear = await module.dayStatus(lastYearRange);

    final currentPoints = _reportUseCase.bucketPoints(
      current,
      period,
      currentRange,
    );
    final lastYearPoints = _reportUseCase.bucketPoints(
      lastYear,
      period,
      lastYearRange,
    );

    // Leap-year / month-length mismatch (design doc's "Edge cases" —
    // e.g. this February has 29 days but last February had 28): clip
    // both series down to the shorter length so every remaining index
    // still lines up the same relative day/month between the two years,
    // rather than the longer series trailing off against nothing.
    final length = currentPoints.length < lastYearPoints.length
        ? currentPoints.length
        : lastYearPoints.length;

    return YearComparison(
      currentPoints: currentPoints.sublist(0, length),
      lastYearPoints: lastYearPoints.sublist(0, length),
      currentRange: currentRange,
      lastYearRange: lastYearRange,
    );
  }

  /// Whether [installDate] is at least a full year before [now] — the
  /// design doc's hard prerequisite for the comparison to mean anything
  /// ("at least one full year of local usage history"). `null` (no
  /// recorded install date) is never eligible.
  static bool isEligible({
    required DateTime? installDate,
    required DateTime now,
  }) {
    if (installDate == null) return false;
    return now.difference(installDate).inDays >= 365;
  }
}

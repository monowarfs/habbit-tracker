import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// One bar in a [PeriodBarChart].
class BarChartPoint {
  /// Creates a bar chart point.
  const BarChartPoint({required this.label, required this.value});

  /// The x-axis label (e.g. a weekday initial, a day-of-month number).
  final String label;

  /// The bar's height.
  final double value;
}

/// A reusable bar chart for period-based stats (weekly/monthly/yearly
/// totals) — built once for Water's stats screen, reused by later
/// modules' own stats screens rather than each hand-rolling `fl_chart`
/// wiring.
class PeriodBarChart extends StatelessWidget {
  /// Creates a bar chart over [points], in [color], with an optional
  /// horizontal [targetLine] (e.g. a daily goal).
  const PeriodBarChart({
    required this.points,
    required this.color,
    this.targetLine,
    this.height = 200,
    super.key,
  });

  /// The bars to render, in x-axis order.
  final List<BarChartPoint> points;

  /// The bar (and target-line) color.
  final Color color;

  /// An optional horizontal reference line (e.g. the goal).
  final double? targetLine;

  /// The chart's height.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(height: height);
    }
    final maxValue = points
        .map((p) => p.value)
        .fold<double>(targetLine ?? 0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxValue == 0 ? 1 : maxValue * 1.2,
          barTouchData: const BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      points[index].label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          extraLinesData: targetLine == null
              ? const ExtraLinesData()
              : ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: targetLine!,
                      color: color.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [6, 4],
                    ),
                  ],
                ),
          barGroups: [
            for (final (index, point) in points.indexed)
              BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: point.value,
                    color: color,
                    width: 12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:habit_tracker/core/analytics/weekday_breakdown_use_case.dart';

/// A horizontal bar chart showing completion rate per weekday.
class WeekdayBreakdownChart extends StatelessWidget {
  /// Creates a weekday breakdown chart.
  const WeekdayBreakdownChart({
    required this.stats,
    super.key,
  });

  /// Per-weekday statistics to display.
  final List<WeekdayStats> stats;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        for (final day in stats)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    _dayLabels[day.weekday],
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: day.completionRate,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      color: _colorForRate(day.completionRate, colorScheme),
                      minHeight: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(day.completionRate * 100).round()}%',
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _colorForRate(double rate, ColorScheme colorScheme) {
    if (rate >= 0.8) return Colors.green;
    if (rate >= 0.5) return Colors.orange;
    if (rate > 0) return Colors.red;
    return colorScheme.surfaceContainerHighest;
  }
}

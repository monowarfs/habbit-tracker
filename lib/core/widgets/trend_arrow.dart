import 'package:flutter/material.dart';

/// The direction of a trend comparison.
enum TrendDirection {
  /// Value increased from previous period.
  up,

  /// Value decreased from previous period.
  down,

  /// Value stayed roughly the same (within 5% threshold).
  flat,
}

/// A compact widget showing a trend arrow with delta percentage.
///
/// Compares [current] value to [previous] value and displays an
/// arrow indicating the direction of change.
class TrendArrow extends StatelessWidget {
  /// Creates a trend arrow.
  const TrendArrow({
    required this.current,
    required this.previous,
    this.label,
    super.key,
  });

  /// The current period's value.
  final double current;

  /// The previous period's value.
  final double previous;

  /// Optional label shown below the arrow (e.g. "vs last week").
  final String? label;

  /// Calculates the trend direction based on the values.
  TrendDirection get direction {
    if (previous == 0) {
      return current > 0 ? TrendDirection.up : TrendDirection.flat;
    }
    final delta = (current - previous) / previous;
    if (delta > 0.05) return TrendDirection.up;
    if (delta < -0.05) return TrendDirection.down;
    return TrendDirection.flat;
  }

  /// Calculates the absolute percentage change.
  double get deltaPercent {
    if (previous == 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous * 100).abs();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (direction) {
      TrendDirection.up => Colors.green,
      TrendDirection.down => Colors.red,
      TrendDirection.flat => theme.colorScheme.onSurfaceVariant,
    };
    final icon = switch (direction) {
      TrendDirection.up => Icons.trending_up,
      TrendDirection.down => Icons.trending_down,
      TrendDirection.flat => Icons.trending_flat,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        Text(
          '${deltaPercent.toStringAsFixed(0)}%',
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
        if (label != null)
          Text(
            label!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

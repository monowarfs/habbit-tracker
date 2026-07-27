import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/water/presentation/water_amount_formatter.dart';

/// An animated ring showing [totalMl] logged against [goalMl] (FR-W-06).
class WaterProgressRing extends StatelessWidget {
  /// Creates a water progress ring of [size] logical pixels.
  const WaterProgressRing({
    required this.totalMl,
    required this.goalMl,
    required this.unit,
    this.size = 220,
    this.showLabel = true,
    super.key,
  });

  /// Today's logged total, in ml.
  final int totalMl;

  /// The applicable goal, in ml.
  final int goalMl;

  /// The user's preferred display unit (D-01/FR-W-02) — the ring's
  /// numbers convert and localize through this, never showing a raw ml
  /// `int` when the user has chosen fl oz.
  final WaterUnit unit;

  /// The ring's diameter.
  final double size;

  /// Whether to show the "total / goal" text in the ring's center.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final goalMet = goalMl > 0 && totalMl >= goalMl;
    final fraction = goalMl > 0 ? (totalMl / goalMl).clamp(0.0, 1.0) : 0.0;
    final semanticColors = Theme.of(context).extension<AppSemanticColors>();
    final ringColor = goalMet
        ? (semanticColors?.success ?? Theme.of(context).moduleAccents.water)
        : Theme.of(context).moduleAccents.water;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, value, child) => Padding(
                padding: EdgeInsets.all(size * 0.1),
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: size / 10,
                  color: ringColor,
                  backgroundColor: ringColor.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          if (showLabel)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatWaterNumber(context, totalMl, unit),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '/ ${formatWaterAmount(context, goalMl, unit)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

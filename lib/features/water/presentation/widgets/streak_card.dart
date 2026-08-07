import 'package:flutter/material.dart';
import 'package:habit_tracker/core/accessibility/semantic_labels.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/water/domain/usecases/calculate_water_streak.dart';

/// Shows current and longest streak (FR-W-08).
class StreakCard extends StatelessWidget {
  /// Creates a streak card for [streak].
  const StreakCard({required this.streak, super.key});

  /// The streak numbers to display.
  final WaterStreakResult streak;

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>();
    final l10n = AppLocalizations.of(context)!;
    return SemanticLabels.wrap(
      label:
          '${l10n.semanticWaterStreakIndicator}: '
          '${streak.current}, ${streak.longest}',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _StreakStat(
                  icon: Icons.local_fire_department,
                  iconColor: semanticColors?.success,
                  value: streak.current,
                  label: 'Current streak',
                ),
              ),
              Expanded(
                child: _StreakStat(
                  icon: Icons.emoji_events,
                  iconColor: Theme.of(context).moduleAccents.water,
                  value: streak.longest,
                  label: 'Longest streak',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakStat extends StatelessWidget {
  const _StreakStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color? iconColor;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor),
        Text('$value', style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:habit_tracker/core/analytics/goal_attainment_use_case.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Shows a module's goal-attainment rate ("22/30 days (73%)") for the
/// selected period — a distinct stat from streak length, per
/// `docs/superpowers/specs/08-analytics/09-goal-attainment-rate-design.md`.
class GoalAttainmentDisplay extends StatelessWidget {
  /// Creates a goal attainment display.
  const GoalAttainmentDisplay({
    required this.result,
    required this.goalLabel,
    super.key,
  });

  /// The calculated attainment result for the selected period.
  final GoalAttainmentResult result;

  /// Module-specific label for what "hit the goal" means (e.g. "Water
  /// goal reached").
  final String goalLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(l10n.goalAttainmentTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (result.totalDays == 0)
          Text(l10n.goalAttainmentEmpty, style: theme.textTheme.bodyMedium)
        else ...[
          Text(
            l10n.goalAttainmentRate(
              result.metDays,
              result.totalDays,
              (result.rate * 100).round(),
            ),
            style: theme.textTheme.bodyLarge,
          ),
          Text(
            goalLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

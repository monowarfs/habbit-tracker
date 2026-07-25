import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/recaps/year_summary.dart';

/// Combined longest-streak hero card for the yearly recap.
class YearlyRecapHeroCard extends StatelessWidget {
  /// Creates the hero card.
  const YearlyRecapHeroCard({required this.summary, super.key});

  /// The full year summary.
  final YearSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    var longestStreak = 0;
    for (final module in summary.modules) {
      if ((module.longestStreakAll ?? 0) > longestStreak) {
        longestStreak = module.longestStreakAll!;
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade700,
            Colors.blue.shade700,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.emoji_events,
                size: 80,
                color: Colors.amber.shade300,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.yearlyRecapYearLabel(summary.yearNumber),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              if (longestStreak > 0) ...[
                Text(
                  '$longestStreak',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  l10n.recapDayStreak,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 32),
              ],
              Text(
                l10n.recapModulesActive(summary.modules.length),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              Text(
                l10n.recapEncouragement,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

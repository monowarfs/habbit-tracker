import 'package:flutter/material.dart';
import 'package:habit_tracker/core/recaps/year_summary.dart';

/// Combined longest-streak hero card for the yearly recap.
class YearlyRecapHeroCard extends StatelessWidget {
  /// Creates the hero card.
  const YearlyRecapHeroCard({required this.summary, super.key});

  /// The full year summary.
  final YearSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Find the overall longest streak across all modules.
    var longestStreak = 0;
    var bestDay = 0;
    for (final module in summary.modules) {
      if ((module.longestStreakAll ?? 0) > longestStreak) {
        longestStreak = module.longestStreakAll!;
      }
      if ((module.bestDayValue ?? 0) > bestDay) {
        bestDay = module.bestDayValue!;
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
                'Year ${summary.yearNumber}',
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
                  'day streak',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 32),
              ],
              Text(
                '${summary.modules.length} modules active',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              Text(
                'Keep up the great work!',
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

import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/recaps/year_summary.dart';

/// Per-module card widget for the yearly recap story view.
class YearlyRecapCard extends StatelessWidget {
  /// Creates a yearly recap card.
  const YearlyRecapCard({
    required this.moduleStats,
    required this.yearNumber,
    super.key,
  });

  /// The module stats to display.
  final ModuleYearStats moduleStats;

  /// The year number.
  final int yearNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final accentColor = Color(moduleStats.accentColorValue);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.8),
            accentColor.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                moduleStats.displayName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              _buildHeroStat(context, l10n),
              const SizedBox(height: 24),
              ..._buildSupportingStats(context, l10n),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStat(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    String heroValue;
    String heroLabel;

    if (moduleStats.totalMl != null) {
      final liters = (moduleStats.totalMl! / 1000).toStringAsFixed(1);
      heroValue = '$liters L';
      heroLabel = l10n.recapWaterHero;
    } else if (moduleStats.totalDoses != null) {
      heroValue = '${moduleStats.dosesTaken ?? 0}';
      heroLabel = l10n.recapDosesTakenHero;
    } else if (moduleStats.totalPrayers != null) {
      heroValue = '${moduleStats.prayersCompleted ?? 0}';
      heroLabel = l10n.recapPrayersCompletedHero;
    } else {
      heroValue = '-';
      heroLabel = moduleStats.displayName;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heroValue,
          style: theme.textTheme.displayLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          heroLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSupportingStats(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final stats = <Widget>[];

    if (moduleStats.averageDailyMl != null) {
      stats.add(_StatRow(
        label: l10n.recapAverageDailyLabel,
        value: '${moduleStats.averageDailyMl!.toStringAsFixed(0)} ml',
      ));
    }
    if (moduleStats.daysGoalMet != null) {
      stats.add(_StatRow(
        label: l10n.recapDaysGoalMetLabel,
        value: l10n.recapDaysGoalMet(moduleStats.daysGoalMet!),
      ));
    }
    if (moduleStats.adherencePercent != null) {
      stats.add(_StatRow(
        label: l10n.recapAdherenceLabel,
        value: l10n.recapAdherencePercent(
          moduleStats.adherencePercent!.round(),
        ),
      ));
    }
    if (moduleStats.onTimePercent != null) {
      stats.add(_StatRow(
        label: l10n.recapOnTimeLabel,
        value: l10n.recapOnTimePercent(
          moduleStats.onTimePercent!.round(),
        ),
      ));
    }
    if (moduleStats.longestStreakAll != null &&
        moduleStats.longestStreakAll! > 0) {
      stats.add(_StatRow(
        label: l10n.recapLongestStreakLabel,
        value: l10n.recapLongestStreak(moduleStats.longestStreakAll!),
      ));
    }
    if (moduleStats.monthsActive != null && moduleStats.monthsTotal != null) {
      stats.add(_StatRow(
        label: l10n.recapMonthsActiveLabel,
        value: l10n.recapMonthsActive(
          moduleStats.monthsActive!,
          moduleStats.monthsTotal!,
        ),
      ));
    }

    return stats;
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

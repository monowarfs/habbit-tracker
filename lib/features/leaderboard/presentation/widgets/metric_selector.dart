import 'package:flutter/material.dart';
import 'package:habit_tracker/core/gamification/leaderboard/leaderboard_metric.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Toggle between the household leaderboard's 3 ranking metrics.
class MetricSelector extends StatelessWidget {
  /// Creates the selector.
  const MetricSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// The currently selected metric.
  final LeaderboardMetric selected;

  /// Called with the newly selected metric.
  final ValueChanged<LeaderboardMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<LeaderboardMetric>(
        segments: [
          ButtonSegment(
            value: LeaderboardMetric.currentStreak,
            label: Text(l10n.leaderboardMetricStreak),
          ),
          ButtonSegment(
            value: LeaderboardMetric.weeklyCompletion,
            label: Text(l10n.leaderboardMetricWeekly),
          ),
          ButtonSegment(
            value: LeaderboardMetric.level,
            label: Text(l10n.leaderboardMetricLevel),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

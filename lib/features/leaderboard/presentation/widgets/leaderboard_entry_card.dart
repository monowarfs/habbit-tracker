import 'package:flutter/material.dart';
import 'package:habit_tracker/core/gamification/leaderboard/leaderboard_entry.dart';
import 'package:habit_tracker/core/gamification/leaderboard/leaderboard_metric.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/profiles/profile_switcher.dart';

/// One ranked row on the household leaderboard.
class LeaderboardEntryCard extends StatelessWidget {
  /// Creates the card. [isTied] highlights that another entry shares
  /// this one's rank.
  const LeaderboardEntryCard({
    required this.entry,
    required this.metric,
    required this.isTied,
    super.key,
  });

  /// The row to render.
  final LeaderboardEntry entry;

  /// The currently selected ranking metric — determines score formatting.
  final LeaderboardMetric metric;

  /// True when another entry shares [entry]'s rank.
  final bool isTied;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Card(
      color: entry.isCurrentUser ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: Semantics(
          label: entry.hasData ? l10n.leaderboardRank(entry.rank) : null,
          child: CircleAvatar(
            backgroundColor: resolveProfileAvatarColor(entry.avatarColor),
            child: entry.hasData
                ? Text(
                    '${entry.rank}',
                    style: const TextStyle(color: Colors.white),
                  )
                : const Icon(
                    Icons.question_mark,
                    color: Colors.white,
                    size: 16,
                  ),
          ),
        ),
        title: Text(
          entry.isCurrentUser
              ? '${entry.profileName} ${l10n.leaderboardYouLabel}'
              : entry.profileName,
        ),
        subtitle: !entry.hasData
            ? Text(l10n.leaderboardNoOverlap)
            : isTied
            ? Text(l10n.leaderboardTied)
            : null,
        trailing: entry.hasData ? Text(_formatScore(entry.score)) : null,
      ),
    );
  }

  String _formatScore(num score) {
    switch (metric) {
      case LeaderboardMetric.currentStreak:
      case LeaderboardMetric.level:
        return score.toInt().toString();
      case LeaderboardMetric.weeklyCompletion:
        return '${score.round()}%';
    }
  }
}

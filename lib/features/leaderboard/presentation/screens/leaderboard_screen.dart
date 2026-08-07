import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/gamification/leaderboard/leaderboard_metric.dart';
import 'package:habit_tracker/core/gamification/leaderboard/leaderboard_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/features/leaderboard/presentation/widgets/leaderboard_entry_card.dart';
import 'package:habit_tracker/features/leaderboard/presentation/widgets/metric_selector.dart';

/// Ranks household members (same-device profiles) by a chosen metric
/// (merges `docs/superpowers/specs/05-community/
/// 04-household-shared-device-leaderboard-design.md` and
/// `06-gamification/12-household-leaderboard-design.md`).
class LeaderboardScreen extends ConsumerStatefulWidget {
  /// Creates the leaderboard screen.
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardMetric _metric = LeaderboardMetric.currentStreak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profiles = ref.watch(profileListProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaderboardTitle)),
      body: profiles == null
          ? const Center(child: CircularProgressIndicator())
          : profiles.length < 2
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.leaderboardSingleProfile,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                MetricSelector(
                  selected: _metric,
                  onChanged: (metric) => setState(() => _metric = metric),
                ),
                Expanded(child: _LeaderboardList(metric: _metric)),
              ],
            ),
    );
  }
}

class _LeaderboardList extends ConsumerWidget {
  const _LeaderboardList({required this.metric});

  final LeaderboardMetric metric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(householdLeaderboardProvider(metric));

    return entriesAsync.when(
      data: (entries) {
        final rankCounts = <int, int>{};
        for (final entry in entries) {
          if (!entry.hasData) continue;
          rankCounts[entry.rank] = (rankCounts[entry.rank] ?? 0) + 1;
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return LeaderboardEntryCard(
              entry: entry,
              metric: metric,
              isTied: entry.hasData && (rankCounts[entry.rank] ?? 0) > 1,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          const Center(child: Icon(Icons.error_outline, size: 32)),
    );
  }
}

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_gate_widget.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/mood/presentation/providers/mood_providers.dart';

/// Mood's stats screen: a distribution of the last 30 days' check-ins by
/// mood value (1-5) and the current streak. Wrapped in `PremiumGateWidget`
/// — defense in depth against a direct deep link bypassing
/// `MoodHomeScreen`'s own gate.
class MoodStatsScreen extends ConsumerWidget {
  /// Creates the mood stats screen.
  const MoodStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moodStatsTitle)),
      body: PremiumGateWidget(child: _StatsContent(l10n: l10n)),
    );
  }
}

class _StatsContent extends ConsumerWidget {
  const _StatsContent({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = localDayKey(clock.now());
    final start = today.addDays(-29);
    final logsAsync = ref.watch(moodLogsInRangeProvider(start, today));
    final streakAsync = ref.watch(moodCurrentStreakProvider);
    final logs = logsAsync.value;

    if (logs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final countByValue = <int, int>{
      for (final v in const [1, 2, 3, 4, 5]) v: 0,
    };
    for (final log in logs) {
      countByValue[log.moodValue] = (countByValue[log.moodValue] ?? 0) + 1;
    }
    final points = [
      for (final value in const [1, 2, 3, 4, 5])
        BarChartPoint(
          label: '$value',
          value: (countByValue[value] ?? 0).toDouble(),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.moodStatsCurrentStreak(streakAsync.value ?? 0),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(l10n.moodStatsDistributionLabel),
          PeriodBarChart(
            points: points,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

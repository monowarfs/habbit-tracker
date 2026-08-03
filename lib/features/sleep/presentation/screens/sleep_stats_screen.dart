import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/sleep/presentation/providers/sleep_providers.dart';

/// Sleep's stats screen: last 7 nights' duration and the current streak,
/// reusing the shared `PeriodBarChart` and streak calculator.
class SleepStatsScreen extends ConsumerWidget {
  /// Creates the sleep stats screen.
  const SleepStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final today = localDayKey(clock.now());
    final start = today.addDays(-6);
    final logsAsync = ref.watch(sleepLogsInRangeProvider(start, today));
    final streakAsync = ref.watch(sleepCurrentStreakProvider);
    final logs = logsAsync.value;

    if (logs == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.sleepStatsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final minutesByDay = <String, int>{};
    for (final log in logs) {
      final key = localDayKey(log.wakeTime).toIso();
      minutesByDay[key] = (minutesByDay[key] ?? 0) + log.durationMinutes;
    }
    final points = <BarChartPoint>[];
    var day = start;
    while (day.compareTo(today) <= 0) {
      final minutes = minutesByDay[day.toIso()] ?? 0;
      points.add(BarChartPoint(label: '${day.day}', value: minutes / 60));
      day = day.addDays(1);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sleepStatsTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sleepStatsCurrentStreak(streakAsync.value ?? 0),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            PeriodBarChart(
              points: points,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

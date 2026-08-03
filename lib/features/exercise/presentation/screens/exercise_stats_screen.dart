import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_gate_widget.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/exercise/domain/usecases/aggregate_weekly_minutes.dart';
import 'package:habit_tracker/features/exercise/presentation/providers/exercise_providers.dart';

/// Exercise's stats screen: last 8 weeks' total workout minutes and the
/// current streak, reusing the shared `PeriodBarChart` and streak
/// calculator. Wrapped in `PremiumGateWidget` — defense in depth against
/// a direct deep link bypassing `ExerciseHomeScreen`'s own gate.
class ExerciseStatsScreen extends ConsumerWidget {
  /// Creates the exercise stats screen.
  const ExerciseStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exerciseStatsTitle)),
      body: PremiumGateWidget(child: _StatsContent(l10n: l10n)),
    );
  }
}

class _StatsContent extends ConsumerWidget {
  const _StatsContent({required this.l10n});

  final AppLocalizations l10n;

  static const _weeksShown = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = localDayKey(clock.now());
    // Snap to this week's Monday first, then step back full weeks — keeps
    // the window exactly `_weeksShown` buckets regardless of today's
    // weekday (a plain `today.addDays(-N)` isn't Monday-aligned, so the
    // aggregator's own week-snapping would otherwise add an extra bucket
    // on 6 of 7 weekdays).
    final start = weekStartFor(today).addDays(-(_weeksShown - 1) * 7);
    final logsAsync = ref.watch(exerciseLogsInRangeProvider(start, today));
    final streakAsync = ref.watch(exerciseCurrentStreakProvider);
    final logs = logsAsync.value;

    if (logs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    const aggregator = AggregateWeeklyMinutesUseCase();
    final weeklyPoints = aggregator.execute(
      logs: logs,
      start: start,
      end: today,
    );
    final chartPoints = [
      for (final point in weeklyPoints)
        BarChartPoint(
          label: '${point.weekStart.month}/${point.weekStart.day}',
          value: point.totalMinutes.toDouble(),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.exerciseStatsCurrentStreak(streakAsync.value ?? 0),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(l10n.exerciseStatsWeeklyMinutesLabel),
          PeriodBarChart(
            points: chartPoints,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

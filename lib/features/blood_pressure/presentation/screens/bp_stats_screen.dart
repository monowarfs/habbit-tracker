import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_gate_widget.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_log.dart';
import 'package:habit_tracker/features/blood_pressure/presentation/providers/bp_providers.dart';

/// Blood Pressure's stats screen: last 7 days' systolic/diastolic and the
/// current streak, reusing the shared `PeriodBarChart` and streak
/// calculator. Wrapped in `PremiumGateWidget` — defense in depth against
/// a direct deep link bypassing `BpHomeScreen`'s own gate.
class BpStatsScreen extends ConsumerWidget {
  /// Creates the blood pressure stats screen.
  const BpStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bpStatsTitle)),
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
    final start = today.addDays(-6);
    final logsAsync = ref.watch(bpLogsInRangeProvider(start, today));
    final streakAsync = ref.watch(bpCurrentStreakProvider);
    final logs = logsAsync.value;

    if (logs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Group by day once; average per day, when multiple readings exist
    // the same day.
    final logsByDay = <String, List<BpLog>>{};
    for (final log in logs) {
      (logsByDay[localDayKey(log.loggedAt).toIso()] ??= []).add(log);
    }
    final systolicPoints = <BarChartPoint>[];
    final diastolicPoints = <BarChartPoint>[];
    var day = start;
    while (day.compareTo(today) <= 0) {
      final dayLogs = logsByDay[day.toIso()] ?? const [];
      systolicPoints.add(
        BarChartPoint(
          label: '${day.day}',
          value: _average(dayLogs.map((l) => l.systolic)),
        ),
      );
      diastolicPoints.add(
        BarChartPoint(
          label: '${day.day}',
          value: _average(dayLogs.map((l) => l.diastolic)),
        ),
      );
      day = day.addDays(1);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.bpStatsCurrentStreak(streakAsync.value ?? 0),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(l10n.bpStatsSystolicLabel),
          PeriodBarChart(
            points: systolicPoints,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(l10n.bpStatsDiastolicLabel),
          PeriodBarChart(
            points: diastolicPoints,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ],
      ),
    );
  }

  double _average(Iterable<int> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}

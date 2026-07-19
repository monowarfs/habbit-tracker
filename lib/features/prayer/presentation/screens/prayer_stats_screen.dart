import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_adherence.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_streak.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';

/// Streak, longest streak, per-prayer on-time %, Qadha summary (FR-P-10).
/// Reuses `core/widgets/charts/period_bar_chart.dart`.
class PrayerStatsScreen extends ConsumerWidget {
  /// Creates the stats screen.
  const PrayerStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = localDayKey(clock.now());
    final rangeStart = today.addDays(-29);
    final recordsAsync = ref.watch(
      prayerRecordsInRangeProvider(start: rangeStart, end: today),
    );
    final counters =
        ref.watch(prayerQadhaCountersProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer stats')),
      body: recordsAsync.when(
        data: (records) {
          final byDay = <LocalDate, List<PrayerRecord>>{};
          for (final record in records) {
            byDay.putIfAbsent(record.prayerDate, () => []).add(record);
          }
          final streak = const CalculatePrayerStreakUseCase().execute(
            recordsByDay: byDay,
            earliestDay: rangeStart,
            today: today,
          );
          final adherence = calculateAdherence(records: records);
          final points = [
            for (var offset = 6; offset >= 0; offset--)
              BarChartPoint(
                label: today.addDays(-offset).day.toString(),
                value: (byDay[today.addDays(-offset)] ?? const [])
                    .where(
                      (r) => r.storedStatus == PrayerStatus.prayed,
                    )
                    .length
                    .toDouble(),
              ),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Current streak: ${streak.current} days'),
              Text('Longest streak: ${streak.longest} days'),
              const SizedBox(height: 16),
              const Text('Prayers completed, last 7 days'),
              PeriodBarChart(
                points: points,
                color: ModuleAccents.prayer,
                targetLine: 5,
              ),
              const SizedBox(height: 16),
              const Text('Qadha summary'),
              for (final counter in counters)
                Text(
                  '${_labelFor(counter.prayerName)}: ${counter.count}',
                ),
              const SizedBox(height: 16),
              const Text('On-time %, last 30 days'),
              for (final entry in adherence.entries)
                Text(
                  '${_labelFor(entry.key)}: '
                  '${entry.value.total == 0 ? 0 : (entry.value.prayed * 100 / entry.value.total).round()}%',
                ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
      ),
    );
  }

  String _labelFor(PrayerName name) => switch (name) {
    PrayerName.fajr => 'Fajr',
    PrayerName.dhuhr => 'Dhuhr',
    PrayerName.asr => 'Asr',
    PrayerName.maghrib => 'Maghrib',
    PrayerName.isha => 'Isha',
  };
}

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final today = localDayKey(clock.now());
    final rangeStart = today.addDays(-29);
    final recordsAsync = ref.watch(
      prayerRecordsInRangeProvider(start: rangeStart, end: today),
    );
    final counters = ref.watch(prayerQadhaCountersProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.prayerStatsTitle)),
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
              Text(l10n.prayerStatsCurrentStreak(streak.current)),
              Text(l10n.prayerStatsLongestStreak(streak.longest)),
              const SizedBox(height: 16),
              Text(l10n.prayerStatsLast7DaysLabel),
              PeriodBarChart(
                points: points,
                color: Theme.of(context).moduleAccents.prayer,
                targetLine: 5,
              ),
              const SizedBox(height: 16),
              Text(l10n.prayerStatsQadhaSummaryLabel),
              for (final counter in counters)
                Text(
                  '${_labelFor(l10n, counter.prayerName)}: ${counter.count}',
                ),
              const SizedBox(height: 16),
              Text(l10n.prayerStatsOnTimeLabel),
              for (final entry in adherence.entries)
                Text(
                  '${_labelFor(l10n, entry.key)}: '
                  '${_onTimePercent(entry.value)}%',
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
      ),
    );
  }

  String _labelFor(AppLocalizations l10n, PrayerName name) => switch (name) {
    PrayerName.fajr => l10n.prayerNameFajr,
    PrayerName.dhuhr => l10n.prayerNameDhuhr,
    PrayerName.asr => l10n.prayerNameAsr,
    PrayerName.maghrib => l10n.prayerNameMaghrib,
    PrayerName.isha => l10n.prayerNameIsha,
  };

  int _onTimePercent(PrayerAdherenceStats stats) =>
      stats.total == 0 ? 0 : (stats.prayed * 100 / stats.total).round();
}

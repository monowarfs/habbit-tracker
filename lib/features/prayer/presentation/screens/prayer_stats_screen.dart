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
          final overallSplit = _sumSplit(adherence.values);
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
              const SizedBox(height: 16),
              Text(l10n.prayerStatsSplitTitle),
              Text(
                l10n.prayerOnTimeLabel(
                  overallSplit.prayed,
                  _percent(overallSplit.prayed, overallSplit.total),
                ),
              ),
              Text(
                l10n.prayerLateLabel(
                  overallSplit.prayedLate,
                  _percent(overallSplit.prayedLate, overallSplit.total),
                ),
              ),
              Text(
                l10n.prayerMissedLabel(
                  overallSplit.missed,
                  _percent(overallSplit.missed, overallSplit.total),
                ),
              ),
              Text(
                l10n.prayerOnTimeRate(
                  _percent(overallSplit.prayed, overallSplit.total),
                ),
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
      _percent(stats.prayed, stats.total);

  /// Sums per-prayer-name stats into a single overall on-time/late/missed
  /// split (08-analytics/10-prayer-on-time-vs-late) — a first-pass single
  /// combined figure rather than a per-prayer-name breakdown.
  PrayerAdherenceStats _sumSplit(Iterable<PrayerAdherenceStats> stats) {
    var prayed = 0;
    var prayedLate = 0;
    var missed = 0;
    var total = 0;
    for (final s in stats) {
      prayed += s.prayed;
      prayedLate += s.prayedLate;
      missed += s.missed;
      total += s.total;
    }
    return (
      prayed: prayed,
      prayedLate: prayedLate,
      missed: missed,
      total: total,
    );
  }

  int _percent(int count, int total) =>
      total == 0 ? 0 : (count * 100 / total).round();
}

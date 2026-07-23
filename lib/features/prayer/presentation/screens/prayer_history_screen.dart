import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/providers/module_day_status_provider.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/habit_heatmap_calendar.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';

/// Per-day completion coloring + day drill-down, visualizing FR-P-09's
/// streak data over a calendar month.
class PrayerHistoryScreen extends ConsumerStatefulWidget {
  /// Creates the history screen.
  const PrayerHistoryScreen({super.key});

  @override
  ConsumerState<PrayerHistoryScreen> createState() =>
      _PrayerHistoryScreenState();
}

class _PrayerHistoryScreenState extends ConsumerState<PrayerHistoryScreen> {
  DateTime _visibleMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final monthStart = LocalDate(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final monthEnd = LocalDate(
      _visibleMonth.year,
      _visibleMonth.month,
      daysInMonth,
    );
    final recordsAsync = ref.watch(
      prayerRecordsInRangeProvider(start: monthStart, end: monthEnd),
    );

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.prayerHistoryTitle)),
      body: recordsAsync.when(
        data: (records) {
          final byDay = <LocalDate, List<PrayerRecord>>{};
          for (final record in records) {
            byDay.putIfAbsent(record.prayerDate, () => []).add(record);
          }
          final dayStatus = ref
              .watch(
                moduleDayStatusProvider(
                  'prayer',
                  DateRange(start: monthStart, end: monthEnd),
                ),
              )
              .value;
          if (dayStatus == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() {
                      _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month - 1,
                      );
                    }),
                  ),
                  Text('${monthStart.year}-${monthStart.month}'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() {
                      _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month + 1,
                      );
                    }),
                  ),
                ],
              ),
              HabitHeatmapCalendar(
                month: monthStart,
                dayStatus: dayStatus,
                accentColor: ModuleAccents.prayer,
                // Five daily prayers is a fixed, known ceiling — no
                // per-instance computation needed.
                maxValue: 5,
                onDayTap: (day) {
                  final dayRecords = byDay[day] ?? const [];
                  if (dayRecords.isNotEmpty) {
                    _showDayDetail(context, dayRecords);
                  }
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
      ),
    );
  }

  void _showDayDetail(
    BuildContext context,
    List<PrayerRecord> records,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = [...records]
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => ListView(
          shrinkWrap: true,
          children: [
            for (final record in sorted)
              ListTile(
                title: Text(_labelFor(l10n, record.prayerName)),
                trailing: Text(_statusLabel(l10n, record.storedStatus)),
              ),
          ],
        ),
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

  String _statusLabel(AppLocalizations l10n, PrayerStatus status) =>
      switch (status) {
        PrayerStatus.upcoming => l10n.prayerStatusUpcoming,
        PrayerStatus.due => l10n.prayerStatusDue,
        PrayerStatus.prayed => l10n.prayerStatusPrayed,
        PrayerStatus.missed => l10n.prayerStatusMissedDue,
      };
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() {
            _visibleMonth = DateTime(
              _visibleMonth.year,
              _visibleMonth.month - 1,
            );
          }),
        ),
        actions: [
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
      body: recordsAsync.when(
        data: (records) {
          final byDay = <LocalDate, List<PrayerRecord>>{};
          for (final record in records) {
            byDay.putIfAbsent(record.prayerDate, () => []).add(record);
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final day = LocalDate(
                _visibleMonth.year,
                _visibleMonth.month,
                index + 1,
              );
              final dayRecords = byDay[day] ?? const [];
              final allPrayed =
                  dayRecords.length == 5 &&
                  dayRecords.every(
                    (r) => r.storedStatus == PrayerStatus.prayed,
                  );
              final anyMissed = dayRecords.any(
                (r) => r.storedStatus == PrayerStatus.missed,
              );
              final color = allPrayed
                  ? Theme.of(context)
                        .extension<AppSemanticColors>()!
                        .success
                  : anyMissed
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest;
              return InkWell(
                onTap: dayRecords.isEmpty
                    ? null
                    : () => _showDayDetail(context, dayRecords),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  color: color,
                  alignment: Alignment.center,
                  child: Text('${index + 1}'),
                ),
              );
            },
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
      ),
    );
  }

  void _showDayDetail(
    BuildContext context,
    List<PrayerRecord> records,
  ) {
    final sorted = [...records]
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final record in sorted)
            ListTile(
              title: Text(_labelFor(record.prayerName)),
              trailing: Text(_statusLabel(record.storedStatus)),
            ),
        ],
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

  String _statusLabel(PrayerStatus status) => switch (status) {
    PrayerStatus.upcoming => 'Upcoming',
    PrayerStatus.due => 'Due',
    PrayerStatus.prayed => 'Prayed',
    PrayerStatus.missed => 'Missed',
  };
}

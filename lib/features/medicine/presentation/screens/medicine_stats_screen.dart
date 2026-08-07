import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/providers/module_day_status_provider.dart';
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/chart_data_table.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/core/widgets/habit_heatmap_calendar.dart';
import 'package:habit_tracker/core/widgets/personal_record_section.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/dose_status.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:intl/intl.dart';

/// Stats tab (adherence chart across all medicines over the last 7 days,
/// plus a missed-doses list, FR-M-08) and History tab (per-day heatmap +
/// drill-down), matching Water's Stats/History `TabBar` split.
class MedicineStatsScreen extends ConsumerStatefulWidget {
  /// Creates the medicine stats screen.
  const MedicineStatsScreen({super.key});

  @override
  ConsumerState<MedicineStatsScreen> createState() =>
      _MedicineStatsScreenState();
}

class _MedicineStatsScreenState extends ConsumerState<MedicineStatsScreen> {
  LocalDate _historyMonth = LocalDate.fromDateTime(clock.now());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.medicineStatsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.medicineStatsTabStats),
              Tab(text: l10n.medicineStatsTabHistory),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildStatsTab(context, l10n), _buildHistoryTab(l10n)],
        ),
      ),
    );
  }

  Widget _buildStatsTab(BuildContext context, AppLocalizations l10n) {
    final today = LocalDate.fromDateTime(clock.now());
    final start = today.addDays(-6);
    final doses = ref
        .watch(medicineDosesInRangeProvider((start: start, end: today)))
        .value;

    if (doses == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final now = clock.now();
    final byDay = <LocalDate, int>{};
    final missed = <MedicineDose>[];
    for (final dose in doses) {
      final status = effectiveDoseStatus(
        storedStatus: dose.storedStatus,
        scheduledFor: dose.scheduledFor,
        now: now,
        graceWindowMinutes: dose.graceWindowMinutes,
      );
      if (status == MedicineDoseStatus.done) {
        final day = LocalDate.fromDateTime(dose.scheduledFor.toLocal());
        byDay[day] = (byDay[day] ?? 0) + 1;
      } else if (status == MedicineDoseStatus.missed) {
        missed.add(dose);
      }
    }
    final points = [
      for (var i = 0; i <= 6; i++)
        BarChartPoint(
          label: DateFormat.E().format(start.addDays(i).toDateTimeUtc()),
          value: (byDay[start.addDays(i)] ?? 0).toDouble(),
        ),
    ];
    // A window wide enough to contain any realistic current streak,
    // without scanning full history on every stats-tab build (the
    // `personal_records` table, not this, is the true all-time source —
    // `core/analytics/record_backfill.dart`).
    final currentStreakRangeStart = today.addDays(-89);
    final currentStreakDayStatus = ref
        .watch(
          moduleDayStatusProvider(
            'medicine',
            DateRange(start: currentStreakRangeStart, end: today),
          ),
        )
        .value;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.medicineStatsDosesTakenLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ChartDataTableToggle(
          points: points,
          color: Theme.of(context).moduleAccents.medicine,
          chartSemanticsLabel: l10n.semanticMedicineStatsChart,
        ),
        if (currentStreakDayStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: PersonalRecordSection(
              moduleId: 'medicine',
              currentStreak: currentStreak(currentStreakDayStatus, today),
              accentColor: Theme.of(context).moduleAccents.medicine,
            ),
          ),
        const SizedBox(height: 24),
        Text(
          l10n.medicineStatsMissedDosesLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (missed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(l10n.medicineStatsNoMissedDoses),
          )
        else
          for (final dose in missed)
            ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(
                DateFormat.MMMEd().add_jm().format(dose.scheduledFor.toLocal()),
              ),
            ),
      ],
    );
  }

  Widget _buildHistoryTab(AppLocalizations l10n) {
    final monthStart = LocalDate(_historyMonth.year, _historyMonth.month, 1);
    final daysInMonth = DateTime(
      monthStart.year,
      monthStart.month + 1,
      0,
    ).day;
    final monthEnd = LocalDate(monthStart.year, monthStart.month, daysInMonth);

    final dayStatus = ref
        .watch(
          moduleDayStatusProvider(
            'medicine',
            DateRange(start: monthStart, end: monthEnd),
          ),
        )
        .value;
    final doses = ref
        .watch(medicineDosesInRangeProvider((start: monthStart, end: monthEnd)))
        .value;
    final medicines = ref.watch(medicinesProvider(includeArchived: true)).value;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n.commonPreviousMonth,
                onPressed: () =>
                    setState(() => _historyMonth = monthStart.addMonths(-1)),
              ),
              Text('${monthStart.year}-${monthStart.month}'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n.commonNextMonth,
                onPressed: () =>
                    setState(() => _historyMonth = monthStart.addMonths(1)),
              ),
            ],
          ),
          if (dayStatus == null || doses == null || medicines == null)
            const Center(child: CircularProgressIndicator())
          else
            Builder(
              builder: (context) {
                final byDay = <LocalDate, List<MedicineDose>>{};
                for (final dose in doses) {
                  final day = LocalDate.fromDateTime(
                    dose.scheduledFor.toLocal(),
                  );
                  byDay.putIfAbsent(day, () => []).add(dose);
                }
                // A fixed, screen-lifetime ceiling — the max number of
                // doses scheduled on any single day in the visible range
                // — not a per-day target, so paging months never
                // rescales what a color means.
                final maxValue = byDay.values.fold<int>(
                  1,
                  (a, list) => list.length > a ? list.length : a,
                );
                return HabitHeatmapCalendar(
                  month: monthStart,
                  dayStatus: dayStatus,
                  accentColor: Theme.of(context).moduleAccents.medicine,
                  maxValue: maxValue,
                  onDayTap: (day) {
                    final dayDoses = byDay[day] ?? const [];
                    if (dayDoses.isNotEmpty) {
                      _showDayDetail(context, dayDoses, medicines);
                    }
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  void _showDayDetail(
    BuildContext context,
    List<MedicineDose> doses,
    List<Medicine> medicines,
  ) {
    final sorted = [...doses]
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => ListView(
          shrinkWrap: true,
          children: [
            for (final dose in sorted)
              ListTile(
                title: Text(
                  medicines
                      .firstWhere(
                        (m) => m.id == dose.medicineId,
                        orElse: () => medicines.first,
                      )
                      .name,
                ),
                subtitle: Text(
                  DateFormat.jm().format(dose.scheduledFor.toLocal()),
                ),
                trailing: Text(dose.storedStatus.name),
              ),
          ],
        ),
      ),
    );
  }
}

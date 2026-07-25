import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/analytics/goal_attainment_use_case.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/providers/module_day_status_provider.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/core/widgets/goal_attainment_display.dart';
import 'package:habit_tracker/core/widgets/habit_heatmap_calendar.dart';
import 'package:habit_tracker/core/widgets/responsive_breakpoints.dart';
import 'package:habit_tracker/core/widgets/trend_arrow.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/water/domain/usecases/aggregate_water_series.dart';
import 'package:habit_tracker/features/water/domain/usecases/resolve_goal_for_date.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';
import 'package:habit_tracker/features/water/presentation/water_amount_formatter.dart';
import 'package:habit_tracker/features/water/presentation/widgets/streak_card.dart';
import 'package:habit_tracker/features/water/presentation/widgets/water_log_tile.dart';
import 'package:intl/intl.dart';

enum _ChartRange { week, month, year }

/// Water stats: Stats tab (weekly/monthly/yearly charts + streak card,
/// FR-W-08) and History tab (calendar + list drill-down).
class WaterStatsScreen extends ConsumerStatefulWidget {
  /// Creates the water stats screen.
  const WaterStatsScreen({super.key});

  @override
  ConsumerState<WaterStatsScreen> createState() => _WaterStatsScreenState();
}

class _WaterStatsScreenState extends ConsumerState<WaterStatsScreen> {
  _ChartRange _range = _ChartRange.month;
  LocalDate _historyMonth = localDayKey(clock.now());
  LocalDate? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.waterStatsTabStats),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.waterStatsTabStats),
              Tab(text: l10n.waterStatsTabHistory),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MaxContentWidth(child: _buildStatsTab(context, l10n)),
            MaxContentWidth(child: _buildHistoryTab(context, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab(BuildContext context, AppLocalizations l10n) {
    final today = localDayKey(clock.now());
    final (start, period, labelFor) = switch (_range) {
      _ChartRange.week => (
        today.addDays(-6),
        WaterAggregationPeriod.daily,
        (LocalDate d) => '${d.day}',
      ),
      _ChartRange.month => (
        today.addDays(-29),
        WaterAggregationPeriod.daily,
        (LocalDate d) => '${d.day}',
      ),
      _ChartRange.year => (
        LocalDate(today.year, today.month, 1).addDays(-365),
        WaterAggregationPeriod.monthly,
        (LocalDate d) => '${d.month}',
      ),
    };

    final series = ref.watch(
      waterSeriesProvider(start: start, end: today, period: period),
    );
    final goal = ref.watch(currentWaterGoalProvider).value;
    final streak = ref.watch(waterStreakProvider);
    final dayStatus = ref
        .watch(
          moduleDayStatusProvider('water', DateRange(start: start, end: today)),
        )
        .value;
    final attainment = dayStatus == null
        ? null
        : const GoalAttainmentUseCase().calculate(dayStatus: dayStatus);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<_ChartRange>(
          segments: [
            ButtonSegment(
              value: _ChartRange.week,
              label: Text(l10n.waterStatsPeriodWeek),
            ),
            ButtonSegment(
              value: _ChartRange.month,
              label: Text(l10n.waterStatsPeriodMonth),
            ),
            ButtonSegment(
              value: _ChartRange.year,
              label: Text(l10n.waterStatsPeriodYear),
            ),
          ],
          selected: {_range},
          onSelectionChanged: (selection) =>
              setState(() => _range = selection.first),
        ),
        const SizedBox(height: 16),
        if (series == null)
          const Center(child: CircularProgressIndicator())
        else
          PeriodBarChart(
            points: [
              for (final point in series)
                BarChartPoint(
                  label: labelFor(point.bucketStart),
                  value: point.totalMl.toDouble(),
                ),
            ],
            color: ModuleAccents.water,
            targetLine: goal?.goalMl.toDouble(),
          ),
        if (series != null && series.length >= 2)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TrendArrow(
                  current: series.last.totalMl.toDouble(),
                  previous: series[series.length - 2].totalMl.toDouble(),
                  label: l10n.trendArrowVsPrevious,
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (streak != null) StreakCard(streak: streak),
        if (attainment != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: GoalAttainmentDisplay(
              result: attainment,
              goalLabel: l10n.goalAttainmentWater,
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryTab(BuildContext context, AppLocalizations l10n) {
    final monthStart = LocalDate(_historyMonth.year, _historyMonth.month, 1);
    final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final monthEnd = LocalDate(monthStart.year, monthStart.month, daysInMonth);

    final entries = ref
        .watch(waterEntriesInRangeProvider((start: monthStart, end: monthEnd)))
        .value;
    final goals = ref.watch(allWaterGoalsProvider).value;
    final unit =
        ref.watch(appSettingsProvider).value?.waterUnit ?? WaterUnit.ml;
    final dayStatus = ref
        .watch(
          moduleDayStatusProvider(
            'water',
            DateRange(start: monthStart, end: monthEnd),
          ),
        )
        .value;
    // Goal-relative color scale — stable across months, unlike scaling to
    // whatever the visible month's own busiest day happened to be. Uses
    // the goal in effect on the last day of the range so a mid-month
    // change still resolves to one stable number for the whole grid.
    const resolveGoal = ResolveGoalForDateUseCase();
    final maxValue = goals == null || goals.isEmpty
        ? 2000
        : resolveGoal.execute(goals, monthEnd).goalMl;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                _historyMonth = monthStart.addMonths(-1);
                _selectedDay = null;
              }),
            ),
            Text('${monthStart.year}-${monthStart.month}'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                _historyMonth = monthStart.addMonths(1);
                _selectedDay = null;
              }),
            ),
          ],
        ),
        if (dayStatus == null || entries == null)
          const Center(child: CircularProgressIndicator())
        else if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(l10n.waterStatsHistoryEmpty),
          )
        else
          HabitHeatmapCalendar(
            month: monthStart,
            dayStatus: dayStatus,
            accentColor: Colors.green,
            maxValue: maxValue,
            onDayTap: (day) => setState(() => _selectedDay = day),
            useSquareCells: true,
            tooltipForDay: (day, status) {
              final dateStr = DateFormat.MMMd().format(day.toDateTimeUtc());
              if (status == null || status.kind == ModuleDayStatusKind.none) {
                return dateStr;
              }
              final amount = formatWaterAmount(
                context,
                status.value.toInt(),
                unit,
              );
              return '$dateStr — $amount';
            },
          ),
        if (_selectedDay case final day?)
          for (final entry in (entries ?? const []).where(
            (e) => localDayKey(e.loggedAt) == day,
          ))
            WaterLogTile(
              entry: entry,
              unit: unit,
              onDelete: () => ref
                  .read(waterControllerProvider.notifier)
                  .deleteEntry(entry.id),
            ),
      ],
    );
  }
}

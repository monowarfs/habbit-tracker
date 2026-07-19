import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/reports/presentation/providers/reports_providers.dart';

/// Weekly/monthly/yearly cross-module reports (FR-C-12/14).
class ReportsScreen extends ConsumerStatefulWidget {
  /// Creates the reports screen.
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.week;
  late LocalDate _anchor = localDayKey(clock.now());

  void _shiftPeriod(int direction) {
    setState(() {
      _anchor = switch (_period) {
        ReportPeriod.week => _anchor.addDays(7 * direction),
        ReportPeriod.month => LocalDate(
          _anchor.year,
          _anchor.month + direction,
          1,
        ),
        ReportPeriod.year => LocalDate(
          _anchor.year + direction,
          _anchor.month,
          1,
        ),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reportsAsync = ref.watch(
      moduleReportsProvider((period: _period, anchor: _anchor)),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftPeriod(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shiftPeriod(1),
          ),
        ],
      ),
      body: Column(
        children: [
          SegmentedButton<ReportPeriod>(
            segments: [
              ButtonSegment(
                value: ReportPeriod.week,
                label: Text(l10n.reportsPeriodWeek),
              ),
              ButtonSegment(
                value: ReportPeriod.month,
                label: Text(l10n.reportsPeriodMonth),
              ),
              ButtonSegment(
                value: ReportPeriod.year,
                label: Text(l10n.reportsPeriodYear),
              ),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          Expanded(
            child: reportsAsync.when(
              data: (reports) => reports.isEmpty
                  ? Center(child: Text(l10n.reportsEmptyState))
                  : ListView(
                      children: [
                        for (final report in reports)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    report.displayName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    l10n.reportsLongestStreak(
                                      report.longestStreak,
                                    ),
                                  ),
                                  PeriodBarChart(
                                    points: report.points,
                                    color: report.accentColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
              error: (error, stack) => Center(child: Text('$error')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

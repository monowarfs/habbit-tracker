import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // ponytail: hardcoded English strings — l10n keys land in a later
    // task (`gen_l10n` additions), swapped in without changing this
    // screen's structure.
    final reportsAsync = ref.watch(
      moduleReportsProvider((period: _period, anchor: _anchor)),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
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
            segments: const [
              ButtonSegment(value: ReportPeriod.week, label: Text('Week')),
              ButtonSegment(value: ReportPeriod.month, label: Text('Month')),
              ButtonSegment(value: ReportPeriod.year, label: Text('Year')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          Expanded(
            child: reportsAsync.when(
              data: (reports) => reports.isEmpty
                  ? const Center(child: Text('No data for this period'))
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
                                    'Longest streak: '
                                    '${report.longestStreak} days',
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

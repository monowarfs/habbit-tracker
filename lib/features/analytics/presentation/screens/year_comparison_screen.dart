import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/analytics/presentation/providers/year_comparison_provider.dart';

/// "vs. Last Year" cross-module comparison screen (`docs/superpowers/
/// specs/08-analytics/06-comparison-to-past-self-IMPLEMENTATION-PLAN.md`):
/// one overlay [PeriodBarChart] per visible module, this period's series
/// against the same period one year prior. Reuses the "list every visible
/// module" layout `HeatmapScreen` already established rather than adding
/// a module picker. Gated behind [yearComparisonEligibleProvider] — a
/// full year of app history is a hard prerequisite for the comparison to
/// mean anything (design doc).
class YearComparisonScreen extends ConsumerStatefulWidget {
  /// Creates the comparison screen.
  const YearComparisonScreen({super.key});

  @override
  ConsumerState<YearComparisonScreen> createState() =>
      _YearComparisonScreenState();
}

class _YearComparisonScreenState extends ConsumerState<YearComparisonScreen> {
  ReportPeriod _period = ReportPeriod.month;
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
        ReportPeriod.custom || ReportPeriod.allTime => _anchor,
      };
    });
  }

  String _periodLabel(AppLocalizations l10n) => switch (_period) {
    ReportPeriod.week => l10n.reportsPeriodWeek,
    ReportPeriod.month => l10n.reportsPeriodMonth,
    ReportPeriod.year => l10n.reportsPeriodYear,
    ReportPeriod.custom || ReportPeriod.allTime => '',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final eligible = ref.watch(yearComparisonEligibleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.comparisonTitle),
        actions: !eligible
            ? null
            : [
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
      body: !eligible
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.comparisonEmptyState,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SegmentedButton<ReportPeriod>(
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
                    onSelectionChanged: (s) =>
                        setState(() => _period = s.first),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final module
                          in ref.watch(visibleHabitModulesProvider))
                        _ModuleComparisonCard(
                          moduleId: module.id,
                          displayName: module.metadata.displayName,
                          icon: module.metadata.icon,
                          accentColor: module.metadata.accentColor,
                          period: _period,
                          periodLabel: _periodLabel(l10n),
                          anchor: _anchor,
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ModuleComparisonCard extends ConsumerWidget {
  const _ModuleComparisonCard({
    required this.moduleId,
    required this.displayName,
    required this.icon,
    required this.accentColor,
    required this.period,
    required this.periodLabel,
    required this.anchor,
  });

  final String moduleId;
  final String displayName;
  final IconData icon;
  final Color accentColor;
  final ReportPeriod period;
  final String periodLabel;
  final LocalDate anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final comparisonAsync = ref.watch(
      yearComparisonProvider(moduleId, period, anchor),
    );
    return comparisonAsync.when(
      data: (comparison) {
        final hasData =
            comparison.currentPoints.any((p) => p.value != 0) ||
            comparison.lastYearPoints.any((p) => p.value != 0);
        if (!hasData) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: accentColor),
                  const SizedBox(width: 8),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PeriodBarChart(
                points: comparison.currentPoints,
                overlayPoints: comparison.lastYearPoints,
                overlayLabel: l10n.comparisonPastLabel,
                color: accentColor,
              ),
              const SizedBox(height: 4),
              _Legend(
                l10n: l10n,
                color: accentColor,
                currentLabel: l10n.comparisonCurrentLabel(periodLabel),
              ),
            ],
          ),
        );
      },
      error: (error, stack) => Text('$error'),
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// Two color swatches under each module's chart, pairing [color] with
/// [currentLabel] and a lighter version of [color] with the shared "Last
/// year" label — the visual legend `PeriodBarChart` itself doesn't draw
/// (its own doc comment: no built-in legend, only the accessibility
/// [PeriodBarChart.overlayLabel]).
class _Legend extends StatelessWidget {
  const _Legend({
    required this.l10n,
    required this.color,
    required this.currentLabel,
  });

  final AppLocalizations l10n;
  final Color color;
  final String currentLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      children: [
        _swatch(context, color, currentLabel),
        _swatch(
          context,
          color.withValues(alpha: 0.3),
          l10n.comparisonPastLabel,
        ),
      ],
    );
  }

  Widget _swatch(BuildContext context, Color swatchColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: swatchColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

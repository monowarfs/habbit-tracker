import 'package:flutter/material.dart';
import 'package:habit_tracker/core/accessibility/semantic_labels.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:intl/intl.dart';

/// Accessible tabular fallback for [PeriodBarChart] — `fl_chart`'s
/// [BarChart] exposes no accessibility tree of its own beyond the single
/// summary label a caller passes as [PeriodBarChart.semanticsLabel], so
/// this renders the same [points] as a plain, screen-reader-navigable
/// table (`docs/superpowers/specs/07-accessibility/
/// 02-CHART-DATA-TABLE-FALLBACK-IMPLEMENTATION-PLAN.md`).
class ChartDataTable extends StatelessWidget {
  /// Creates a data table over the same [points] a [PeriodBarChart] would
  /// render for the same series.
  const ChartDataTable({
    required this.points,
    this.goalLabel,
    this.targetValue,
    super.key,
  });

  /// The bars' underlying data, in the same order the chart renders them.
  final List<BarChartPoint> points;

  /// Header text for the goal column, e.g. a module-specific "Daily
  /// Goal". Only shown when [targetValue] is non-null; falls back to a
  /// generic label when [targetValue] is set but this isn't.
  final String? goalLabel;

  /// The goal each row's value is compared against. `null` hides the
  /// goal column entirely — not every chart has a target line.
  final double? targetValue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(l10n.chartTableEmptyState),
      );
    }

    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final numberFormat = NumberFormat.decimalPattern(locale);
    final showGoalColumn = targetValue != null;

    Widget cell(String text, {bool header = false}) => Expanded(
      child: Semantics(
        header: header,
        child: Text(
          text,
          softWrap: true,
          style: header
              ? theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.bodyMedium,
        ),
      ),
    );

    return SemanticLabels.wrap(
      label: l10n.chartTableStatusHeader,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              cell(l10n.chartTablePeriodHeader, header: true),
              cell(l10n.chartTableValueHeader, header: true),
              if (showGoalColumn)
                cell(goalLabel ?? l10n.chartTableGoalHeader, header: true),
            ],
          ),
          const Divider(height: 1),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cell(point.label),
                  cell(numberFormat.format(point.value)),
                  if (showGoalColumn)
                    cell(
                      point.value >= targetValue!
                          ? l10n.recapDaysGoalMetLabel
                          : l10n.calendarStatusMissedLabel,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Wraps a [PeriodBarChart] with a toggle that swaps it for the
/// equivalent [ChartDataTable] — the accessible fallback a stats screen
/// wires in place of a bare [PeriodBarChart].
class ChartDataTableToggle extends StatefulWidget {
  /// Creates a chart that can be toggled to its [ChartDataTable]
  /// equivalent, over the same [points]/[color]/[targetLine] a bare
  /// [PeriodBarChart] would take.
  const ChartDataTableToggle({
    required this.points,
    required this.color,
    required this.chartSemanticsLabel,
    this.targetLine,
    this.goalLabel,
    super.key,
  });

  /// The bars' underlying data, in the same order the chart renders them.
  final List<BarChartPoint> points;

  /// The bar (and target-line) color, forwarded to [PeriodBarChart].
  final Color color;

  /// [PeriodBarChart.semanticsLabel] for the chart view.
  final String chartSemanticsLabel;

  /// An optional horizontal reference line (e.g. a goal), forwarded to
  /// both [PeriodBarChart] and [ChartDataTable].
  final double? targetLine;

  /// [ChartDataTable.goalLabel], forwarded through unchanged.
  final String? goalLabel;

  @override
  State<ChartDataTableToggle> createState() => _ChartDataTableToggleState();
}

class _ChartDataTableToggleState extends State<ChartDataTableToggle> {
  // Per-screen view preference, not a persisted setting — resets on
  // route pop, same as any other transient widget state.
  final ValueNotifier<bool> _showTable = ValueNotifier(false);

  @override
  void dispose() {
    _showTable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<bool>(
      valueListenable: _showTable,
      builder: (context, showTable, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Semantics(
            button: true,
            toggled: showTable,
            label: l10n.chartTableToggleLabel,
            excludeSemantics: true,
            child: IconButton(
              icon: Icon(showTable ? Icons.bar_chart : Icons.table_chart),
              tooltip: l10n.chartTableToggleLabel,
              onPressed: () => _showTable.value = !showTable,
            ),
          ),
          if (showTable)
            ChartDataTable(
              points: widget.points,
              goalLabel: widget.goalLabel,
              targetValue: widget.targetLine,
            )
          else
            PeriodBarChart(
              points: widget.points,
              color: widget.color,
              targetLine: widget.targetLine,
              semanticsLabel: widget.chartSemanticsLabel,
            ),
        ],
      ),
    );
  }
}

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

import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/heatmap_color_scheme.dart';
import 'package:habit_tracker/core/widgets/heatmap_tooltip.dart';
import 'package:intl/intl.dart';

/// A GitHub-contribution-style year grid for one module: weeks as
/// columns (padded to full Monday-start weeks so every column is a real
/// calendar week), the 7 weekdays as rows, horizontally scrollable — a
/// year is 52-53 columns wide (`08-analytics/01-adherence-heatmap-
/// design.md`, Task 1).
class HeatmapGrid extends StatelessWidget {
  /// Creates a year heatmap for [year], colored by [dayStatus].
  const HeatmapGrid({
    required this.dayStatus,
    required this.year,
    this.onDayTap,
    this.today,
    super.key,
  });

  /// This module's `dayStatus()` result — only entries within [year] are
  /// rendered as real cells.
  final Map<LocalDate, ModuleDayStatus> dayStatus;

  /// The calendar year to render.
  final int year;

  /// Called when a past-or-today, in-year cell is tapped.
  final void Function(LocalDate day)? onDayTap;

  /// Defaults to the real current date; overridable for tests.
  final LocalDate? today;

  static const _cellSize = 14.0;

  /// The Monday on/before Jan 1 and the Sunday on/after Dec 31 — grid
  /// bounds padded so every column is a full calendar week.
  ({LocalDate start, LocalDate end}) _gridBounds() {
    final firstOfYear = LocalDate(year, 1, 1);
    final lastOfYear = LocalDate(year, 12, 31);
    final leadingPad = firstOfYear.toDateTimeUtc().weekday - 1; // Mon=1..Sun=7
    final trailingPad = 7 - lastOfYear.toDateTimeUtc().weekday;
    return (
      start: firstOfYear.addDays(-leadingPad),
      end: lastOfYear.addDays(trailingPad),
    );
  }

  Widget _monthLabel(LocalDate weekStart) {
    // A week "belongs" to a month label only if that month actually
    // starts within it — avoids a label repeating on every column.
    for (var i = 0; i < 7; i++) {
      final day = weekStart.addDays(i);
      if (day.day == 1 && day.year == year) {
        return SizedBox(
          width: _cellSize,
          child: Text(
            DateFormat.MMM().format(day.toDateTimeUtc()),
            style: const TextStyle(fontSize: 10),
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        );
      }
    }
    return const SizedBox(width: _cellSize, height: 14);
  }

  String _semanticsLabel(
    AppLocalizations l10n,
    LocalDate day,
    ModuleDayStatus? status,
  ) {
    final date = day.toIso();
    if (status == null || status.kind == ModuleDayStatusKind.none) {
      return l10n.heatmapCellNoDataSemantics(date);
    }
    final value = '${status.value}';
    return switch (status.kind) {
      ModuleDayStatusKind.complete => l10n.heatmapCellCompleteSemantics(
        date,
        value,
      ),
      ModuleDayStatusKind.partial => l10n.heatmapCellPartialSemantics(
        date,
        value,
      ),
      ModuleDayStatusKind.missed => l10n.heatmapCellMissedSemantics(
        date,
        value,
      ),
      ModuleDayStatusKind.paused => l10n.heatmapCellPausedSemantics(date),
      ModuleDayStatusKind.none => l10n.heatmapCellNoDataSemantics(date),
    };
  }

  Widget _buildCell(
    BuildContext context,
    AppLocalizations l10n,
    LocalDate effectiveToday,
    LocalDate day,
  ) {
    // Padding days outside the requested year (leading/trailing week
    // fill) render as an invisible placeholder, never a "no data" cell —
    // they aren't part of this year's data at all.
    if (day.year != year) {
      return const SizedBox(width: _cellSize, height: _cellSize);
    }
    final status = dayStatus[day];
    final isFuture = day.compareTo(effectiveToday) > 0;
    final icon = HeatmapColorScheme.iconForStatus(
      status?.kind ?? ModuleDayStatusKind.none,
    );
    final cell = Semantics(
      label: _semanticsLabel(l10n, day, status),
      excludeSemantics: true,
      child: InkWell(
        onTap: isFuture ? null : () => onDayTap?.call(day),
        child: Opacity(
          opacity: isFuture ? 0.4 : 1,
          child: Container(
            width: _cellSize,
            height: _cellSize,
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: HeatmapColorScheme.colorForStatus(
                context,
                status?.kind ?? ModuleDayStatusKind.none,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: icon == null
                ? null
                : Icon(
                    icon,
                    size: 8,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
          ),
        ),
      ),
    );
    return Tooltip(
      message: heatmapTooltipMessage(l10n, day, status),
      triggerMode: TooltipTriggerMode.tap,
      child: cell,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveToday = today ?? LocalDate.fromDateTime(DateTime.now());
    final bounds = _gridBounds();
    final totalDays =
        bounds.end
            .toDateTimeUtc()
            .difference(bounds.start.toDateTimeUtc())
            .inDays +
        1;
    final weekCount = totalDays ~/ 7;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var week = 0; week < weekCount; week++)
            Column(
              children: [
                _monthLabel(bounds.start.addDays(week * 7)),
                for (var weekday = 0; weekday < 7; weekday++)
                  _buildCell(
                    context,
                    l10n,
                    effectiveToday,
                    bounds.start.addDays(week * 7 + weekday),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

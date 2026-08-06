import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// Pure, unit-testable: no `BuildContext`, no `Theme` lookup. `kind` gates
/// a fixed alpha band so `complete` always outranks `partial` regardless
/// of raw value (`docs/superpowers/specs/2026-07-21-01-per-habit-calendar-
/// heatmap-design.md`, "Weaknesses found in v1" #1) — a `partial` day
/// with a higher raw value than some `complete` day must never render
/// more "filled in."
double heatmapAlphaFor(ModuleDayStatus status, num maxValue) {
  switch (status.kind) {
    case ModuleDayStatusKind.none:
      return 0; // caller uses the neutral surface color, not this alpha
    case ModuleDayStatusKind.missed:
      return 1; // caller uses errorContainer, not this alpha
    case ModuleDayStatusKind.partial:
      return _bandedAlpha(status.value, maxValue, min: 0.15, max: 0.40);
    case ModuleDayStatusKind.complete:
      return _bandedAlpha(status.value, maxValue, min: 0.55, max: 0.95);
    case ModuleDayStatusKind.paused:
      return 0; // same as none — neutral surface color
  }
}

double _bandedAlpha(
  num value,
  num maxValue, {
  required double min,
  required double max,
}) {
  final ratio = maxValue <= 0 ? 1.0 : (value / maxValue).clamp(0.0, 1.0);
  return min + (max - min) * ratio;
}

/// A single-month heatmap calendar: each day cell is shaded by its
/// `ModuleDayStatus.value` within a fixed alpha band per `.kind`. Shared
/// across Water/Medicine/Prayer's history screens instead of each
/// hand-rolling its own month grid.
class HabitHeatmapCalendar extends StatelessWidget {
  /// Creates a heatmap for [month] (any day within the target month).
  const HabitHeatmapCalendar({
    required this.month,
    required this.dayStatus,
    required this.accentColor,
    required this.maxValue,
    required this.onDayTap,
    this.today,
    this.useSquareCells = false,
    this.tooltipForDay,
    super.key,
  });

  /// Any day within the month to render.
  final LocalDate month;

  /// The exact return shape of `HabitModule.dayStatus()`.
  final Map<LocalDate, ModuleDayStatus> dayStatus;

  /// The module's own themeable accent color.
  final Color accentColor;

  /// A stable, caller-supplied ceiling `status.value` is measured
  /// against — not a per-instance max — so paging between months never
  /// rescales what a color means (e.g. the resolved goal for Water, a
  /// constant for Prayer, the max scheduled dose count for Medicine).
  final num maxValue;

  /// Called when a day cell is tapped. Never called for a day after
  /// [today].
  final void Function(LocalDate day) onDayTap;

  /// Defaults to the real current date; overridable for tests.
  final LocalDate? today;

  /// When true, renders square cells (like GitHub's contribution chart)
  /// instead of circles.
  final bool useSquareCells;

  /// Optional callback to generate a tooltip message for a day cell.
  /// Return null to show no tooltip.
  final String Function(LocalDate day, ModuleDayStatus? status)? tooltipForDay;

  Color _colorFor(BuildContext context, ModuleDayStatus? status) {
    final colors = Theme.of(context).colorScheme;
    if (status == null || status.kind == ModuleDayStatusKind.none) {
      return colors.surfaceContainerHighest;
    }
    if (status.kind == ModuleDayStatusKind.missed) {
      // AppSemanticColors.missed (orange), not colors.errorContainer (red)
      // — red/green is the most common CVD failure mode and `complete`
      // cells are colored by the module's own (often warm) accentColor,
      // so "missed" must not default to red
      // (docs/superpowers/specs/07-accessibility/
      // 03-palette-audit-results.md). Alpha-blended like the bands below
      // to match this calendar's pale-fill visual style.
      final semantic = Theme.of(context).semanticColors;
      return Color.alphaBlend(
        semantic.missed.withValues(alpha: 0.3),
        colors.surface,
      );
    }
    final alpha = heatmapAlphaFor(status, maxValue);
    // alphaBlend against the theme's own surface, not translucent paint
    // over an arbitrary background — deterministic contrast in both
    // light and dark M3 palettes.
    return Color.alphaBlend(
      accentColor.withValues(alpha: alpha),
      colors.surface,
    );
  }

  /// A small non-color status glyph overlaid in the cell's corner — hue
  /// alone (module accent vs. the missed/partial bands) must never be the
  /// only way a status is legible (`03-palette-audit-results.md`).
  IconData? _iconFor(ModuleDayStatusKind kind) {
    return switch (kind) {
      ModuleDayStatusKind.complete => Icons.check,
      ModuleDayStatusKind.missed => Icons.close,
      ModuleDayStatusKind.partial => Icons.remove,
      ModuleDayStatusKind.paused => Icons.horizontal_rule,
      ModuleDayStatusKind.none => null,
    };
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
      // Distinct from `none`'s "no data" — a paused module day is a known
      // state, not an absence of data (matches the new `horizontal_rule`
      // icon this status also gets, above).
      ModuleDayStatusKind.paused => l10n.heatmapCellPausedSemantics(date),
      ModuleDayStatusKind.none => l10n.heatmapCellNoDataSemantics(date),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveToday = today ?? LocalDate.fromDateTime(DateTime.now());
    final firstOfMonth = LocalDate(month.year, month.month, 1);
    final daysInMonth = LocalDate(
      month.year,
      month.month + 1,
      1,
    ).addDays(-1).day;
    final leadingBlanks = firstOfMonth.toDateTimeUtc().weekday - 1; // Mon=0

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: leadingBlanks + daysInMonth,
      itemBuilder: (context, index) {
        if (index < leadingBlanks) return const SizedBox.shrink();
        final day = LocalDate(
          month.year,
          month.month,
          index - leadingBlanks + 1,
        );
        final status = dayStatus[day];
        final isFuture = day.compareTo(effectiveToday) > 0;
        final isToday = day.compareTo(effectiveToday) == 0;
        final tooltipMsg = tooltipForDay?.call(day, status);
        final cell = Semantics(
          label: _semanticsLabel(l10n, day, status),
          // The Text/Icon below are purely visual — this label already
          // fully describes the cell, so their own semantics (e.g. the
          // bare day-number "5") must not merge in and muddy it.
          excludeSemantics: true,
          child: InkWell(
            onTap: isFuture ? null : () => onDayTap(day),
            child: Opacity(
              opacity: isFuture ? 0.4 : 1,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    color: _colorFor(context, status),
                    shape: useSquareCells
                        ? BoxShape.rectangle
                        : BoxShape.circle,
                    borderRadius: useSquareCells
                        ? BorderRadius.circular(3)
                        : null,
                    border: isToday
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    // Fills the circle's full bounds — without this the
                    // Stack shrinks to wrap only the Text (its one
                    // non-positioned child), and the "corner" checkmark
                    // ends up overlapping the day number instead of
                    // sitting in the actual corner of the cell.
                    fit: StackFit.expand,
                    children: [
                      // `StackFit.expand` above forces this non-positioned
                      // child to fill the whole cell, so without an
                      // explicit `Center` the text paints from its own
                      // top-left origin instead of the cell's middle.
                      Center(
                        child: Text(
                          '${day.day}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      // A non-color cue per status kind — never rely on
                      // hue/alpha alone (colorblind users, low-contrast
                      // displays) — overlaid on, not replacing, the day
                      // number.
                      if (status != null && _iconFor(status.kind) != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Icon(
                            _iconFor(status.kind),
                            size: 8,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        if (tooltipMsg == null) return cell;
        return Tooltip(
          message: tooltipMsg,
          triggerMode: TooltipTriggerMode.tap,
          child: cell,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';

/// Fixed, theme-aware color/icon per [ModuleDayStatusKind] for
/// `HeatmapGrid` (`docs/superpowers/specs/08-analytics/
/// 01-adherence-heatmap-design.md`). Unlike `HabitHeatmapCalendar`'s
/// per-module accent-blended bands, this screen puts every module's year
/// side by side, so "complete" must read as the same color everywhere —
/// mirrors `GlobalMonthCalendar._colorFor`'s palette rather than
/// inventing a new one (colorblind-safe per `docs/superpowers/specs/
/// 07-accessibility/03-palette-audit-results.md`: never red/green alone).
class HeatmapColorScheme {
  const HeatmapColorScheme._();

  /// The cell fill color for [kind].
  static Color colorForStatus(BuildContext context, ModuleDayStatusKind kind) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).semanticColors;
    return switch (kind) {
      ModuleDayStatusKind.complete => semantic.success,
      ModuleDayStatusKind.partial => colors.tertiary,
      ModuleDayStatusKind.missed => semantic.missed,
      ModuleDayStatusKind.paused => colors.surfaceContainerHighest,
      ModuleDayStatusKind.none => colors.surfaceContainerHighest,
    };
  }

  /// A small non-color glyph for [kind] — same icon set as
  /// `HabitHeatmapCalendar`/`GlobalMonthCalendar` — hue alone must never
  /// be the only way a cell's status is legible. `null` for `none`
  /// (nothing to mark).
  static IconData? iconForStatus(ModuleDayStatusKind kind) {
    return switch (kind) {
      ModuleDayStatusKind.complete => Icons.check,
      ModuleDayStatusKind.missed => Icons.close,
      ModuleDayStatusKind.partial => Icons.remove,
      ModuleDayStatusKind.paused => Icons.horizontal_rule,
      ModuleDayStatusKind.none => null,
    };
  }
}

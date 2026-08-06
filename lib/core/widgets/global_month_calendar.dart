import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// Combines every module's [ModuleDayStatusKind] for one day into a
/// single coloring decision for [GlobalMonthCalendar] (FR-C-16). `none`
/// entries are ignored unless every entry is `none`.
ModuleDayStatusKind combinedDayStatusKind(List<ModuleDayStatusKind> kinds) {
  final resolved = kinds.where((k) => k != ModuleDayStatusKind.none).toList();
  if (resolved.isEmpty) return ModuleDayStatusKind.none;
  if (resolved.every((k) => k == ModuleDayStatusKind.complete)) {
    return ModuleDayStatusKind.complete;
  }
  if (resolved.every((k) => k == ModuleDayStatusKind.missed)) {
    return ModuleDayStatusKind.missed;
  }
  return ModuleDayStatusKind.partial;
}

/// A month grid coloring each day by every enabled module's combined
/// status (FR-C-16). `statusesByModule` maps a module id to that
/// module's `dayStatus()` result covering (at least) the target month.
class GlobalMonthCalendar extends StatelessWidget {
  /// Creates a month calendar for `month` (any day within the target
  /// month), colored from `statusesByModule`, calling `onDayTap` when a
  /// day cell is tapped.
  const GlobalMonthCalendar({
    required this.month,
    required this.statusesByModule,
    required this.onDayTap,
    super.key,
  });

  /// Any day within the month to render.
  final LocalDate month;

  /// Module id -> that module's day-status map.
  final Map<String, Map<LocalDate, ModuleDayStatus>> statusesByModule;

  /// Called with the tapped day.
  final void Function(LocalDate day) onDayTap;

  int _daysInMonth() =>
      LocalDate(month.year, month.month + 1, 1).addDays(-1).day;

  Color _colorFor(BuildContext context, ModuleDayStatusKind kind) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).semanticColors;
    switch (kind) {
      case ModuleDayStatusKind.complete:
        return semantic.success;
      case ModuleDayStatusKind.partial:
        return colors.tertiary;
      case ModuleDayStatusKind.missed:
        // AppSemanticColors.missed (orange), not colors.error (red) — see
        // docs/superpowers/specs/07-accessibility/
        // 03-palette-audit-results.md: red vs. green (`complete`) is the
        // single most common deuteranopia/protanopia failure mode.
        return semantic.missed;
      case ModuleDayStatusKind.paused:
        return colors.surfaceContainerHighest;
      case ModuleDayStatusKind.none:
        return colors.surfaceContainerHighest;
    }
  }

  /// A small non-color status glyph — hue alone must never be the only
  /// way a day's combined status is legible.
  ///
  /// `paused` returns null: [combinedDayStatusKind] never actually
  /// produces `paused` (a lone or all-`paused` day falls into its
  /// `partial` fallback branch, since `paused` isn't one of the two
  /// `every()` checks) — rendering an icon for a value this method can't
  /// return would be dead code that never draws, so the case is listed
  /// explicitly (for switch exhaustiveness) but deliberately maps to
  /// nothing rather than the unreachable `Icons.horizontal_rule`
  /// `HabitHeatmapCalendar` uses for the same status
  /// (`03-palette-audit-results.md`).
  IconData? _iconFor(ModuleDayStatusKind kind) {
    return switch (kind) {
      ModuleDayStatusKind.complete => Icons.check,
      ModuleDayStatusKind.missed => Icons.close,
      ModuleDayStatusKind.partial => Icons.remove,
      ModuleDayStatusKind.paused => null,
      ModuleDayStatusKind.none => null,
    };
  }

  /// Screen-reader label for [kind], reusing the same ARB keys as the
  /// icon glyphs (`03-palette-audit-results.md`). `null` for `none` and
  /// `paused` — see [_iconFor]'s doc comment for why `paused` can't
  /// actually reach this widget via [combinedDayStatusKind].
  String? _statusLabel(AppLocalizations l10n, ModuleDayStatusKind kind) {
    return switch (kind) {
      ModuleDayStatusKind.complete => l10n.calendarStatusDoneLabel,
      ModuleDayStatusKind.missed => l10n.calendarStatusMissedLabel,
      ModuleDayStatusKind.partial => l10n.calendarStatusPartialLabel,
      ModuleDayStatusKind.paused => null,
      ModuleDayStatusKind.none => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayCount = _daysInMonth();
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: dayCount,
      itemBuilder: (context, index) {
        final day = LocalDate(month.year, month.month, index + 1);
        final kinds = [
          for (final statuses in statusesByModule.values)
            statuses[day]?.kind ?? ModuleDayStatusKind.none,
        ];
        final combined = combinedDayStatusKind(kinds);
        final icon = _iconFor(combined);
        final statusLabel = _statusLabel(l10n, combined);
        final cell = Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _colorFor(context, combined),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              Center(child: Text('${day.day}')),
              if (icon != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(
                    icon,
                    size: 10,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
            ],
          ),
        );
        final tappableCell = InkWell(onTap: () => onDayTap(day), child: cell);
        if (statusLabel == null) return tappableCell;
        // Semantics wraps InkWell (not the reverse) to match
        // HabitHeatmapCalendar's convention for the same job.
        return Semantics(
          label: '${day.toIso()}, $statusLabel',
          excludeSemantics: true,
          child: tappableCell,
        );
      },
    );
  }
}

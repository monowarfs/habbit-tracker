import 'package:flutter/material.dart';
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
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    switch (kind) {
      case ModuleDayStatusKind.complete:
        return semantic.success;
      case ModuleDayStatusKind.partial:
        return colors.tertiary;
      case ModuleDayStatusKind.missed:
        return colors.error;
      case ModuleDayStatusKind.none:
        return colors.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        return InkWell(
          onTap: () => onDayTap(day),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _colorFor(context, combined),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text('${day.day}'),
          ),
        );
      },
    );
  }
}

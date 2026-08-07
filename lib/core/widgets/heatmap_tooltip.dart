import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:intl/intl.dart';

/// Formats a `HeatmapGrid` cell's tap tooltip, e.g. `"25 Jul 2026 —
/// Completed"` (`08-analytics/01-adherence-heatmap-design.md`, Task 3).
/// Pure/testable — no `BuildContext`; the cell itself renders this via a
/// plain `Tooltip` widget (`triggerMode: tap`), the same pattern
/// `HabitHeatmapCalendar` already uses, rather than a bespoke tooltip
/// widget.
String heatmapTooltipMessage(
  AppLocalizations l10n,
  LocalDate day,
  ModuleDayStatus? status,
) {
  final dateLabel = DateFormat('d MMM yyyy').format(day.toDateTimeUtc());
  final statusLabel = switch (status?.kind) {
    ModuleDayStatusKind.complete => l10n.heatmapTooltipDone,
    ModuleDayStatusKind.partial => l10n.heatmapTooltipPartial,
    ModuleDayStatusKind.missed => l10n.heatmapTooltipMissed,
    ModuleDayStatusKind.paused => l10n.calendarStatusSkippedLabel,
    ModuleDayStatusKind.none || null => l10n.heatmapTooltipNone,
  };
  return '$dateLabel — $statusLabel';
}

# Per-Habit Calendar / Heatmap View

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

Feature Atlas gap-analysis flags "per-habit calendar / heatmap view" as a
Must Have, inspired by Loop Habit Tracker's per-habit intensity-shaded
calendar. Checking what already exists complicates a naive "build it from
scratch" read:

- **Water** has `WaterHistoryCalendar`
  (`lib/features/water/presentation/widgets/water_history_calendar.dart`),
  a single-month `GridView` colored by whether that day's goal was met
  (`success` green / `ModuleAccents.water` at 20% alpha / neutral),
  embedded in `WaterStatsScreen`'s History tab
  (`lib/features/water/presentation/screens/water_stats_screen.dart:196`).
  It's a real widget, but it's Water-specific — its `goalMetByDay` param
  is a `Map<LocalDate, bool>`, computed inline in the screen from
  `dailyTotals` + `ResolveGoalForDateUseCase`.
- **Prayer** has `PrayerHistoryScreen`
  (`lib/features/prayer/presentation/screens/prayer_history_screen.dart`),
  but the month grid is hand-built directly in the screen's `build()`
  (lines 78-116) — never extracted into a widget, coloring by a 3-way
  `allPrayed`/`anyMissed`/neutral check computed inline.
- **Medicine** has no calendar/history screen at all.
  `MedicineStatsScreen` (`lib/features/medicine/presentation/screens/
  medicine_stats_screen.dart`) is a 7-day adherence bar chart
  (`PeriodBarChart`) plus a missed-doses list — no month view, no
  drill-down by day.
- Run 15 added `GlobalMonthCalendar`
  (`lib/core/widgets/global_month_calendar.dart`), which *is* shared and
  reusable — but it's cross-module by design (one cell = every enabled
  module's status combined via `combinedDayStatusKind`), lives behind the
  dashboard's bottom sheet (not a route), and colors by a flat 4-way
  `ModuleDayStatusKind` (complete/partial/missed/none) with no intensity
  gradient.

**So the actual gap is narrower than "no calendar exists":** two of three
modules already show a per-day-colored month grid; the real gaps are (a)
none of them is a true heatmap — all three color schemes are flat/discrete
(2-4 fixed colors), not intensity-graded by how much was done, which is
the specific thing that makes Loop's view a "heatmap" rather than a
checklist calendar; (b) there is no shared widget for this in
`lib/core/widgets/` despite `period_bar_chart.dart` establishing that
precedent for charts — Water and Prayer each hand-rolled their own month
grid, and Medicine's is missing outright.

The good news: `HabitModule.dayStatus(DateRange range)` (added Run 15,
`lib/core/modules/habit_module.dart:222`) already returns
`Map<LocalDate, ModuleDayStatus>` per module, where `ModuleDayStatus`
carries both `kind` (complete/partial/missed/none) *and* `value` (the raw
number in the module's own natural unit — ml, doses, prayers). That's
exactly the day-to-intensity shape a heatmap needs, and all three modules
already implement it correctly (`water_module.dart:187`,
`medicine_module.dart:212`, `prayer_module.dart:208`) for Run 15's
dashboard/Reports work. This is a presentation-layer consolidation plus
an intensity-coloring upgrade, not new domain or data work.

## Design

### New shared widget: `lib/core/widgets/habit_heatmap_calendar.dart`

```dart
class HabitHeatmapCalendar extends StatelessWidget {
  const HabitHeatmapCalendar({
    required this.month,          // any LocalDate within the month to render
    required this.dayStatus,      // Map<LocalDate, ModuleDayStatus> — the exact
                                   // return type of HabitModule.dayStatus()
    required this.accentColor,    // ModuleAccents.water/.medicine/.prayer
    required this.onDayTap,
    this.maxValue,                // optional override; see below
    super.key,
  });
}
```

Layout reuses the month-grid mechanics `WaterHistoryCalendar` already has
(leading-blank cells via `firstOfMonth.toDateTimeUtc().weekday`, 7-column
`GridView`, `InkWell` day cells) — a single month at a time with prev/next
chevrons owned by the calling screen (each screen already has this
chevron pattern; the widget itself takes only `month`, matching
`GlobalMonthCalendar`'s existing convention). This is deliberately *not*
a multi-month GitHub-style scrolling grid — that's a materially bigger
widget for a Complexity-S ticket, and a single navigable month is what
Loop's own per-habit calendar and this app's two existing
implementations already settled on.

**Coloring (the actual heatmap part, new relative to every existing
calendar in this codebase):**

```dart
Color _colorFor(BuildContext context, LocalDate day) {
  final status = dayStatus[day];
  final colors = Theme.of(context).colorScheme;
  if (status == null || status.kind == ModuleDayStatusKind.none) {
    return colors.surfaceContainerHighest;
  }
  if (status.kind == ModuleDayStatusKind.missed) {
    return colors.errorContainer; // matches PrayerHistoryScreen's existing choice
  }
  final effectiveMax = maxValue ??
      dayStatus.values
          .where((s) => s.kind != ModuleDayStatusKind.none)
          .map((s) => s.value)
          .fold<num>(1, (a, b) => a > b ? a : b);
  final ratio = effectiveMax <= 0 ? 1.0 : (status.value / effectiveMax).clamp(0.0, 1.0);
  return accentColor.withValues(alpha: 0.25 + 0.65 * ratio);
}
```

`complete` and `partial` share one continuous alpha ramp on the module's
own accent color instead of two hard-coded colors — a light-to-dark
gradient by how much was actually logged that day, which is the one
thing none of the three existing calendars do today (Water: binary;
Prayer: binary; GlobalMonthCalendar: flat 4-color, and intentionally
cross-module so it can't use a single module's natural-unit value
anyway). `effectiveMax` defaults to the max value seen in the same
`dayStatus` map (guards div-by-zero and needs no cross-module scale
config — each module's `value` is already documented as "the module's
own natural unit," so a per-call, per-instance max is the right default);
callers may pass `maxValue` explicitly (e.g. Water could pass the day's
resolved goal instead of the month's observed max, for a goal-relative
gradient) but the default needs no extra wiring to ship.

### Per-module integration

All three follow the same shape: fetch `dayStatus()` from the already-
registered module (found via `habitModulesProvider`, the exact pattern
`DashboardScreen`'s `_GlobalCalendarSheetState._load()` already uses at
`lib/features/dashboard/presentation/screens/dashboard_screen.dart:88`),
store it in local state, hand it to `HabitHeatmapCalendar`. No new
provider plumbing needed.

- **Water** (`water_stats_screen.dart`, History tab): delete the local
  `goalMetByDay` computation (currently built from `dailyTotals` +
  `ResolveGoalForDateUseCase` inline) and the `WaterHistoryCalendar`
  widget file; call `waterModule.dayStatus(range)` instead — it already
  encodes identical goal-met logic — and render `HabitHeatmapCalendar`
  with `accentColor: ModuleAccents.water`. Net deletion: one widget file,
  one inline computation.
- **Prayer** (`prayer_history_screen.dart`): replace the hand-rolled
  `GridView.builder` block (lines 78-116) with `HabitHeatmapCalendar`
  fed by `prayerModule.dayStatus(range)` instead of the screen's own
  `byDay` grouping + `allPrayed`/`anyMissed` check (again, already
  duplicated in `prayer_module.dart:208`'s `dayStatus()`). The existing
  `_showDayDetail` bottom sheet stays as `onDayTap`'s handler, still
  looking up that day's records from the already-fetched
  `prayerRecordsInRangeProvider` data for the detail list (heatmap cells
  show status, not per-prayer breakdown). `accentColor: ModuleAccents.prayer`.
- **Medicine** (`medicine_stats_screen.dart`): net-new surface — add a
  second tab ("History", matching Water's Stats/History `TabBar` split)
  showing `HabitHeatmapCalendar` fed by `medicineModule.dayStatus(range)`,
  `accentColor: ModuleAccents.medicine`, `onDayTap` opening a simple
  bottom sheet listing that day's doses (same shape as Prayer's
  `_showDayDetail`, sourced from the already-available
  `medicineDosesInRangeProvider`). This is the only screen restructuring
  in scope; the other two are drop-in replacements.

### Explicitly out of scope / unchanged

- `GlobalMonthCalendar` and the dashboard's bottom-sheet cross-module
  view are untouched — different data shape (combined multi-module kind,
  no intensity), different call site, still the right tool for "how did
  today go across everything."
- No new l10n strings — none of the three screens' existing text changes;
  the widget itself renders only day numbers.
- No DB/schema/domain changes — `ModuleDayStatus`/`dayStatus()` already
  exist and are reused as-is.
- Multi-month scrolling / a true GitHub-contribution-grid layout: not
  attempted here (Complexity S). If a future run wants that, it would
  extend this widget rather than replace it — `dayStatus` already accepts
  an arbitrary `DateRange`, so widening the widget from one month to N
  months later is additive, not a rewrite.

### Testing

New `test/core/widgets/habit_heatmap_calendar_test.dart` (same location
convention as the existing `global_month_calendar_test.dart`): verifies
`none`/`missed` cells use the fixed neutral/error colors, and that two
`complete` days with different `value`s render different alpha on the
same `accentColor` (the actual heatmap behavior under test). Each
module's existing screen/widget tests get updated to assert
`HabitHeatmapCalendar` appears instead of the widget/inline grid it
replaces, rather than new test files.

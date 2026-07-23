# Per-Habit Calendar / Heatmap View

**Date:** 2026-07-21
**Status:** Draft v2 — pending review (revised after self-critique, see below)

## Revision note

This is a revision of the original draft. Section "Weaknesses found in v1"
documents what was wrong; the "Design" section below already reflects the
fixes — it is not a diff, it's the corrected plan. Nothing has been
implemented yet.

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

## Weaknesses found in v1 (self-review before implementation)

1. **Partial-day intensity could visually outrank a complete day.** v1's
   color ramp computed `ratio = value / effectiveMax` across *all* cells
   in the visible month regardless of `kind`, then applied one continuous
   alpha curve. Concretely: a `partial` Medicine day with 3/4 doses taken
   (`value: 3`) would render *more* filled-in than a `complete` day with
   2/2 doses taken (`value: 2`), because raw value, not adherence, drove
   the ratio. That's backwards — a heatmap whose "more intense" cells
   don't reliably mean "did better" is actively misleading, worse than
   the flat coloring it replaces. **Fix:** `kind` now gates a fixed alpha
   *band* (`missed`/`none` unchanged; `partial` restricted to `0.15–0.40`;
   `complete` restricted to `0.55–0.95`) — value only varies intensity
   *within* the band its `kind` already earned. Complete always outranks
   partial, by construction, with zero new domain data needed.

2. **Cross-month color instability.** v1 defaulted `effectiveMax` to the
   max `value` observed in whatever month happens to be on screen. Paging
   from a busy month to a quiet one silently rescales every color's
   meaning — the same 1500 ml day could read as "pretty full" in one
   month and "nearly empty" in the next, defeating the point of a
   heatmap (colors should mean the same thing over time). **Fix:** each
   caller now passes an explicit, stable `maxValue` instead of relying on
   the per-instance-max default: Water passes the resolved daily goal
   (already computed via `ResolveGoalForDateUseCase` for the visible
   month), Prayer passes the constant `5` (five daily prayers is a fixed,
   known ceiling — no computation needed), Medicine passes the max
   *scheduled* dose count across its active schedules for the visible
   range (computed once per screen load, not per cell). `maxValue` is
   still a widget parameter — the per-instance-max fallback is removed
   entirely rather than kept as a silent default, so a future caller
   can't accidentally reintroduce weakness #2 by omitting it.

3. **No non-color cue — an accessibility gap.** Alpha-graded single-hue
   cells are hard to distinguish for colorblind users and add nothing for
   screen-reader users; v1 had no `Semantics` label and no shape/icon
   fallback. **Fix:** each day cell gets a `Semantics` label (e.g. "July
   5, complete, 2200 milliliters") and `complete` cells additionally get
   a small check-mark glyph overlay (not just a fill color) so status is
   never color-only.

4. **Dark-theme contrast unverified.** `accentColor.withValues(alpha:
   ...)` painted directly over `colorScheme.surfaceContainerHighest`
   wasn't checked against the dark M3 palette, where that surface role is
   already fairly saturated — a 0.25-alpha accent could be nearly
   invisible. **Fix:** color computation now uses `Color.alphaBlend`
   against `colorScheme.surface` explicitly (not translucent paint over
   an arbitrary background), which is deterministic in both themes;
   Testing section adds an explicit dark-theme check.

5. **Three independent hand-rolled data fetches.** v1 had each of the
   three screens independently call `module.dayStatus(range)` and manage
   its own loading/error local state — exactly the kind of per-screen
   duplication this ticket is otherwise consolidating away, and
   inconsistent with this codebase's Riverpod-codegen convention for
   async data (per `CLAUDE.md`). **Fix:** add one shared
   `@riverpod` family provider (`moduleDayStatusProvider(moduleId,
   range)` in `lib/core/providers/module_day_status_provider.dart`) that
   all three screens consume via `ref.watch`, giving consistent
   loading/error UI and provider-level caching across month navigation
   for free.

6. **"No new l10n strings" was incorrect.** Medicine gains a second
   ("History") tab, which needs a label. **Fix:** confirmed
   `WaterStatsScreen`'s existing Stats/History tab labels already come
   from generic, already-localized strings (`l10n.statsTabLabel` /
   `l10n.historyTabLabel` in `lib/core/l10n/app_en.arb` — not
   Water-specific keys); Medicine's new tab reuses the same two keys, so
   the "no new l10n strings" claim is corrected to "no *new* l10n
   strings — reuses Water's existing generic tab labels," not literally
   zero-touch on l10n review.

7. **Today/future-date handling unspecified.** Neither existing
   calendar's today-highlight/future-date-disabled behavior was carried
   forward explicitly. **Fix:** ported as an explicit widget behavior
   (below), not left implicit.

8. **Orphaned test file risk.** Deleting `WaterHistoryCalendar` without
   also deleting its dedicated widget test
   (`test/features/water/presentation/widgets/water_history_calendar_test.dart`,
   if it exists) would leave a compile failure. **Fix:** explicit step
   added to the Testing section.

9. **Testability of the color function.** v1's `_colorFor` took a
   `BuildContext`, forcing any test of the ramp logic through a full
   widget pump. **Fix:** the banding/ratio math is extracted into a pure,
   `BuildContext`-free function, matching this codebase's established
   preference for pure/unit-testable logic (e.g. `notification_planner
   .dart`).

## Design

### New shared widget: `lib/core/widgets/habit_heatmap_calendar.dart`

```dart
class HabitHeatmapCalendar extends StatelessWidget {
  const HabitHeatmapCalendar({
    required this.month,          // any LocalDate within the month to render
    required this.dayStatus,      // Map<LocalDate, ModuleDayStatus> — the exact
                                   // return type of HabitModule.dayStatus()
    required this.accentColor,    // ModuleAccents.water/.medicine/.prayer
    required this.maxValue,       // stable, caller-supplied ceiling — see
                                   // "Cross-month color instability" fix below.
                                   // No per-instance-max fallback.
    required this.onDayTap,
    this.today,                   // defaults to clock.now()'s LocalDate; overridable for tests
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

**Today / future dates:** both `WaterHistoryCalendar` and
`PrayerHistoryScreen`'s grid outline the current day and disable taps on
future dates today — carried forward explicitly: the cell for
`today` gets a `colorScheme.primary`-width-2 border regardless of fill
color, and `onDayTap` is not wired for any `day.isAfter(today)` cell
(rendered at reduced opacity, no `InkWell`).

**Coloring — pure function, no `BuildContext`:**

```dart
/// Pure, unit-testable: no BuildContext, no Theme lookup.
/// `kind` gates a fixed alpha band so `complete` always outranks
/// `partial` regardless of raw value — see "Weaknesses found in v1" #1.
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
  }
}

double _bandedAlpha(num value, num maxValue, {required double min, required double max}) {
  final ratio = maxValue <= 0 ? 1.0 : (value / maxValue).clamp(0.0, 1.0);
  return min + (max - min) * ratio;
}

Color _colorFor(BuildContext context, LocalDate day) {
  final status = dayStatus[day];
  final colors = Theme.of(context).colorScheme;
  if (status == null || status.kind == ModuleDayStatusKind.none) {
    return colors.surfaceContainerHighest;
  }
  if (status.kind == ModuleDayStatusKind.missed) {
    return colors.errorContainer; // matches PrayerHistoryScreen's existing choice
  }
  final alpha = heatmapAlphaFor(status, maxValue);
  // alphaBlend against the theme's own surface, not a translucent paint —
  // deterministic contrast in both light and dark M3 palettes (v1's
  // `.withValues(alpha:)` over an arbitrary background was unverified in
  // dark mode; see "Weaknesses found in v1" #4).
  return Color.alphaBlend(
    accentColor.withValues(alpha: alpha),
    colors.surface,
  );
}
```

`complete` and `partial` each get their own continuous alpha ramp on the
module's own accent color — light-to-dark *within* the band their `kind`
already earned — which is the one thing none of the three existing
calendars do today (Water: binary; Prayer: binary; `GlobalMonthCalendar`:
flat 4-color, and intentionally cross-module so it can't use a single
module's natural-unit value anyway). `maxValue` is a required, stable,
per-caller value (goal / constant / scheduled-count — see per-module
integration below), not a derived per-instance max, so paging between
months never rescales what a color means.

**Accessibility:** each day cell wraps in `Semantics(label: '<date>,
<kind description>, <value> <unit>')` (e.g. "July 5, complete, 2200
milliliters"); `complete` cells additionally render a small check-mark
`Icon` overlay in the cell's corner so status is legible without relying
on color/alpha alone (colorblind users, low-contrast displays).

### Shared data provider: `lib/core/providers/module_day_status_provider.dart`

```dart
@riverpod
Future<Map<LocalDate, ModuleDayStatus>> moduleDayStatus(
  Ref ref,
  String moduleId,
  DateRange range,
) async {
  final modules = await ref.watch(habitModulesProvider.future);
  final module = modules.firstWhere((m) => m.id == moduleId);
  return module.dayStatus(range);
}
```

Replaces v1's plan of three independent hand-rolled fetches (see
"Weaknesses found in v1" #5) with one family provider all three screens
`ref.watch`, giving consistent loading/error UI and Riverpod's normal
caching across month-navigation rebuilds, instead of three separately
maintained local-state fetch implementations.

### Per-module integration

- **Water** (`water_stats_screen.dart`, History tab): delete the local
  `goalMetByDay` computation and the `WaterHistoryCalendar` widget file;
  `ref.watch(moduleDayStatusProvider('water', range))`, render
  `HabitHeatmapCalendar` with `accentColor: ModuleAccents.water`,
  `maxValue:` the month's resolved goal (via the existing
  `ResolveGoalForDateUseCase` — if the goal changed mid-month, use the
  goal in effect on the *last* day of the visible range, so a single
  stable number governs the whole grid). Net deletion: one widget file,
  one inline computation.
- **Prayer** (`prayer_history_screen.dart`): replace the hand-rolled
  `GridView.builder` block (lines 78-116) with `HabitHeatmapCalendar`,
  `ref.watch(moduleDayStatusProvider('prayer', range))`, `accentColor:
  ModuleAccents.prayer`, `maxValue: 5` (constant — five daily prayers).
  The existing `_showDayDetail` bottom sheet stays as `onDayTap`'s
  handler, still looking up that day's records from the already-fetched
  `prayerRecordsInRangeProvider` data for the detail list (heatmap cells
  show status, not per-prayer breakdown).
- **Medicine** (`medicine_stats_screen.dart`): net-new surface — add a
  second tab (label: reuses `l10n.historyTabLabel`, matching Water's
  existing Stats/History `TabBar` split — see "Weaknesses found in v1"
  #6) showing `HabitHeatmapCalendar`,
  `ref.watch(moduleDayStatusProvider('medicine', range))`,
  `accentColor: ModuleAccents.medicine`, `maxValue:` the max scheduled
  dose count across active schedules for the visible range (computed
  once per screen load from the already-available schedule list, not
  per cell — a fixed, screen-lifetime constant, not a per-month
  recompute). `onDayTap` opens a bottom sheet listing that day's doses
  (same shape as Prayer's `_showDayDetail`, sourced from the already-
  available `medicineDosesInRangeProvider`). This is the only screen
  restructuring in scope; the other two are drop-in replacements.

### Explicitly out of scope / unchanged

- `GlobalMonthCalendar` and the dashboard's bottom-sheet cross-module
  view are untouched — different data shape (combined multi-module kind,
  no intensity), different call site, still the right tool for "how did
  today go across everything."
- No DB/schema/domain changes — `ModuleDayStatus`/`dayStatus()` already
  exist and are reused as-is.
- Multi-month scrolling / a true GitHub-contribution-grid layout: not
  attempted here (Complexity S). If a future run wants that, it would
  extend this widget rather than replace it — `dayStatus` already accepts
  an arbitrary `DateRange`, so widening the widget from one month to N
  months later is additive, not a rewrite.

### Testing

- New `test/core/widgets/habit_heatmap_calendar_test.dart` (same
  location convention as the existing `global_month_calendar_test.dart`):
  - Pure-function tests on `heatmapAlphaFor`/`_bandedAlpha` (no widget
    pump needed): `none`/`missed` return their sentinel values; a
    `partial` day's alpha is always `< 0.40` and a `complete` day's is
    always `>= 0.55` regardless of `value` (the actual bug fixed in
    "Weaknesses found in v1" #1 — assert this holds even when the
    partial day's `value` exceeds the complete day's `value`).
  - Widget test: `today`'s cell renders the expected border; a cell for
    a date after `today` is not wired to `onDayTap`.
  - Widget test, run under both `ThemeMode.light` and `ThemeMode.dark`
    (`MaterialApp(theme:, darkTheme:, themeMode:)`): the blended color
    for a `complete` cell is measurably different from
    `surfaceContainerHighest` in both themes (regression test for
    "Weaknesses found in v1" #4).
  - `Semantics` label present and correctly formatted for a sample cell.
- Each module's existing screen/widget tests get updated to assert
  `HabitHeatmapCalendar` appears instead of the widget/inline grid it
  replaces, rather than new test files.
- Delete `test/features/water/presentation/widgets/
  water_history_calendar_test.dart` if it exists (grep for it before
  removing `WaterHistoryCalendar` — see "Weaknesses found in v1" #8) so
  no test references a deleted widget.

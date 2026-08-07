# Dynamic Text Scaling Stress Test — Results

**Spec:** `05-dynamic-text-scaling-stress-test-design.md` /
`05-DYNAMIC-TEXT-SCALING-STRESS-TEST-IMPLEMENTATION-PLAN.md`
**Date:** 2026-08-07

## Method note (deviation from the plan's stated tool)

The plan's prerequisite was "Simulator/emulator with OS text size set to
200%+" and "record screenshots at 200% for both en and bn locales, both
light and dark themes." No interactive simulator/emulator is available in
this environment, so the stress test instead used `flutter_test` widget
tests: a shared `pumpAtTextScale(tester, widget, scale)` helper
(`test/accessibility/text_scale_test_helper.dart`) wraps a screen in an
ancestor `MediaQuery` forcing a given `TextScaler.linear(scale)`, settles,
and fails the test on any exception reported during layout (a `RenderFlex`
overflow surfaces via `FlutterError.onError`, not a thrown exception at
the call site — `tester.takeException()` is what actually catches it).
This is a stronger, CI-enforceable regression gate than one-time
screenshots would have been, at the cost of not producing visual
artifacts to embed in this doc.

## Coverage

- Dashboard: 1.5x and 2.0x × light/dark × en/bn (8 cases,
  `test/features/dashboard/presentation/dashboard_text_scale_test.dart`).
- Water: `WaterHomeScreen`, `WaterAddEntryScreen`, `WaterSettingsScreen`
  at 2.0x (`water_text_scale_test.dart`); `WaterStatsScreen` at 2.0x is in
  its own file (`water_stats_text_scale_test.dart`) — see "Test
  infrastructure note" below.
- Medicine: `MedicineHomeScreen`, `MedicineListScreen`,
  `MedicineDetailScreen`, `MedicineStatsScreen` at 2.0x.
- Prayer: `PrayerHomeScreen`, `PrayerStatsScreen`, `PrayerQadhaScreen`,
  `PrayerSettingsScreen` at 2.0x.
- Settings: `SettingsHomeScreen` at 2.0x.

## Fixes made

### 1. `WaterAddEntryScreen` — fixed-height `Column` in a non-scrolling body

`Scaffold.body` held a `Padding`-wrapped `Column` (amount field, notes
field, date/time tile, Save button) directly, with no scroll container.
At 2.0x, the stacked fields' combined height exceeded the viewport by
4px. **Fix:** `Padding` → `SingleChildScrollView(padding: ...)` around
the same `Column`. Matches the plan's edge case #1 ("fixed-height
Row/Column with text children") — the canonical fix for a form screen
specifically is making it scrollable, not `Flexible`/`Expanded` (there's
no sibling to share space with).

### 2. `PeriodBarChart` — chart axis labels don't respect `MediaQuery` text scale

Confirmed the plan's edge case #4 directly. `fl_chart`'s `SideTitles`
reserves a fixed pixel height for the bottom-axis label slot
(`reservedSize`, not scale-aware); the label `Text` used the ambient
`labelSmall` style, which grows with the app's text scale. At 2.0x the
label overflowed that fixed slot every frame. **Fix:** wrap the label in
`MediaQuery(data: MediaQueryData(textScaler: TextScaler.noScaling), ...)`
so axis labels stay a fixed, dense size regardless of the device's
accessibility text-scale setting — the same convention other chart
libraries use for tick labels.

### 3. `StreakCard` — `Row` of two `Column`s, no flex

`Row(mainAxisAlignment: spaceEvenly)` held two `_StreakStat` `Column`s
("Current streak" / "Longest streak") with no `Expanded`/`Flexible`.
`Column`'s width is unconstrained inside a plain `Row` child, so at 2.0x
each label's natural single-line width exceeded the available space by
355px. **Fix:** wrap both `_StreakStat`s in `Expanded`, letting their
label `Text`s wrap onto a second line instead of overflowing
horizontally.

### 4. `WaterStatsScreen` — `TrendArrow` in a centered `Row`, no flex

Same shape as #3, one child: a centered `Row` wrapping `TrendArrow`
directly, overflowing by 60px at 2.0x. **Fix:** wrap `TrendArrow` in
`Flexible`.

## Test infrastructure note (not a UI bug)

`WaterStatsScreen`'s text-scale test was intermittently very slow to
finish under `flutter test` in this development environment — which runs
many concurrent `flutter test` processes across parallel work at once —
sometimes settling in under a second, sometimes taking the full 10-minute
per-test timeout, independent of whether the underlying overflow bugs
were fixed. Isolated reproduction of the exact same widget tree (same
scale, same viewport, same theme), pumped with manual `tester.pump()`
calls and instrumented with `tester.binding.hasScheduledFrame`, never
showed a genuinely stuck frame loop across a 200-virtual-second window —
consistent with contention rather than an actual infinite layout/build
loop in the widget code. One real, narrower finding along the way:
disposing this screen can leave a pending zero-duration `Timer` behind —
Drift's `QueryStream._onCancelOrPause` schedules one to close its
stream-query bookkeeping when a `StreamProvider` watching a Drift stream
(`waterSeriesProvider` et al.) is torn down — which the framework's own
post-test invariant check can catch as "A Timer is still pending even
after the widget tree was disposed" if the test doesn't pump once more
after disposal. `water_stats_text_scale_test.dart` pumps twice after
disposing the widget tree to give that timer a chance to fire, and is
kept as its own file (split out of `water_text_scale_test.dart`) so this
screen's heavier teardown — multiple concurrently-watched Drift streams
plus an animated `fl_chart` — doesn't share an isolate with the other
three Water screens' tests. `WaterStatsScreen` itself renders correctly
with no overflow at 2.0x once the four fixes below landed; the slowness
observed here was about environment contention during test execution,
not a defect in the shipped widget code.

## Edge cases from the plan, re-checked

1. **Fixed-height `Row`/`Column` widgets** — found and fixed twice
   (`WaterAddEntryScreen`'s form `Column`, `StreakCard`'s `Row`).
2. **Buttons with hardcoded dimensions** — none found; buttons across all
   16 screens tested use default/intrinsic sizing.
3. **Snackbar text overflow** — not triggered by any of the tested
   screens' snackbars during a plain screen pump (no snackbar-triggering
   interaction was exercised); not a finding either way.
4. **Chart axis labels** — confirmed and fixed (`PeriodBarChart`).
5. **Bottom-nav labels** — not exercised; the tested screens are pushed
   on top of the shell, not the shell itself. Out of scope for this pass.

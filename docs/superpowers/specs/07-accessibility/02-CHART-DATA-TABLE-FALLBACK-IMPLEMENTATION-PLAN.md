# Implementation Plan: 02 Chart Data-Table Fallback

## Overview

- **Spec:** Chart Data-Table Fallback
- **Complexity:** S
- **Estimated effort:** 1 day
- **Dependencies:** Depends on spec 01 (chart labeling conventions). Prayer stats screen should exist (it does).
- **Prerequisites:** `PeriodBarChart` already exposes series data via `points` list.

---

## Implementation Tasks

### Task 1: Create shared chart data-table widget

**Files to create/modify:**
- `lib/core/widgets/chart_data_table.dart` (new)

**Detailed changes:**
- Create `ChartDataTable` as a `StatelessWidget` that accepts:
  - `List<BarChartPoint> points` — the same data the chart renders.
  - `String? goalLabel` — optional "Goal" column header text.
  - `double? targetValue` — if non-null, the goal column shows met/missed per row.
- Render a `DataTable` (or `ListView` of `Row` widgets for simplicity) with columns:
  - **Period** — from `point.label`.
  - **Value** — from `point.value` formatted with the module's unit.
  - **Goal** — conditionally shown: "Met" if `targetValue != null && point.value >= targetValue`, else "Missed" (or empty if no goal).
- Wrap the entire table in a `Semantics` widget with a label like "Chart data table" (localized).
- Handle empty data: if `points.isEmpty`, show an empty-state message using the existing pattern from stats screens.
- Use `Flexible`/`Expanded` on table cells to handle long value strings (Bangla translations) without overflow.

**Integration:** This is a presentation-layer companion to `PeriodBarChart`. It does not modify the chart widget itself. Each module's stats screen will import and use `ChartDataTable` alongside the existing `PeriodBarChart`.

### Task 2: Add toggle control for table view

**Files to create/modify:**
- `lib/core/widgets/chart_data_table.dart` (modify — add `ChartDataTableToggle` wrapper)

**Detailed changes:**
- Create a `ChartDataTableToggle` widget that:
  - Accepts `List<BarChartPoint> points`, `Color color`, `double? targetLine`, `String? goalLabel`, and a `String chartSemanticsLabel`.
  - Uses `ValueNotifier<bool>` in local state to track chart-vs-table view.
  - Renders `PeriodBarChart` when the toggle is off, `ChartDataTable` when on.
  - Includes a `Semantics`-labeled `IconButton` (table icon / chart icon) that toggles the view.
  - The toggle's `Semantics` label announces its current state (e.g. "Show data table" / "Show chart").
- Store toggle state in `ValueNotifier` (local widget state, not `AppSettings`) since it's a per-screen preference.

**Integration:** Replaces direct `PeriodBarChart` usage in stats screens. The toggle wraps the existing chart widget.

### Task 3: Wire into Water stats screen

**Files to create/modify:**
- `lib/features/water/presentation/water_stats_screen.dart` (modify)

**Detailed changes:**
- Replace the direct `PeriodBarChart(...)` instantiation with `ChartDataTableToggle(...)`, passing the same `points`, `color`, and `targetLine` that the chart already receives.
- Pass `goalLabel: AppLocalizations.of(context).waterStatsPeriodWeek` (or appropriate period label) and `targetLine` as the goal value.
- The chart's existing `Semantics` label (from spec 01) becomes the `chartSemanticsLabel` parameter.

**Integration:** Drop-in replacement — the `ChartDataTableToggle` renders the same chart by default.

### Task 4: Wire into Medicine stats screen

**Files to create/modify:**
- `lib/features/medicine/presentation/medicine_stats_screen.dart` (modify)

**Detailed changes:**
- Same pattern as Task 3 — replace `PeriodBarChart` with `ChartDataTableToggle`.
- Pass Medicine's series data, color, and target line.

**Integration:** Identical to Water's integration.

### Task 5: Wire into Prayer stats screen

**Files to create/modify:**
- `lib/features/prayer/presentation/prayer_stats_screen.dart` (modify)

**Detailed changes:**
- Same pattern — replace `PeriodBarChart` with `ChartDataTableToggle`.
- If Prayer's stats screen has no goal target, pass `targetLine: null` and the table omits the Goal column.

**Integration:** Same as Water/Medicine. Gracefully handles the no-goal case.

### Task 6: Add ARB keys

**Files to create/modify:**
- `lib/core/l10n/app_en.arb` (modify)
- `lib/core/l10n/app_bn.arb` (modify)

**Detailed changes:**
- Add keys: `chartTableToggleLabel`, `chartTablePeriodHeader`, `chartTableValueHeader`, `chartTableGoalHeader`, `chartTableStatusHeader`, `chartTableEmptyState`.
- Add descriptions following existing ARB conventions.

**Integration:** Standard `gen_l10n` flow.

---

## Performance Considerations

- **Caching strategy:** The table uses the same in-memory `List<BarChartPoint>` the chart already holds — no additional data fetching.
- **Lazy loading:** The table is only rendered when toggled on; `ValueNotifier` state ensures it's only built once per toggle cycle.
- **Memory efficiency:** `DataTable` or `ListView.builder` for the table rows — standard Flutter widgets, no overhead beyond the chart itself.

---

## Testing

- `test/core/widgets/charts/chart_data_table_test.dart` — tests:
  - Table renders correct rows for a sample series.
  - Empty data shows empty-state message.
  - Goal column is conditionally present/absent based on `targetLine`.
  - Toggle control switches between chart and table views.
  - All column headers are present and accessible (Semantics nodes).
- `test/features/water/presentation/water_stats_table_test.dart` — Water stats screen renders table fallback when toggled.
- `test/features/medicine/presentation/medicine_stats_table_test.dart` — Medicine stats screen renders table fallback when toggled.

---

## Localization

New ARB keys:
```
chartTableToggleLabel
chartTablePeriodHeader
chartTableValueHeader
chartTableGoalHeader
chartTableStatusHeader
chartTableEmptyState
```

---

## Edge Cases

1. **Empty data series** — table shows empty-state message, not an empty header row.
2. **Very long value strings** — Bangla unit translations may be verbose; `Flexible`/`Expanded` on cells prevents overflow.
3. **Goal target absent** — when `targetLine` is null, Goal column is hidden entirely.
4. **Toggle state persistence** — toggle state lives in local widget state (`ValueNotifier`), resets on route pop.
5. **Screen reader interaction** — toggle button has `Semantics` label and announces its current state.

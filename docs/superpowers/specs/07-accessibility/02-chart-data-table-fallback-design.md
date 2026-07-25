# Chart Data-Table Fallback

**Category:** Accessibility · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is a net-new feature layered on an existing shared widget. `period_bar_chart.dart` is the one reusable `fl_chart` bar chart used by Water's and Medicine's stats screens today, and Prayer's stats screen is expected to reuse it too. A bar chart conveys trend and magnitude visually; a screen-reader user gets little or nothing from it even after item #1's labeling audit adds a summary label. WCAG guidance calls for a non-visual equivalent for any data visualization that carries information not available elsewhere on the screen.

## Goals

- Give every screen that renders `period_bar_chart.dart` an accessible tabular alternative (period, value, and goal-target-met/missed where applicable) that a screen reader can read row by row.
- Make the fallback discoverable without visually cluttering the chart for sighted users (e.g. a toggle, an expandable section, or an always-present but visually de-emphasized table).
- Keep the same data the chart already renders — no new aggregation logic, just a second presentation of it.

## Non-goals / out of scope

- Redesigning the chart itself or changing its visual style.
- Building a generic "chart-to-table" framework for hypothetical future chart types — scope this to the one shared widget in active use.
- Exporting the table data (CSV/share) — that's a separate concern from accessibility if it comes up later.

## Proposed approach (high-level)

Add a data-table view that sits alongside `period_bar_chart.dart` wherever it's used (Water stats, Medicine stats, and Prayer stats once built), sourced from the same series data the chart already receives — this is a presentation-layer addition, not a new data pipeline. The simplest version is a toggle or disclosure control on each stats screen that swaps the chart for a plain data table (or reveals it below/instead of the chart), built from ordinary Flutter table/list widgets so default screen-reader semantics apply for free. Because all three modules already share the one chart widget, this fallback should be built once as a companion to `period_bar_chart.dart` and reused the same way the chart itself is reused, rather than three separate per-module implementations.

## Dependencies & prerequisites

- Depends on `period_bar_chart.dart` already exposing (or being extended to expose) the same series data in a plain, chart-independent form.
- Should follow item #1 (navigation audit) so the fallback's own labels/order are consistent with whatever labeling convention that audit establishes.
- Prayer's stats screen needs to exist (it's noted in CLAUDE.md as intended to reuse the shared chart) before this fallback can be wired into all three modules at once — otherwise it lands in Water/Medicine first and Prayer picks it up when its stats screen ships.

## Open questions for the implementation round

- Toggle control, always-visible table below the chart, or a separate accessible-only route reachable via a semantics action?
- Does the table need its own localization strings (column headers) in both en/bn ARBs, or can it reuse existing stats-screen strings?
- Should the "goal target met" indicator in the table use a symbol/text (per item #3's colorblind concerns) rather than color alone?

## Effort & sequencing notes

Complexity S — one shared widget, one companion view, reused three times. Sequence after item #1 (audit) so labeling conventions are settled; can proceed independently of items #4 through #12.

## Localization

- New ARB keys needed for column headers and the toggle control text:
  - `chart_table_toggle_label` — label for the show/hide table toggle.
  - `chart_table_period_header` — "Period" column header.
  - `chart_table_value_header` — "Value" column header.
  - `chart_table_goal_header` — "Goal" column header (only for modules with a goal target).
  - `chart_table_status_header` — "Status" column header showing met/missed.
- Add these to both `app_en.arb` and `app_bn.arb` following the existing `snake_case` naming convention.
- The toggle label and column headers are all user-facing and must be localized since they appear in a screen-reader-readable table.
- Existing stats-screen strings (e.g. `water_stats_title`, `medicine_stats_title`) can be reused for the table's section title — no duplication needed.

## Edge cases & error handling

1. **Empty data series** — when a module has no data for the selected period, the table must display an empty-state message (e.g. "No data for this period") rather than rendering an empty header row. Reuse the existing empty-state pattern from the stats screens.
2. **Very long value strings** — if a module's value unit is verbose (e.g. Bangla translation of "milliliters"), the table column may overflow; use `Flexible`/`Expanded` widgets on table cells to allow text wrapping rather than truncation.
3. **Goal target absent** — Water and Medicine stats have goal targets; Prayer's stats screen may not. The table must conditionally hide or grey out the "Goal" column header and cells when no goal data is present for the current module.
4. **Table/chart toggle state persistence** — if the user switches to table view and navigates away and back, the table view should persist for that session (store in local widget state, not in `AppSettings`, since this is a per-screen preference not a global setting).
5. **Screen reader interaction with the toggle** — the toggle control that reveals/hides the table must itself have a clear `Semantics` label and announce its current state (following #1's labeling conventions).

## Cross-references

- `docs/superpowers/specs/07-accessibility/01-talkback-voiceover-navigation-audit-design.md` — establishes labeling conventions this fallback must follow.
- `docs/superpowers/specs/07-accessibility/03-colorblind-safe-streak-heatmap-palette-check-design.md` — the "goal met" indicator in the table should use a non-color cue (per this spec's open question).
- `lib/core/widgets/charts/period_bar_chart.dart` — the shared chart widget this fallback accompanies.
- `lib/features/water/presentation/` — Water stats screen where the table will first appear.
- `lib/features/medicine/presentation/` — Medicine stats screen, second consumer.
- `lib/features/prayer/presentation/` — Prayer stats screen, third consumer (when built).

## Test strategy

- **Widget tests**: Create `test/core/widgets/charts/chart_data_table_test.dart` testing:
  - The table renders correct rows for a sample series.
  - Empty data shows the empty-state message.
  - Goal column is conditionally present/absent based on module data.
  - The toggle control switches between chart and table views.
  - All column headers are present and accessible.
- **Widget tests per module**: Add a test in each module's test directory verifying the stats screen renders the table fallback when toggled:
  - `test/features/water/presentation/water_stats_table_test.dart`
  - `test/features/medicine/presentation/medicine_stats_table_test.dart`
- **Golden tests**: Consider a golden test for the table layout at a fixed data set to catch visual regressions in column widths and alignment, especially for Bangla locale.
- **Regression-prevention strategy**: Since the table is built once as a companion to `period_bar_chart.dart`, a single comprehensive widget test suite for the shared component is sufficient; per-module tests only need to verify the toggle wiring, not the table's internal rendering.

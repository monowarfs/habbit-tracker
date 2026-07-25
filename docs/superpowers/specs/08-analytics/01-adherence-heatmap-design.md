# GitHub-Style Adherence Heatmap

**Category:** Analytics · **Kind:** Personal analytics (on-device only) · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

The app already has a month calendar bottom sheet on the dashboard, but a
single month is a narrow window — it can't show a streak's shape over a
year, and it doesn't reward the user for looking back at their history.
GitHub's contribution graph and Loop Habit Tracker's own heatmap are both
proven, addictive-to-scan visual summaries of exactly the day-status data
this app already computes per module. This is a purely personal, on-device
visualization — nothing about it involves sending any data anywhere.

## Goals

- Give each module (Water/Medicine/Prayer) a year-at-a-glance grid of day
  cells, colored by that day's completion status.
- Make the grid scannable at a glance: color intensity should communicate
  "good day" vs "missed day" vs "no data yet" without needing a legend
  read every time.
- Support tapping/hovering a cell to see the specific date's detail (reuse
  whatever the existing month calendar sheet already surfaces per day).
- Work per-module first; a combined/aggregate heatmap across all enabled
  modules is a reasonable stretch goal, not a requirement.

## Non-goals / out of scope

- Not replacing the existing month calendar sheet — this is a
  complementary, longer-range view.
- Not building a generic charting component from scratch if an existing
  grid/heatmap widget pattern can be adapted.
- Not attempting cross-device sync or any historical backfill beyond what
  the local database already holds.
- No product-telemetry angle at all — this is entirely a personal-stats
  feature.

## Proposed approach (high-level)

The day-completion data this needs already exists via the Reports module's
day-status/streak computations (`day_status_streaks`) — the heatmap is
primarily a new presentation layer over data that's already being
aggregated for the Reports screen, not a new data pipeline. The natural
home is either a new tab/section within the existing Reports screen or a
dedicated screen reachable from Reports, keeping it consistent with how
Water/Medicine/Prayer stats screens already present period-based views.
Rendering can follow the same grid-of-cells idea widely used for this
pattern (a scrollable grid, one column per week, one row per weekday,
cell color driven by a per-day status enum). Given the existing
`period_bar_chart` widget is a bar chart not a grid, this likely needs its
own lightweight reusable widget rather than adapting that one.

## Dependencies & prerequisites

- Reports module's day-status/streak data (`day_status_streaks`) as the
  data source — need to confirm it already exposes (or can easily expose)
  a full-year, per-day status series per module rather than just
  period aggregates.
- A per-day status color scheme consistent with each module's existing
  accent color (per-module `ModuleAccents` in the app theme).
- Enough historical data in a fresh install to be meaningful — early on,
  most of the grid will just show "no data," which is an expected and
  fine empty state, not a defect.

## Open questions for the implementation round

- Should there be one heatmap per module, a combined all-modules view, or
  both — and if combined, how is a "day" scored when a user runs multiple
  modules with different completion definitions?
- What's the exact color/intensity scale (binary done/not-done vs. a
  gradient reflecting partial completion, e.g. medicine adherence % on a
  multi-dose day)?
- Where does this live in navigation — inside Reports, or its own
  dashboard entry point?
- Does this need virtualized/lazy rendering for performance once a user
  has multiple years of history, or is a year small enough to render
  eagerly?

## Effort & sequencing notes

Atlas complexity: M. Straightforward once the underlying day-status series
is confirmed available per module; the main work is a new grid widget and
its data-shaping, not new domain logic. No hard dependency on other items
in this batch — reasonable to schedule independently, though it pairs
naturally with the "personal record" and "goal-attainment" items since all
three consume the same underlying day-status/streak data.

## Database schema

No new tables. The heatmap reads from each module's `dayStatus(DateRange)`
method, which already returns `Map<LocalDate, ModuleDayStatus>`. For a
full-year view, pass `DateRange(start: LocalDate(year, 1, 1), end:
LocalDate(year, 12, 31))`.

## Localization

New ARB keys (en/bn):
- `heatmapTitle` — "Year at a Glance"
- `heatmapTooltipDone` — "Completed"
- `heatmapTooltipPartial` — "Partially completed"
- `heatmapTooltipMissed` — "Missed"
- `heatmapTooltipNone` — "No data"
- `heatmapMonthLabels` — abbreviated month names (J, F, M, ...)
- `heatmapDayLabels` — abbreviated day names (M, T, W, ...)

## Edge cases & error handling

- **Performance for 365-day range:** the existing `dayStatus()` method
  returns a map — 364 entries is trivial. No virtualization needed for
  v1. If multi-year is added later (Spec 04-premium/08), consider
  paginated rendering.
- **Empty data:** show "No data for this year" with a prompt to start
  tracking.
- **Partial year:** if the user started mid-year, show only months with
  data. Gray out future months.
- **Cross-module aggregate view:** for v1, show per-module heatmaps
  separately. Cross-module scoring is deferred to Spec 08-analytics/05
  (consistency score).

## Cross-references

- Day-status data: `lib/core/reports/day_status_streaks.dart`.
- Existing heatmap widget: `HabitHeatmapCalendar` in Medicine stats.
- Related: Spec 08-analytics/02 (personal record) — same data source.
- Related: Spec 08-analytics/05 (consistency score) — aggregate view.
- Related: Spec 04-premium/08 (extended stats) — multi-year heatmap.

## Test strategy

- Unit test: heatmap data shaping from day-status map.
- Widget test: heatmap rendering with mock data.
- Widget test: empty state and partial-year display.
- Golden test: heatmap visual output for regression.

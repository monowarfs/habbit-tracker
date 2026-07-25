# Best/Worst Day-of-Week Breakdown

**Category:** Analytics · **Kind:** Personal analytics (on-device only) · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Current stats screens show overall completion rates and streaks, but
nothing answers the more actionable question a user actually asks
themselves: "why do I keep failing?" A day-of-week breakdown ("You
complete Water 92% of Sundays, 61% of Wednesdays") is specific enough to
prompt a concrete behavior change — e.g. moving a reminder time, or just
noticing a pattern — in a way a single blended percentage cannot. Apple
Health's trends feature uses exactly this kind of segmentation. This is a
purely personal, on-device statistic.

## Goals

- For each module, compute and display completion rate segmented by day
  of week (Mon–Sun), over a selectable period (e.g. last 30/90 days, or
  all-time).
- Clearly highlight the best and worst day so the takeaway is immediate,
  not something the user has to compute themselves by scanning seven bars.
- Keep the display lightweight — a small bar/strip, not a new complex
  chart type.

## Non-goals / out of scope

- Not a general-purpose "slice by any dimension" analytics builder — this
  is one specific, fixed segmentation (day of week), not a configurable
  pivot table.
- Not attempting causal explanation (e.g. correlating with notification
  times) — that's the notification-effectiveness item's territory, kept
  separate.
- Not applicable to Medicine's per-dose granularity in the same way as
  Water/Prayer's daily granularity — Medicine's version may need to be
  adherence-rate-by-weekday rather than a simple boolean, which is a
  scoping detail for the implementation round.

## Proposed approach (high-level)

Day-of-week segmentation is a grouping performed on top of the same
day-status series the Reports module's aggregate report use case
(`aggregate_report_usecase`) already produces — bucket each day's known
completion status by its weekday, then average within each bucket. This
is a pure aggregation function, similar in shape to the existing
week/month/year rollups, just grouped differently. The natural
presentation surface is each module's own stats screen (Water/Medicine/
Prayer), likely as a small addition alongside the existing period bar
chart (`period_bar_chart`) rather than a new chart type — a simple
seven-bar strip with the best/worst bars called out.

## Dependencies & prerequisites

- The day-status series already produced for Reports aggregation
  (`aggregate_report_usecase`) as the sole data input.
- Enough historical data for the breakdown to be statistically meaningful
  — a brand-new user will see a mostly-empty or noisy breakdown, which
  needs a sensible empty/low-data state rather than a misleading result.
- Per-module stats screens as the presentation surface.

## Open questions for the implementation round

- What's the right minimum sample size before showing a "best/worst day"
  claim (a single Sunday shouldn't produce "100% on Sundays")?
- Should the period be user-selectable (last 30/90 days, all-time) or
  fixed to one default?
- How does this apply to Medicine, where a day can have multiple doses
  with partial adherence rather than a single done/not-done state?

## Effort & sequencing notes

Atlas complexity: S. A pure aggregation/grouping function reusing existing
day-status data plus a small new UI strip — low effort. Pairs naturally
with personal-record tracking and trend arrows since all three are small,
independent additions to the same stats screens.

## Database schema

No new tables. The breakdown is computed at read time from the existing
`dayStatus(DateRange)` data, grouped by weekday.

## Localization

New ARB keys (en/bn):
- `dayOfWeekBest` — "Best day: {day}"
- `dayOfWeekWorst` — "Worst day: {day}"
- `dayOfWeekLabel` — "{day}: {percent}%"
- `dayOfWeekMon` through `dayOfWeekSun` — abbreviated day names.
- `dayOfWeekInsufficientData` — "Not enough data yet"

## Edge cases & error handling

- **Minimum sample size:** require at least 4 weeks (28 days) of data
  before showing best/worst day. Below that, show "Not enough data yet."
- **Medicine partial adherence:** use adherence rate (percentage of doses
  taken) per weekday, not a boolean. A day with 80% adherence scores
  higher than 50%.
- **Period selection:** default to last 90 days. Allow user to switch
  between 30/90/all-time via a segmented control.
- **Equal scores:** if multiple days tie for best/worst, show all tied
  days (e.g. "Best days: Mon, Wed, Fri").

## Cross-references

- Aggregate report: `lib/core/reports/aggregate_report_usecase.dart`.
- Related: Spec 08-analytics/04 (trend arrows) — same stats screen.
- Related: Spec 08-analytics/05 (consistency score) — related metric.
- Related: Spec 08-analytics/08 (adherence by medicine) — Medicine's
  partial adherence granularity.

## Test strategy

- Unit test: weekday grouping and percentage calculation.
- Unit test: minimum sample size enforcement.
- Widget test: day-of-week breakdown display.
- Widget test: insufficient data state.

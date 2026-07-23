# Comparison-to-Past-Self Chart

**Category:** Analytics · **Kind:** Personal analytics (on-device only) · **Atlas complexity:** M · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Apple Health's yearly trends view lets a long-tenured user see this
month's numbers overlaid against the same month a year ago — a
meaningful, motivating comparison, but only for someone who has actually
used the app for a year or more. This is explicitly a long-tenure reward:
low near-term retention impact (most users won't have the history to use
it soon after install) but a genuine "the app grows with you" payoff for
users who stick around, and a good signal that the product respects
long-term users rather than only ever addressing new ones.

## Goals

- Let a user overlay the current month's (or week's) data series against
  the same period one year prior, on the same chart.
- Reuse the existing period bar chart presentation rather than inventing
  a new chart type.
- Degrade gracefully (and honestly) when a user doesn't yet have a year of
  history — hide or clearly label the feature as "not enough history yet"
  rather than showing a misleading empty comparison.

## Non-goals / out of scope

- Not a general "compare any two arbitrary periods" tool — specifically
  "this period vs. the same period last year," matching the Apple Health
  inspiration.
- Not building new data retention/backfill — this only works with
  whatever local history already exists; no attempt to reconstruct or
  synthesize missing older data.
- Not prioritized for near-term build — explicitly the lowest
  retention-impact item in this batch, reasonable to schedule last.

## Proposed approach (high-level)

The existing period bar chart widget (`period_bar_chart`) already renders
bars plus an optional goal target line for a single period's series per
module (built for Water, reused by Medicine); this feature is best framed
as extending that same widget to optionally render a second overlay
series (last year's data) rather than building a new chart component.
The data side reuses whatever per-module aggregation already produces a
period's series (Water's `AggregateWaterSeriesUseCase` and equivalents for
Medicine/Prayer) — the only new logic is fetching the same aggregation for
a year-shifted date range and passing both series into the chart.

## Dependencies & prerequisites

- At least one full year of local usage history for the comparison to be
  meaningful — this is a hard practical prerequisite, not just a nice
  data point.
- The existing `period_bar_chart` widget's willingness to accept a second,
  visually distinct overlay series (e.g. a lighter/dashed bar or line for
  "last year").
- Each module's existing period-aggregation use case, called twice with
  different date ranges rather than needing new domain logic.

## Open questions for the implementation round

- What's the exact eligibility threshold — do we require a full 365 days
  of app install, or just that data exists for the equivalent period
  last year (a user could have gaps)?
- Does this apply per-module only, or would a combined view make sense
  eventually — likely per-module only for a first pass.
- What happens across leap years / month-length mismatches when aligning
  "the same period last year"?
- Is this discoverable proactively (the app surfaces it once a user
  crosses the one-year mark) or only on-demand (user has to know to look
  for it)?

## Effort & sequencing notes

Atlas complexity: M. The chart-widget extension and cross-year data
fetching are moderate but well-bounded work; the low retention impact and
hard one-year data prerequisite make this a reasonable candidate to
schedule last among the personal-analytics items in this batch.

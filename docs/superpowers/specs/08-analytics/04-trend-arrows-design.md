# Trend Arrows vs. Previous Period

**Category:** Analytics · **Kind:** Personal analytics (on-device only) · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Every module's stats screen currently shows static numbers for the
current period (this week's/month's completion rate, average, etc.) with
no sense of direction. A simple up/down arrow comparing the current
period to the previous one — the pattern TickTick uses for its own
completion stats — reframes a static number into a trajectory at almost
no visual cost, which is exactly the kind of small, cheap addition that
makes a stats screen feel alive on every visit rather than only on days
with a milestone.

## Goals

- Add a trend indicator (up/down/flat arrow, plus the delta) next to the
  key headline numbers on each module's stats screen (Water, Medicine,
  Prayer) and, where relevant, the Reports screen.
- Compare the current period to the immediately preceding period of the
  same length (this week vs. last week, this month vs. last month).
- Keep it purely visual/glanceable — no new screen, no new navigation.

## Non-goals / out of scope

- Not a full historical trend chart — that's the comparison-to-past-self
  item's territory (a full overlay chart is a separate, larger feature).
- Not adding trend arrows to every possible metric on first pass — start
  with the one or two headline numbers each stats screen already
  foregrounds, not an exhaustive sweep of every stat.
- Not attempting statistical significance testing — this is a simple
  period-over-period delta, not a claim about whether a change is
  "real."

## Proposed approach (high-level)

This is the smallest item in the batch: for whichever headline metric a
stats screen already computes (from the same aggregation use cases
already backing Water's `AggregateWaterSeriesUseCase`, Medicine's
`calculateAdherence`, and Prayer's own adherence/on-time calculators), also
compute the same metric for the prior equivalent period and diff the two.
The UI addition is a small arrow-plus-percentage widget placed next to
the existing number — no new screen, no new route, and no change to the
underlying use cases beyond calling them once more with a shifted date
range.

## Dependencies & prerequisites

- Each module's existing period-aggregation use case
  (`AggregateWaterSeriesUseCase`, `calculateAdherence`, Prayer's
  adherence calculator) — called twice (current + previous period)
  rather than needing new logic.
- A small shared "trend delta" presentation widget so the arrow/delta
  treatment is visually consistent across all three modules' stats
  screens, rather than three separate implementations.

## Open questions for the implementation round

- What counts as "previous period" when the current period is partial
  (e.g. comparing an in-progress week to a full previous week) — compare
  like-for-like partial ranges, or wait until the period completes?
- Does this belong on the Reports screen's rollups too, or only on each
  module's own stats screen?
- Is a flat/no-change state worth its own icon, or does a small
  percentage suffice without a third arrow direction?

## Effort & sequencing notes

Atlas complexity: S. Reuses existing aggregation use cases as-is; the only
real work is a shared small widget and calling the aggregation function
twice. Very low risk — a good early/cheap win in this batch, independent
of the others.

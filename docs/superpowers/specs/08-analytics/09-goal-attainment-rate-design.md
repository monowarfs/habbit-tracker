# Goal-Attainment Rate Over Time

**Category:** Analytics · **Kind:** Personal analytics (on-device only) · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Streak length is the metric most prominently shown today, but a streak is
an all-or-nothing measure that resets to zero on a single missed day —
it can make weeks of mostly-good behavior look like a failure after one
slip. "Hit your water goal 22/30 days" is a distinct, more forgiving
metric that captures overall consistency even through an occasional
broken streak, which is exactly the gap Loop Habit Tracker's own
goal-attainment view fills alongside its streak counters.

## Goals

- Show, as its own stat/chart distinct from streak length, the count and
  percentage of days a module's goal was actually hit over a selected
  period (e.g. "22/30 days" or "73%").
- Make clear this is a different metric from the streak count, not a
  restatement of it — likely placed near but visually distinct from the
  streak display.
- Start with Water (whose goal concept — a daily volume target — is the
  cleanest fit) and extend the same pattern to Medicine/Prayer if their
  own goal/completion definitions map naturally.

## Non-goals / out of scope

- Not replacing the existing streak display — additive, not a
  substitution.
- Not a new goal-setting feature — this only reports attainment against
  whatever goal-setting already exists (Water's goal history, Medicine's
  schedule-based completion, Prayer's five-daily-prayer completion).
- Not attempting partial-credit scoring (e.g. "80% of goal" counting as a
  fractional hit) in this first pass — a day either hit the goal or it
  didn't, matching the simple, forgiving framing that's the point of this
  metric.

## Proposed approach (high-level)

Water's existing per-day aggregation (`AggregateWaterSeriesUseCase`)
already buckets daily totals against a resolved goal for charting
purposes — goal-attainment rate is a straightforward derived count over
that same per-day series (count of days where the daily total met or
exceeded the resolved goal, divided by days in the period), not a new
data pipeline. The natural presentation is a small addition to Water's
existing stats screen, likely near its existing chart, phrased explicitly
as a distinct stat from the streak count so users don't conflate the two.
The same shape of calculation (day hit goal vs. not, over a period)
should translate to Medicine and Prayer using their own respective
existing day-completion notions, though each module's definition of "hit
the goal" differs enough that this may need light, module-specific
adaptation rather than one shared generic function.

## Dependencies & prerequisites

- Water's `AggregateWaterSeriesUseCase` and its existing goal-resolution
  logic (`ResolveGoalForDateUseCase`) as the primary data source.
- Each module's own day-completion definition if extended beyond Water —
  Medicine's dose-completion state and Prayer's five-daily-prayer
  completion would each need their own "did this day hit the goal"
  framing.
- Existing per-module stats screens as the presentation surface.

## Open questions for the implementation round

- Should this ship for Water only first, with Medicine/Prayer as a
  follow-up once the pattern is validated, or all three together?
- What period(s) should be selectable — same week/month/year selector as
  existing stats screens, presumably?
- Does a day with no data (module not yet in use, or a day before install)
  count against the denominator, or is the period bounded to days the
  module was actually active?

## Effort & sequencing notes

Atlas complexity: S. A straightforward derived count over data
`AggregateWaterSeriesUseCase` already produces for Water; extending to
Medicine/Prayer is slightly more effort since each module's "goal"
concept differs. Reasonable to scope Water-only first and treat the other
two modules as a fast follow within the same feature.

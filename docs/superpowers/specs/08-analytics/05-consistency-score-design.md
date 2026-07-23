# Composite Daily "Consistency Score"

**Category:** Analytics · **Kind:** Personal analytics (on-device only) · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

A user running all three modules (Water, Medicine, Prayer) together has
no single number that says "how am I doing today, overall" — they have to
mentally average three separate per-module statuses. Oura's and Whoop's
readiness scores prove that a single, well-designed 0-100 composite is a
powerful daily glanceable metric that drives repeat opens, precisely
because it collapses a lot of underlying signal into one number worth
checking each morning.

## Goals

- Define a single 0-100 "Consistency Score" per day, blending the
  day-completion status of every module the user currently has enabled.
- Surface it prominently on the dashboard — a natural companion to the
  existing day-completion indicator and upcoming strip already there.
- Make the score's composition legible on demand (a tap/expand should show
  which modules contributed what), so it doesn't feel like an opaque
  black-box number.

## Non-goals / out of scope

- Not a health/readiness score in the Oura/Whoop sense (no biometric
  input) — purely a completion-consistency metric derived from this app's
  own day-status data.
- Not replacing any module's own individual stats — this is an additional
  rolled-up view, not a substitute for Water/Medicine/Prayer's own
  screens.
- Not attempting a historical "score trend chart" in this pass — today's
  score and perhaps a short recent history is enough; a full trend view
  can follow later if it earns its own scope.

## Proposed approach (high-level)

Each module already has its own day-completion notion — this is the same
"day status" per-module data that already backs the dashboard's
day-completion indicator and the Reports module's aggregation
(`day_status_streaks`). The consistency score is a weighted (or, to
start, simple average) combination of each enabled module's own
day-completion status/percentage for the day, computed fresh each day
rather than stored — consistent with how the codebase already treats
other derived-not-persisted status (e.g. Medicine's lazily-derived dose
status). The natural home for both the computation and the display is
alongside the dashboard's existing day-completion indicator, since that's
already the per-day, per-module rollup surface.

## Dependencies & prerequisites

- Each module's day-completion/day-status data as already computed for
  the dashboard's day-completion indicator and the Reports module.
- A weighting/normalization decision for how modules with very different
  completion shapes (Water's single daily goal vs. Medicine's multiple
  discrete doses vs. Prayer's five daily prayers) combine into one
  comparable 0-100 figure.
- Graceful behavior when zero or one module is enabled — the "composite"
  framing matters most with 2+ modules active; the single-module case
  needs a sensible degenerate behavior (probably just that module's own
  percentage).

## Open questions for the implementation round

- What's the actual scoring formula — simple average of per-module
  completion percentages, or a weighted blend, and does the weighting
  differ if a user hasn't enabled all modules?
- Should partial-day (still in progress) scores be shown differently from
  end-of-day final scores, given the day isn't "graded" until it ends?
- Is this a dashboard-only feature, or does it also warrant its own small
  history view (e.g. last 7 days of scores) on the Reports screen?
- Does this interact with achievements (e.g. a streak of high-consistency
  days) or stay purely a standalone stat for this pass?

## Effort & sequencing notes

Atlas complexity: M. The data inputs already exist per-module; the real
work is designing and validating the composite formula and building a new
dashboard surface for it. Best sequenced after (or alongside) the
personal-record and heatmap items since all three read from the same
day-status foundation, but this one needs its own scoring-formula design
work the others don't.

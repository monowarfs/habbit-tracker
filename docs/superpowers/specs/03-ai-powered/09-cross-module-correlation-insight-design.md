# Cross-Module Correlation Insight

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Each module today reports on itself in isolation — Water's stats screen
shows Water history, Prayer's shows Prayer history — but a user managing
several habits at once likely has real behavioral correlations between
them (missing Asr correlating with also missing an evening water goal,
for instance) that no screen currently surfaces. Apple Health's trends
feature demonstrates the value of exactly this kind of cross-signal
observation for user self-awareness, without needing to explain *why*
the correlation exists — just surfacing "here's a pattern" is often
enough for a user to notice something they hadn't consciously connected.

## Goals
- Detect statistically notable co-occurrence patterns between two
  modules' day-level completion status (e.g. missed-day correlations)
  using the Reports module's existing aggregated day-status data.
- Surface a small number of plain-language observations ("Days you miss
  X, you also tend to miss Y") rather than a raw correlation coefficient.
- Keep the framing strictly observational, never diagnostic or
  prescriptive — a locally-computed note, not a claim about causation.

## Non-goals / out of scope
- No causal inference, no machine learning, no statistical modeling
  beyond a straightforward co-occurrence/correlation calculation over
  day-level pass/fail data already produced by the Reports module.
- Not a general-purpose analytics dashboard — a small, bounded number of
  the most notable patterns, not an exhaustive matrix of every
  module-pair combination.
- Does not send any data anywhere — entirely computed and displayed
  on-device, consistent with every other item in this category except
  the one cloud item.

## Proposed approach (high-level)
Pure local statistics on top of data the Reports module already
aggregates: `aggregate_report_usecase`'s day-completion-streaks output
(and the underlying `day_status_streaks` per-module day status) gives a
pass/fail signal per module per day. For each pair of enabled modules,
compute a simple co-occurrence measure over a rolling window (e.g. how
often a "missed" day in module A coincides with a "missed" day in module
B, compared to how often B is missed on days A is completed) and, when
the difference is large enough to be worth mentioning, generate a
plain-language sentence describing it. This becomes a new, small
insights section on the existing Reports screen, reusing its existing
week/month/year aggregation machinery rather than introducing a
parallel data pipeline.

## Dependencies & prerequisites
- The Reports module's existing `day_status_streaks` and
  `aggregate_report_usecase` day-level data.
- Enough days of history across at least two active modules before any
  correlation is statistically meaningful — a fresh install or single-
  module user has nothing to correlate.
- Copy/tone guidance so generated sentences read as gentle observations,
  not clinical or alarming statements.

## Open questions for the implementation round
- What's the minimum sample size (days) and correlation-strength
  threshold before a pattern is surfaced, to avoid noisy/spurious
  correlations from short histories?
- How many patterns get shown at once — just the single strongest one,
  or a short ranked list?
- Does this only compare "missed" days, or also positive correlations
  (completing both consistently), and does that framing add or dilute
  the insight's usefulness?
- Should a user be able to dismiss/mute a specific insight they don't
  find useful, similar to how other dismissible UI elements work
  elsewhere in the app?

## Effort & sequencing notes
Complexity M — the correlation arithmetic itself is simple, but
generating trustworthy, non-spurious, plain-language observations from
noisy real-world data (especially with limited history) is the harder
design problem. Natural to sequence after the Reports module has
accumulated real usage data to validate against.

# Personal-Record Tracking

**Category:** Analytics · **Kind:** Personal analytics (on-device only) · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

The Reports module already computes longest-streak records as part of its
week/month/year aggregation, but today that number is just one figure
among several on a stats screen — it isn't surfaced as an explicit,
celebrated achievement. Strava's "PR" framing (personal records, called
out by name, with the specific number and date) is a well-proven pattern
for turning a buried statistic into something a user feels proud of and
wants to keep or beat. This is a purely personal, on-device feature.

## Goals

- Surface each module's longest-streak record as an explicit, named
  headline stat (e.g. "Longest prayer streak: 41 days (record)"),
  distinct from the current/active streak count.
- Make it visually distinct — a small badge/highlight treatment, not just
  another number in a list — so it reads as an accomplishment.
- Detect and (subtly) celebrate the moment a record is broken, not just
  display the historical max.

## Non-goals / out of scope

- Not a full achievements/badges system — that already exists via
  `core/achievements` and this feature should complement it, not duplicate
  it (a record could become an achievement trigger, but this spec is
  about the stat surface, not the achievement engine's rules).
- Not introducing new streak-calculation logic — this reuses the existing
  longest-streak computation, it doesn't recompute it differently.
- Not extending to non-streak records (e.g. "most water logged in a day")
  in this pass — that's a reasonable future extension but out of scope
  here to keep this lightweight.

## Proposed approach (high-level)

The longest-streak number already comes out of the Reports module's
aggregate report use case (`aggregate_report_usecase`) alongside the
week/month/year view. The main change is presentational: pull that record
value forward into a dedicated, prominent slot — likely near the top of
each module's stats screen and/or the Reports screen — rather than
leaving it embedded in a general stats block. Detecting a "new record"
moment (current streak surpassing the previously stored longest) is a
comparison the aggregate report use case (or a thin wrapper around it)
can perform on read; whether that moment also fires an achievement is a
question for the achievements engine, which already has a write-path
hook per module for exactly this kind of event.

## Dependencies & prerequisites

- `aggregate_report_usecase`'s existing longest-streak computation as the
  sole data source — no new domain logic expected.
- Coordination with `core/achievements` if a "new record" is meant to also
  trigger a celebratory achievement, to avoid two separate detection paths
  for the same event.
- Per-module stats screens (Water/Medicine/Prayer) as the presentation
  surface, following whatever visual language they already use for
  headline numbers.

## Open questions for the implementation round

- Does "longest streak" mean an all-time record only, or should there be
  a rolling "best this year" record too?
- Should the record be shown per-module only, or does the dashboard also
  get a rolled-up "best streak across all modules" callout?
- Is the "new record" moment worth a distinct celebratory UI treatment
  (e.g. a small animation/toast) beyond just updating the number, and does
  that overlap with the achievements engine's own celebration UI?

## Effort & sequencing notes

Atlas complexity: S. This is primarily a presentation change on top of
data the Reports module already produces — low risk, low effort. Natural
first candidate in this batch since several other items (heatmap,
day-of-week breakdown) share the same underlying data source and could be
sequenced together.

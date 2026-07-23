# Yearly "Wrapped"-Style Recap

**Category:** Long-Term Retention · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Everything else in the atlas is built to earn week one. This feature is built for the moment a full year later, when a user hasn't opened the app in three weeks and the only thing that gets them back is a reason that feels personal and effortless to receive. A generated end-of-year story — total doses taken, prayers completed, water logged, longest streaks — costs the user nothing (no data entry, no decision) and gives them something worth sharing or at least worth a proud thirty seconds. Without it, a year of faithfully-logged data just sits in the database with no moment where the app hands it back as a story.

## Goals
- Produce a locally-rendered, shareable-feeling recap once a full calendar year of usage has accumulated.
- Surface it proactively (not buried in a menu) at a natural year-end moment.
- Pull from data every module already has — no new tracking required.
- Make it feel personal per-module (water totals, prayer on-time %, medicine adherence) rather than one generic number.

## Non-goals / out of scope
- No actual social sharing / image export pipeline in this pass (may be a fast-follow, not core to the retention hook).
- No cross-user comparison, leaderboards, or benchmarking against "typical users."
- No mid-year recaps (monthly/quarterly) — that's a different, separate feature.
- No new achievement types beyond what already exists — this is a presentation layer over existing history, not a new gamification system.

## Proposed approach (high-level)
Build a recap generator that reads a full year's worth of history from each registered module (via the module registry) and existing aggregation/streak use cases per module (the Water/Prayer/Medicine streak calculators and the Reports module's aggregation logic), then renders a sequence of story-card screens — one hero stat per module plus a combined "best day/longest streak" card. This is presentation-and-aggregation work, not new domain logic: reuse the existing recap-card renderer described in the reports module rather than inventing new chart types. Trigger it via a one-time-per-year check on app launch (similar in spirit to the existing app-resume re-planning hook), gated so it only fires once the user has enough history for it to be meaningful (e.g. at least one module used across most of the past year).

## Dependencies & prerequisites
- Reports module's aggregation/streak use cases (per-module, already exist for Water; Prayer/Medicine equivalents).
- A recap-card renderer/screen (reuse whatever the Reports screen already uses for period charts).
- Enough historical data to make the recap non-empty — needs a graceful "not enough data yet" fallback for users under a year old.
- `module_registry.dart` to iterate all installed modules generically rather than hard-coding Water/Medicine/Prayer.

## Open questions for the implementation round
- What exact trigger condition (calendar year boundary vs. rolling 365-day anniversary of install date) — ties into the anniversary-badge feature's install-date tracking.
- Does this need a dismiss-and-never-show-again vs. a permanently-accessible "past recaps" archive?
- Which stats are compelling enough to be the "headline" card vs. supporting detail, per module?
- Should recap generation be lazy (computed once, cached) or always regenerated on view?

## Effort & sequencing notes
Complexity M — mostly assembly of existing aggregation logic behind a new presentation flow, not new domain logic. Natural pairing with the anniversary-badge feature (#6) since both key off install-date/tenure; consider sequencing them together since the trigger-condition logic overlaps.

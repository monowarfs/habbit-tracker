# Habit Archive with "Revive" Flow

**Category:** Long-Term Retention · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Somewhere around month six or year two, life changes and a medicine schedule or water goal stops applying — a prescription ends, a routine shifts. Today the only real option is deleting it, which discards configuration and frames the moment as failure ("starting over from scratch") rather than a normal pause. A year-two user is far more likely to come back to something they paused than something they deleted, because deletion carries an emotional cost delete doesn't communicate as reversible. An explicit archive-and-revive path removes that shame and makes returning to an old habit as easy as it should be.

## Goals
- Let a user archive a medicine schedule or water goal instead of deleting it, hiding it from active views without losing its configuration.
- Provide an explicit "revive" action that restores the exact prior settings (schedule, goal amount, reminders) rather than requiring re-entry.
- Make archived items visibly distinct from active ones so the UI isn't cluttered with dormant entries.
- Preserve historical logs/doses tied to the archived item so past streaks and reports remain intact.

## Non-goals / out of scope
- No automatic archiving based on inactivity detection — this is a user-initiated action, not a silent background behavior.
- No archive for Prayer (its schedule is location/method-driven, not a per-item toggle like Water goals or Medicine schedules) — scope this to the modules where "pausing one thing" is a coherent concept.
- No data export/import tie-in in this pass — that's the separate Data settings screen's concern.
- No multi-level archive hierarchy (archived-of-archived) — one flat archived state.

## Proposed approach (high-level)
This is largely a soft-delete pattern the codebase already has: the existing `deleted_at` soft-delete columns establish the precedent of marking a row inactive without physically removing it, and repositories already filter on that column for "active" queries. Introduce an equivalent "archived" (as distinct from "deleted") state — either a new column or a status enum alongside the existing soft-delete field, since archived and deleted are different lifecycles (deleted is meant to be permanent/hidden everywhere, archived is meant to be visible in one dedicated "archived" list and revivable). The revive flow is then just flipping that flag back and re-running whatever activation logic already exists for a newly-created schedule or goal (recomputing next-due dates, re-registering notifications) rather than any new restore mechanism.

## Dependencies & prerequisites
- The existing soft-delete `deleted_at` columns and the query-filtering convention they've established.
- Medicine's schedule-activation logic and Water's goal-resolution logic, both of which need to treat a revived item exactly like a freshly created one for date/notification purposes.
- The notification planner, since reviving a medicine schedule needs to re-enter it into the pending-notification pipeline.
- A UI surface (likely inside each module's settings or a dedicated "archived items" screen) to list and revive archived entries.

## Open questions for the implementation round
- Should archiving pause notifications immediately, or only take effect at the next materialization cycle?
- Does archiving a medicine schedule need to reconcile in-flight doses (today's `due`/`upcoming` doses) at the moment of archiving?
- Is "archived" a per-schedule/per-goal flag, or could it apply at the whole-module level (e.g. archive Water entirely)?
- How does revive interact with streak math — does reviving resume the old streak, or does it necessarily start fresh (ties into the life-event pause mode feature)?

## Effort & sequencing notes
Complexity M — new lifecycle state plus reactivation logic across two modules, but built on an established soft-delete pattern rather than a novel one. Reasonable to sequence after or alongside the life-event pause mode feature (#4), since both touch "streak math when something isn't currently active."

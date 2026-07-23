# Anniversary Badge ("1 Year With the App")

**Category:** Long-Term Retention · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Every achievement in the app today rewards a specific behavior — a streak, a milestone count. None of them reward simply staying, and by year two, staying is itself the accomplishment worth acknowledging. A user whose water streak broke twice, whose medicine schedule changed three times, and who nonetheless kept coming back for a full year has a relationship with the app that behavior-specific streaks don't capture. An anniversary badge recognizes tenure itself, which is exactly the kind of quiet acknowledgment that makes a year-two user feel seen rather than just measured.

## Goals
- Award a badge/achievement at the one-year mark (and plausibly further multi-year marks) from the user's install date, independent of any streak state.
- Make it visible wherever other achievements already surface, so it doesn't need its own separate UI.
- Trigger reliably exactly once per anniversary, with no dependency on the user having been actively logging that day.

## Non-goals / out of scope
- No tiered sub-year anniversaries (3-month, 6-month) in this pass — the atlas names the one-year mark specifically; shorter/longer intervals can follow the same mechanism later if wanted.
- No notification campaign around the anniversary in this pass (could pair with the recap feature's launch trigger, but that's a separate decision).
- No cosmetic reward tied to this specifically — that's the separate loyalty-milestone-rewards feature; this is just the achievement/badge record itself.

## Proposed approach (high-level)
This plugs directly into the existing achievements engine, which already evaluates and persists achievement records from each module's own write path. An anniversary badge is a cross-cutting achievement not owned by any one module — it needs an install-date signal (when the app was first used) that doesn't currently exist as a tracked value and would need to be captured once, at first launch, and stored durably. The achievement engine's evaluation would then need one non-module-triggered check: on each app open, compare current date against install date and award the anniversary achievement definition if the threshold has just been crossed and it hasn't already been awarded. This is a small, mostly evaluation-trigger addition to an engine that otherwise assumes achievements are triggered by module writes.

## Dependencies & prerequisites
- The achievements engine and its existing repository/evaluation pattern.
- An install-date value — needs to be captured and persisted at first launch if it doesn't already exist anywhere in the app (settings or a dedicated small record).
- A trigger point that runs independent of any module's write path, since "a year passed" isn't caused by a log/dose/prayer write — likely the same app-resume hook that already re-plans notifications.

## Open questions for the implementation round
- Does install-date tracking already exist anywhere (e.g. implicitly via the earliest row in any table), or does this need a brand-new persisted field?
- Should this be evaluated on every app open (cheap date comparison) or does it need a scheduled check independent of the user opening the app that day?
- Does the atlas intend just a 1-year badge, or should the mechanism be built generically for N-year milestones from the start (ties into the loyalty-rewards feature at 2 years)?

## Effort & sequencing notes
Complexity S — one new achievement definition plus a non-module trigger path in an engine that already exists. Natural to build together with or just before the loyalty-milestone cosmetic rewards feature (#10), since both need the same install-date tracking and a similar "N years since install" evaluation.

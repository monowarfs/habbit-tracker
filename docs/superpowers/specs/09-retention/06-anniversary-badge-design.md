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
- **Cross-cutting gap (installDate):** No `installDate` field exists in `AppSettings` today. This must be added to the settings entity before this spec can evaluate anniversary milestones.
- **Cross-cutting gap (achievement engine cross-cutting support):** The current achievement engine only evaluates from module write paths. An anniversary badge is a *cross-cutting* achievement not owned by any module — the engine must gain a new trigger type: "app resume" or "time-based" evaluation, distinct from module-write triggers.
- **Cross-cutting gap (schema migration):** The `achievements` table needs a `milestone_value` (or `target_years`) column to support generic N-year milestones. This requires a Drift schema migration.

## Resolved Dependencies
Prerequisites that must be built **before** this spec can be implemented:
1. `installDate` field added to `AppSettings` (Drift table + entity) — shared with Spec 05 (quarterly recalibration).
2. Achievement engine extended with a non-module-triggered evaluation path (e.g., "app resume" or "scheduled" trigger type).
3. `achievements` table extended with a `milestone_value` column to support N-year milestones generically.
4. Drift schema migration for the `achievements` table changes.

## Open questions for the implementation round
- ~~Does install-date tracking already exist anywhere (e.g. implicitly via the earliest row in any table), or does this need a brand-new persisted field?~~ → **Decision: New persisted field.** Implicit derivation from earliest row is fragile (rows can be deleted, data can be imported). A dedicated `installDate` field in `AppSettings` is set once on first launch and never changed.
- ~~Should this be evaluated on every app open (cheap date comparison) or does it need a scheduled check independent of the user opening the app that day?~~ → **Decision: Every app open.** The check is a cheap date comparison (`DateTime.now().difference(installDate).inDays >= 365 * N`). No background scheduler needed — the user opens the app, the engine evaluates, and awards the badge if the threshold has just been crossed and it hasn't already been awarded.
- ~~Does the atlas intend just a 1-year badge, or should the mechanism be built generically for N-year milestones from the start (ties into the loyalty-rewards feature at 2 years)?~~ → **Decision: Generic N-year from the start.** Define achievement definitions for 1-year and 2-year milestones. The engine evaluates `installDate + N years` for each defined milestone. Adding 3-year, 5-year, etc. later is just adding new definitions — no engine change needed.

## Edge Cases & 3-4 Year Considerations
- **Install date is null (legacy users):** If a user upgraded from a version without `installDate`, the field will be null. On first launch after upgrade, set `installDate` to `DateTime.now()` and log it. This means legacy users get a "fresh start" for anniversary purposes — an acceptable trade-off since retrospective install dates can't be reliably inferred.
- **Multiple milestones on the same day:** A user who installs on day 0 and opens the app 2 years later (having not opened for a year) should receive both the 1-year and 2-year badges in a single evaluation pass. The engine must evaluate all N-year milestones in ascending order and award any that have been crossed.
- **Badge re-awarding:** The engine must check the `achievements` table before awarding — if a 1-year badge already exists for this user, do not award again. Use `installDate + N years` as the unique key for each milestone.
- **Pause interaction:** If a user paused a module (Spec 04), the anniversary badge is unaffected — it tracks tenure, not activity. The badge should be awarded regardless of pause state.
- **Data export/import:** If a user exports data and imports on a new device, the `installDate` must be preserved in the export. If it's not (e.g., older export format), the import should fall back to `DateTime.now()`.
- **Year 3+ evaluation cost:** After 3–4 years, the engine evaluates 3+ milestones per app open. This is trivially cheap (date comparisons), but the achievements display should group anniversary badges visually (e.g., "1 Year", "2 Year" as a single "Tenure" section) rather than listing each as a separate card.
- **Achievement engine pause interaction (cross-cutting):** When a module is paused (Spec 04), streak-related achievements freeze, but the anniversary badge is NOT streak-related — it should continue to be evaluated. The engine must distinguish between streak-dependent and tenure-dependent achievements.
- **Schema migration coordination:** This spec adds `milestone_value` to `achievements` and `installDate` to `AppSettings`. If Spec 04 (pause) or Spec 05 (recalibration) also modifies these tables, the migrations must be sequenced carefully to avoid version conflicts. Implement `installDate` in whichever spec ships first; the other depends on it.

## Acceptance Criteria
- [ ] **Install date captured:** `AppSettings` has an `installDate` field. On first launch, it is set to `DateTime.now()` (using injected clock). On subsequent launches, it remains unchanged. On upgrade from legacy (null value), it is set to `DateTime.now()` on first open.
- [ ] **Achievement definitions:** Achievement definitions exist for 1-year and 2-year milestones, each with a unique `id`, `milestone_value` (365 or 730 days), and display metadata (title, description, icon).
- [ ] **App-open evaluation:** On every app open, the achievement engine evaluates `currentDate - installDate` against each milestone definition. If the threshold has been crossed and the badge has not already been awarded, it is awarded.
- [ ] **No duplicate awards:** If a 1-year badge already exists for the user, the engine does not award it again. Each milestone is awarded exactly once.
- [ ] **Multi-milestone catch-up:** If a user opens the app for the first time in 2 years, both the 1-year and 2-year badges are awarded in the same evaluation pass.
- [ ] **Visibility:** Anniversary badges appear in the existing achievements screen alongside other achievements. No separate UI is needed.
- [ ] **Pause independence:** Anniversary badges are awarded regardless of any module's pause state. Pausing does not suppress or delay anniversary evaluation.
- [ ] **Export/import:** The `installDate` field is included in data exports and preserved on import. If missing from an older export format, it defaults to `DateTime.now()` on import.
- [ ] **No regression:** Existing achievement definitions and the module-write trigger path are unaffected.

## Effort & sequencing notes
Complexity S — one new achievement definition plus a non-module trigger path in an engine that already exists. Natural to build together with or just before the loyalty-milestone cosmetic rewards feature (#10), since both need the same install-date tracking and a similar "N years since install" evaluation.

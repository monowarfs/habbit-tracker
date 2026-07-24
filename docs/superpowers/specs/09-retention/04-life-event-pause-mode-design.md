# Life-Event Pause Mode (Travel / Illness)

**Category:** Long-Term Retention · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Streaks are motivating in week one and demoralizing in year two the first time real life interrupts them — a travel weekend, a hospital stay, a genuinely unavoidable gap — and the streak just silently breaks with no way to tell the app "this doesn't count against me." That's precisely the kind of thing that quietly convinces a long-term user the app doesn't understand their life and can push them to abandon tracking rather than face a broken streak. Letting a user explicitly declare a date range as paused, rather than have the streak math treat it as a failure, is what keeps year-two users honest without punishing them for being human.

## Goals
- Let a user mark an explicit date range (per module, or app-wide) as "paused" ahead of time or after the fact.
- Ensure streak calculations treat paused days as neutral (neither breaking nor extending a streak) rather than as misses.
- Make the paused state visible in history views so it reads as an intentional pause, not a gap or a failure.
- Support the two named cases (travel, illness) without requiring the user to explain why — the reason is not tracked, just the range.

## Non-goals / out of scope
- No automatic detection of travel or illness (e.g. via location/calendar signals) — purely user-declared.
- No partial-day pausing — whole calendar days only, matching the existing day-bucketing granularity.
- No retroactive editing of already-computed achievement records tied to streaks in this pass — that reconciliation is an open question, not a committed goal.
- No pause reasons/categories UI — a single generic "pause" concept covers both travel and illness.

## Proposed approach (high-level)
Each module's streak calculator (the Water streak use case and its Prayer/Medicine equivalents) already walks a day-by-day history to determine consecutive completion. Introduce a shared concept of a "paused range" that these calculators consult so a day inside a paused range is skipped in the streak walk rather than evaluated as a hit or miss — conceptually the same as how a rest day might already be excluded, generalized to a user-declared range instead of a fixed weekly pattern. This is a data-model and streak-calculator change more than a UI-heavy one: a simple date-range record (per module or global) that the day-status/streak logic reads alongside existing history, plus a small settings surface to create/edit/cancel a pause. Dashboard and history views need to render paused days distinctly from both "done" and "missed" so users see the pause reflected honestly.

## Dependencies & prerequisites
- The Water streak use case and the equivalent Prayer/Medicine streak calculators — all three need to consult the same pause concept for consistent behavior.
- The day-status/history rendering used by the dashboard and each module's history/calendar views, to show paused days distinctly.
- **Cross-cutting gap (ModuleDayStatusKind):** No `paused` variant exists in `ModuleDayStatusKind` today — this spec must add it alongside the existing `done`/`missed`/`upcoming` variants before any UI or streak work can reference it.
- **Cross-cutting gap (streak calculators):** Current streak calculators (`CalculateWaterStreakUseCase`, `calculateAdherence` for Medicine, Prayer streak logic) have no pause awareness — each must be updated to accept and consult a pause range.
- **Cross-cutting gap (archive/pause boundary):** The archive feature (Spec 03) and this pause feature both represent "not currently active" — the archive/pause boundary must be defined to avoid overlap: archive = indefinite suspension, pause = bounded date range with intent to resume.
- **Cross-cutting gap (schema migration):** A new `pause_ranges` table requires a Drift schema migration with a clear version bump and downgrade-free migration path.

## Resolved Dependencies
Prerequisites that must be built **before** this spec can be implemented:
1. `ModuleDayStatusKind.paused` variant added to the existing `ModuleDayStatusKind` enum (codebase-wide).
2. Archive/pause boundary decision documented — archive is indefinite suspension; pause is bounded date range with streak-neutral behavior.
3. All three streak calculators (Water, Medicine, Prayer) refactored to accept an optional pause-range parameter.
4. Drift schema migration for the new `pause_ranges` table (one table, global or per-module depending on scoping decision below).

## Open questions for the implementation round
- ~~Should pause be app-wide only, or can a user pause just Medicine while continuing Water and Prayer?~~ → **Decision: Per-module pause.** A pause is scoped to a single module. The UI presents a module selector when creating a pause. App-wide pausing can be a future enhancement by creating one pause per active module simultaneously.
- ~~Does declaring a pause need to happen only in advance, or can it be backfilled after the fact once the user is back?~~ → **Decision: Both.** Users can create a future-dated pause or backfill a past pause. Backfilled pauses require a confirmation dialog ("This will mark days X–Y as paused, adjusting your streak. Continue?").
- ~~How do achievements that were mid-progress during a pause reconcile — frozen and resumed, or recalculated as if the pause days didn't exist?~~ → **Decision: Frozen and resumed.** Achievement progress pauses when the module pauses and resumes when the module resumes. The achievement engine must be updated to consult pause ranges (cross-cutting gap — Spec 06 achievement engine update is a prerequisite).
- ~~Does notification scheduling need to suppress reminders during a paused range too, or is that an independent user action (e.g. separately snoozing notifications)?~~ → **Decision: Automatically suppress.** Creating a pause automatically suppresses all pending notifications for that module during the pause range. No separate notification snooze action required. When the pause ends, the notification planner re-plans on the next app resume.

## Edge Cases & 3-4 Year Considerations
- **Overlapping pauses:** Two pauses for the same module cannot overlap. The create-pause UI must reject or merge overlapping ranges. After 3–4 years, a user may have accumulated many pause records — consider a monthly/yearly summary that groups them rather than showing every individual range.
- **Pause during an active streak:** Pausing mid-streak must preserve the streak count. The streak calculator must remember the pre-pause streak length and resume counting from that point, not from zero.
- **Pause near a streak milestone:** A user pausing on day 29 of a 30-day streak must not lose the milestone. The calculator must treat the pause as neutral and award the milestone when the user resumes and completes the next day.
- **Multiple consecutive pauses:** After 3–4 years, a user may pause repeatedly (e.g., seasonal travel). The system must handle N pause ranges without performance degradation — the streak calculator should use efficient range intersection, not linear scan over all pause records.
- **Pause backfill beyond retention window:** If a user tries to backfill a pause from 6 months ago, the system must handle the case where that day's data may have been pruned or aggregated — the pause still applies to streak calculation but the historical log entry may not exist.
- **Dashboard day-completion indicator:** The dashboard's day-completion indicator (done/missed/partial) must show a distinct "paused" state for days within a pause range. This requires the `ModuleDayStatusKind.paused` variant to be recognized by the dashboard rendering logic.
- **Achievement re-evaluation trigger:** When a pause is created or cancelled, the achievement engine must be notified to re-evaluate any streak-related achievements for the affected date range. This is a new trigger type: "pause boundary changed" — distinct from module-write triggers.
- **Year 3+ data volume:** After 3–4 years, a user could have 50+ pause records. Index `module_id + start_date` for efficient lookup during streak calculation. Consider a summary view that collapses consecutive pauses into a single display entry.
- **Timezone transitions during pause:** A pause spanning a DST transition or timezone change must not create a phantom extra/missing day — use `localDayKey` bucketing consistently.

## Acceptance Criteria
- [ ] **Schema:** A `pause_ranges` table exists with columns: `id`, `module_id`, `start_date`, `end_date`, `created_at`. Drift migration version bumped and `flutter pub get` + `build_runner` succeed.
- [ ] **ModuleDayStatusKind:** `ModuleDayStatusKind.paused` variant exists and is recognized by all three modules' day-status derivation logic.
- [ ] **Create pause:** User can create a pause for any module with a start date and end date. Overlapping pauses are rejected with a clear error message.
- [ ] **Backfill pause:** User can create a past-dated pause with a confirmation dialog. Backfilled pause affects streak calculation retroactively.
- [ ] **Streak neutrality:** Given a streak of 10 done days, a 3-day pause, and 5 more done days, the streak calculator reports a streak of 15 (not 5).
- [ ] **Dashboard indicator:** Paused days render with a distinct visual indicator (not done, not missed) in the dashboard day-completion view and each module's history calendar.
- [ ] **Notification suppression:** During a pause range, no notifications are scheduled for the paused module. When the pause ends, notifications resume on the next app resume.
- [ ] **Achievement freeze:** Achievement progress for a paused module is frozen during the pause and resumes when the pause ends.
- [ ] **Pause cancellation:** User can cancel an in-progress pause. Cancellation re-enables notifications and resumes streak calculation from the next day.
- [ ] **No regression:** Existing streak calculations for non-paused modules are unaffected (no pause parameter = no behavioral change).

## Effort & sequencing notes
Complexity M — touches three modules' streak logic plus history rendering, but the core idea (a date range the streak walk treats as neutral) is a single well-scoped concept applied consistently. High retention impact justifies prioritizing this over most of the rest of the category; natural pairing with the habit-archive/revive feature (#3) since both are about "this isn't currently active, and that's fine."

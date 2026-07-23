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
- Decide whether pause is app-wide (all modules) or per-module — affects whether this is one new table or one per module.

## Open questions for the implementation round
- Should pause be app-wide only, or can a user pause just Medicine while continuing Water and Prayer?
- Does declaring a pause need to happen only in advance, or can it be backfilled after the fact once the user is back?
- How do achievements that were mid-progress during a pause reconcile — frozen and resumed, or recalculated as if the pause days didn't exist?
- Does notification scheduling need to suppress reminders during a paused range too, or is that an independent user action (e.g. separately snoozing notifications)?

## Effort & sequencing notes
Complexity M — touches three modules' streak logic plus history rendering, but the core idea (a date range the streak walk treats as neutral) is a single well-scoped concept applied consistently. High retention impact justifies prioritizing this over most of the rest of the category; natural pairing with the habit-archive/revive feature (#3) since both are about "this isn't currently active, and that's fine."

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

## Resolved Dependencies

These prerequisites must be built before this spec can be implemented:

1. **`ModuleDayStatusKind.paused` variant** — Archived items must not count as "missed" in day-status calculations. The `paused` variant (shared with Spec 01) must exist in `core/reports/` before archive logic touches streak/status math.
2. **Pause-aware streak calculators** — `CalculateWaterStreakUseCase`, `calculateAdherence` (Medicine), and Prayer's streak calculator must accept paused dates. This is shared infrastructure: Spec 01 (yearly recap) also needs it.
3. **Archive/pause boundary definition** — The codebase has no defined boundary between "archive" (long-term, reversible, user-initiated) and "pause" (short-term, temporary). This spec must define: archive = explicit user action on a schedule/goal; pause = implicit when archived (streaks exclude archived period). The `ModuleDayStatusKind.paused` variant maps to "archived item, not a separate pause action."
4. **Schema migration** — New `archived_at` column (nullable `DateTime`) on `medicine_schedules` and `water_goals` tables, distinct from the existing `deleted_at`. Drift migration step required.
5. **Notification cancellation on archive** — When a medicine schedule is archived, its pending notifications must be cancelled immediately via `NotificationService.cancel()`. This requires the notification service to support cancellation by schedule/goal ID, not just by notification ID.

## Dependencies & prerequisites

- The existing soft-delete `deleted_at` columns and the query-filtering convention they've established.
- Medicine's schedule-activation logic and Water's goal-resolution logic, both of which need to treat a revived item exactly like a freshly created one for date/notification purposes.
- The notification planner, since reviving a medicine schedule needs to re-enter it into the pending-notification pipeline.
- A UI surface (likely inside each module's settings or a dedicated "archived items" screen) to list and revive archived entries.
- **Cross-cutting gap:** `ModuleDayStatusKind.paused` variant for streak/status exclusion (see Resolved Dependencies #1).
- **Cross-cutting gap:** Pause-aware streak calculators (see Resolved Dependencies #2).
- **Cross-cutting gap:** Archive vs. pause boundary definition (see Resolved Dependencies #3).
- **Cross-cutting gap:** Drift schema migration for `archived_at` columns (see Resolved Dependencies #4).
- **Cross-cutting gap:** Notification cancellation by schedule/goal ID on archive (see Resolved Dependencies #5).

## Edge Cases & 3–4 Year Considerations

- **Archived item with in-flight doses:** If a user archives a Medicine schedule at 2 PM and there's a `due` dose at 3 PM, that dose must be marked as `skipped` (or a new `cancelled` status) at the moment of archival, not left dangling as `due`.
- **Reviving after a long gap:** If a user archives a Water goal for 18 months and revives it, the streak calculator must NOT try to bridge the gap — reviving starts a new streak. The old streak is preserved in historical data.
- **Multiple archives/revives:** A user may archive and revive the same schedule 5+ times over 3 years. Each revive must be idempotent: re-register notifications, recompute next-due dates, start fresh streak. No "resume from where you left off" logic.
- **Archived items in reports/stats:** Archived items' historical data must appear in past reports. A note like "(Archived)" should appear next to the item name in historical views, but data is fully preserved.
- **Schema migration for `archived_at`:** Existing soft-deleted rows have `deleted_at` set. New `archived_at` column defaults to `NULL` (active). Migration must not accidentally archive existing active items.
- **Whole-module archive not supported in v1:** Per spec scope, archiving is per-schedule/per-goal. If a user wants to "stop Water entirely," they archive each Water goal individually. A whole-module archive is a future consideration but not in this spec.
- **Conflict with `deleted_at`:** If a row has both `archived_at` and `deleted_at` set, `deleted_at` wins — the item is fully removed, not archived. Repository queries must check `deleted_at` first.
- **Year 3+ data volume:** Users with 3+ years of archived items must not slow down the archived-items list. Index `archived_at` column and paginate the archived-items query.

## Acceptance Criteria

- [ ] User can archive a Medicine schedule or Water goal via a clearly labeled "Archive" action in the item's detail/settings screen.
- [ ] Archived items are hidden from all active views (checklist, quick-add, pending notifications) but visible in a dedicated "Archived" list.
- [ ] Archived items display the archive date and retain all historical logs/doses/goal data.
- [ ] Reviving an archived item restores its exact prior configuration (schedule, goal amount, reminders) and re-enters it into the notification pipeline.
- [ ] Reviving starts a fresh streak — no attempt to bridge the archived gap.
- [ ] In-flight doses (`due`/`upcoming`) are marked `skipped` (or equivalent) at the moment of archival.
- [ ] Pending notifications for an archived schedule are cancelled immediately via `NotificationService.cancel()`.
- [ ] `ModuleDayStatusKind.paused` variant exists and is applied to days where the archived item was the only active item.
- [ ] `archived_at` column exists on `medicine_schedules` and `water_goals` with Drift migration.
- [ ] Archived items' data appears correctly in historical reports with "(Archived)" label.
- [ ] Archive action requires confirmation dialog ("Archive [item name]? You can revive it later.").
- [ ] en/bn localization strings added for archive/revive UI, confirmation dialog, and archived-items list.
- [ ] The feature is scoped to Water and Medicine only (Prayer excluded per spec).

## Open questions for the implementation round

- ~~Should archiving pause notifications immediately, or only at next materialization cycle?~~ → **Resolved:** Immediately. Call `NotificationService.cancel()` for all pending notifications of the archived schedule at the moment of archival. Waiting until the next materialization cycle leaves a gap where the user receives a notification for a schedule they thought they archived.
- ~~Does archiving a medicine schedule need to reconcile in-flight doses?~~ → **Resolved:** Yes. Any `due` or `upcoming` doses for today (or within the grace window) must be marked `skipped` at the moment of archival. Doses in the past that are already `done`/`skipped`/`missed` are left untouched.
- ~~Is "archived" per-schedule/per-goal or whole-module?~~ → **Resolved:** Per-schedule/per-goal only in v1. Whole-module archive is out of scope — users archive individual items, not entire modules.
- ~~How does revive interact with streak math?~~ → **Resolved:** Reviving always starts a fresh streak. The archived period is excluded from streak calculations (via `ModuleDayStatusKind.paused`), but reviving does NOT resume the pre-archive streak. Historical streak data is preserved; the new streak begins on the revive date.

## Effort & sequencing notes
Complexity M — new lifecycle state plus reactivation logic across two modules, but built on an established soft-delete pattern rather than a novel one. Reasonable to sequence after or alongside the life-event pause mode feature (#4), since both touch "streak math when something isn't currently active." **Must be sequenced after** `ModuleDayStatusKind.paused` variant (Resolved Dependencies #1) and pause-aware streak calculators (Resolved Dependencies #2) are in place.

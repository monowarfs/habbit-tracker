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

## Resolved Dependencies

These prerequisites must be built before this spec can be implemented:

1. **`installDate` entity field** — No `installDate` exists on any user/app entity today. A new `install_date` column must be added to `app_settings` (or a new `user_profile` table) with a migration that seeds the value to `DateTime.now()` for existing installs. This is shared infrastructure: Spec 02 (nudge inactivity) and Spec 06 (anniversary badge) also need it.
2. **`ModuleDayStatusKind.paused` variant** — The `ModuleDayStatusKind` enum in `core/reports/` currently has `complete`/`partial`/`missed` only. A `paused` variant is needed so days where all modules are paused do not count as "missed" in streak or recap calculations. This is shared infrastructure: Spec 03 (archive) also needs it.
3. **Pause-aware streak calculators** — `CalculateWaterStreakUseCase`, `calculateAdherence` (Medicine), and the Prayer streak calculator currently treat any non-logged day as broken. Each must accept a `pausedDates: Set<LocalDate>` parameter and exclude those from streak continuity. This is shared infrastructure: Spec 03 also needs it.
4. **Cross-module year summary data shape** — No shared type exists for aggregating a full year of per-module stats. A `YearSummary` Freezed class with per-module sub-objects (water total ml, medicine adherence %, prayer on-time %, longest streaks) must be defined in `core/reports/` and populated by each module's aggregation use case.
5. **Schema migration** — `install_date` addition to `app_settings` requires a Drift migration step in `schema_version.dart`.

## Dependencies & prerequisites

- Reports module's aggregation/streak use cases (per-module, already exist for Water; Prayer/Medicine equivalents).
- A recap-card renderer/screen (reuse whatever the Reports screen already uses for period charts).
- Enough historical data to make the recap non-empty — needs a graceful "not enough data yet" fallback for users under a year old.
- `module_registry.dart` to iterate all installed modules generically rather than hard-coding Water/Medicine/Prayer.
- **Cross-cutting gap:** `installDate` field must exist on `app_settings` (see Resolved Dependencies #1).
- **Cross-cutting gap:** `ModuleDayStatusKind.paused` variant and pause-aware streak calculators (see Resolved Dependencies #2–3).
- **Cross-cutting gap:** `YearSummary` data shape in `core/reports/` (see Resolved Dependencies #4).
- **Cross-cutting gap:** Drift schema migration for the `install_date` column (see Resolved Dependencies #5).

## Edge Cases & 3–4 Year Considerations

- **Partial-year users:** A user who installs in November will not have a full calendar year by Dec 31. Trigger on rolling 365-day anniversary of `installDate` instead of calendar year boundary, with a minimum-data threshold (at least 200 days of any module activity) to avoid a trivially empty recap.
- **Multi-year users (year 2, 3, 4+):** The recap must be keyed by year number (Year 1, Year 2, …) not by calendar date, so a user who joined mid-2024 gets their "Year 1" in mid-2025. Store recaps by `(installYear, yearNumber)` composite key.
- **Paused/archived modules during the year:** If a user archived Medicine for 3 months, the Medicine section of the recap should show "X of Y months active" with a note, not a misleading 0% adherence. The `paused` variant in streak/status calculators feeds this.
- **Module added mid-year:** If Prayer was added in March, the recap should only cover March–December for Prayer, not show a misleading 0 for Jan–Feb.
- **Data integrity across schema migrations:** Year 3+ users will have gone through multiple Drift migrations. The recap generator must tolerate missing columns gracefully (feature-flag old data as "incomplete" rather than crashing).
- **Locale-dependent year boundaries:** Bengali calendar year differs from Gregorian. The recap must use the Gregorian calendar year for data bucketing regardless of UI locale.
- **Notification permission revoked:** If the user has disabled notifications, the recap cannot be surfaced proactively. Fallback: show the recap card on the Dashboard on first launch after the trigger date.
- **Storage growth:** Recaps are read-only historical data. Cap at 5 years of stored recaps; older ones are evicted automatically on generation.

## Acceptance Criteria

- [ ] Recap triggers exactly once per year on the rolling 365-day anniversary of `installDate`, not on calendar year boundary.
- [ ] Recap shows one "headline" stat per active module (Water: total liters; Medicine: adherence %; Prayer: on-time %) plus a combined longest-streak card.
- [ ] Modules that were paused/archived during the year display "X of Y months active" rather than 0% or misleading data.
- [ ] Modules added mid-year only show data from their addition date forward.
- [ ] A "not enough data" screen is shown if the user has fewer than 200 active days across all modules.
- [ ] Recap cards render locally with no network dependency.
- [ ] Recap is accessible after dismissal via a "Past Recaps" entry in Settings/Reports (max 5 stored).
- [ ] `installDate` column exists in `app_settings` and is seeded for existing installs via migration.
- [ ] `ModuleDayStatusKind.paused` variant exists and is excluded from streak and recap calculations.
- [ ] `YearSummary` data shape is defined and populated by all three active modules.
- [ ] The feature is toggleable via a settings switch (default: on).
- [ ] en/bn localization strings added for all recap card text and fallback screens.

## Open questions for the implementation round

- ~~What exact trigger condition~~ → **Resolved:** Rolling 365-day anniversary of `installDate` with 200-active-day minimum threshold.
- **Dismiss-and-never-show-again vs. past recaps archive:** Both — auto-show once on trigger date, dismissible, but always accessible in a "Past Recaps" list in Settings. This satisfies both the surprise delight and the revisitable memory use cases.
- Which stats are compelling enough to be the "headline" card vs. supporting detail, per module? → **Resolved (default, adjustable during implementation):**
  - Water: total liters consumed (hero) + average daily intake + days goal met.
  - Medicine: overall adherence % (hero) + doses taken/total + longest consecutive streak.
  - Prayer: on-time % (hero) + total prayers completed + current streak.
  - Combined: overall longest streak across all modules + best single day.
- ~~Should recap generation be lazy (computed once, cached) or always regenerated on view?~~ → **Resolved:** Computed once on trigger and cached as a `recaps` table row (JSON-serialized `YearSummary`). Re-generation only on explicit user action ("Refresh" button, which re-runs aggregation).

## Effort & sequencing notes
Complexity M — mostly assembly of existing aggregation logic behind a new presentation flow, not new domain logic. Natural pairing with the anniversary-badge feature (#6) since both key off install-date/tenure; consider sequencing them together since the trigger-condition logic overlaps. **Must be sequenced after** the `installDate` infrastructure is added (see Resolved Dependencies #1) and the `ModuleDayStatusKind.paused` variant is in place (see Resolved Dependencies #2).

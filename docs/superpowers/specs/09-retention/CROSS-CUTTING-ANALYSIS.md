# 09-Retention Category: Cross-Cutting Gap Analysis

**Date:** 2026-07-25
**Status:** Review Round 1 Complete — All 11 specs analyzed

## Executive Summary

All 11 specs in the 09-retention category are in "Draft — high-level planning" status. After three parallel review passes, the following critical cross-cutting gaps were identified that affect multiple specs and must be resolved before any spec moves to implementation-ready status.

---

## Critical Infrastructure Gaps (Blocking Multiple Specs)

### 1. No `installDate` / Tenure Tracking Exists
**Affects:** Specs 01, 06, 09, 10
**Severity:** CRITICAL — Blocks 4 specs
**Current State:** No `installDate`, `firstLaunchAt`, `install_date`, or `tenure` field exists anywhere in the codebase. The `onboardingCompletedAt` field on `AppSettings` is nullable and represents onboarding completion, not first launch.
**Resolution Required:** Add `installDate` (INTEGER, nullable, set-once) to `app_settings` table. Capture at first app launch in `main.dart` or `settings_repository_impl.dart`'s `_ensureSeeded()`. Include in `BackupEnvelope` for backup/restore persistence.
**Sequencing:** Must be built first — it is a prerequisite for Specs 01, 06, 09, and 10.

### 2. No Module Enable/Disable Mechanism
**Affects:** Spec 07
**Severity:** HIGH — Blocks entire spec
**Current State:** `module_registry.dart` unconditionally creates all modules. `buildHabitModules()` has no enable/disable concept. `StatefulShellRoute` in `app_router.dart` has fixed branches for all 3 modules. `dashboard_screen.dart` iterates all modules unconditionally.
**Resolution Required:** Add `enabledModules` (JSON list of module IDs) to `app_settings`. Modify `module_registry.dart` to filter by enabled state. Update `StatefulShellRoute` to conditionally include branches. Update `dashboard_screen.dart` and `settings_home_screen.dart` to filter.
**Sequencing:** Must be built as part of Spec 07 implementation.

### 3. No Cross-Module "Last Activity" Signal
**Affects:** Spec 02
**Severity:** HIGH — Blocks spec
**Current State:** No `lastActivityAt` column exists. Activity is scattered across `water_logs`, `medicine_doses`, `prayer_records` tables. A cross-table MAX query is non-trivial in Drift without a dedicated tracking column.
**Resolution Required:** Add `lastActivityAt` (INTEGER, nullable) to `app_settings`. Update on every write across all modules (Water log, Medicine dose, Prayer record). Or create a helper that queries all three log tables and computes MAX (less efficient but no schema change).
**Sequencing:** Required for Spec 02.

### 4. No `paused` Variant in `ModuleDayStatusKind`
**Affects:** Specs 01, 03, 04
**Severity:** HIGH — Breaks streak/recap/calendar behavior
**Current State:** `ModuleDayStatusKind` has `complete`, `partial`, `missed`, `none`. No `paused` variant exists.
**Resolution Required:** Add `paused` to the enum. Update all consumers: `habit_heatmap_calendar.dart`, `global_month_calendar.dart`, `day_status_streaks.dart`, `aggregate_report_usecase.dart`, and all three modules' `dayStatus()` implementations.
**Sequencing:** Required before or as part of Spec 04.

### 5. Streak Calculators Have No Pause Awareness
**Affects:** Specs 01, 03, 04
**Severity:** HIGH — All streak-dependent specs break
**Current State:** `longestStreak()` and `currentStreak()` in `day_status_streaks.dart` treat non-`complete` days as streak breaks. `CalculateWaterStreakUseCase` and `CalculatePrayerStreakUseCase` do not accept pause data.
**Resolution Required:** Modify streak calculators to accept `pausedRanges` parameter. Paused days are skipped in the streak walk (neither breaking nor extending).
**Sequencing:** Required for Spec 04; affects Specs 01 and 03.

---

## High-Priority Gaps (Spec-Specific)

### 6. Achievement Engine Has No Cross-Cuttedness Support
**Affects:** Specs 06, 10
**Severity:** HIGH
**Current State:** `AchievementEngine.evaluate(String moduleId)` looks up a module by `moduleId`. `AchievementDefinition` requires `moduleId` as non-nullable. Anniversary/tenure achievements have no owning module.
**Resolution Required:** Add a special `moduleId` convention (e.g., `'_system'`) or add `evaluateGlobal()` method. Update `AchievementDefinition` to support system-level achievements.

### 7. No Archive/Pause Boundary Defined
**Affects:** Specs 03, 04
**Severity:** HIGH
**Current State:** Both specs handle "temporarily inactive" with overlapping scope. No defined boundary between archive (permanent removal with possible revival) and pause (temporary date-range exclusion).
**Resolution Required:** Define clear semantics:
- **Archive:** For items that may never return (finished prescription, abandoned goal). Preserves configuration but hides from active views. Revivable.
- **Pause:** For temporary absence (travel, illness). Excludes date range from streak math. Auto-expires or user-ended.
- **Interaction:** Pausing an archived item is invalid (it's already inactive). Reviving a paused item ends the pause.

### 8. No Re-Engagement Nudge Injection Point
**Affects:** Spec 02
**Severity:** HIGH
**Current State:** All notification candidates come from per-module `pendingNotifications()`. The re-engagement nudge is cross-module by design and does not fit this contract.
**Resolution Required:** Inject at the `planAndApplyNotifications()` level as a separate code path. The nudge needs a sentinel `moduleId` (e.g., `'_system'`) and the action handler must handle it without dispatching to a module.

### 9. No Cross-Module "Year Summary" Data Shape
**Affects:** Spec 01
**Severity:** MEDIUM
**Current State:** Each module's aggregation is independent with different value units (ml for Water, doses for Medicine, prayers for Prayer). No uniform "year in review" data shape exists.
**Resolution Required:** Define a `YearRecapStats` data class per module with standardized fields (totalTracked, bestDay, longestStreak, onTimePercentage). The recap renderer translates raw values into module-specific display text.

### 10. No Schema Migration Mentioned
**Affects:** All specs requiring DB changes (01, 02, 03, 04, 05, 06, 07, 10)
**Severity:** MEDIUM
**Current State:** Current schema version is 9. No spec mentions migration.
**Resolution Required:** Each spec requiring new columns/tables must specify the migration step (`if (from < N) ...` in `app_database.dart`).

---

## Medium-Priority Gaps

### 11. No Acceptance Criteria on Any Spec
**Affects:** All 11 specs
**Severity:** MEDIUM
**Current State:** Zero measurable done-conditions across all specs.
**Resolution Required:** Add acceptance criteria section to each spec with testable conditions.

### 12. No Dashboard Day-Completion Indicator Behavior for Paused/Archived
**Affects:** Specs 03, 04
**Severity:** MEDIUM
**Current State:** `_DayCompletionIndicator` counts modules where `today` is `complete`. Paused/archived modules would show misleadingly.
**Resolution Required:** Define behavior: exclude paused modules from the count, or show a distinct "paused" state.

### 13. No Achievement Re-Evaluation Trigger for Pause/Archive
**Affects:** Specs 03, 04
**Severity:** MEDIUM
**Current State:** Achievement engine is called from module write paths. No trigger for "pause was added/removed."
**Resolution Required:** Re-evaluate achievements when pause/archive state changes.

### 14. Notification Ledger Unbounded Growth
**Affects:** Spec 11 (and future)
**Severity:** MEDIUM
**Current State:** No pruning, no archival, no size discussion. Could reach 30,000+ rows after 3 years.
**Resolution Required:** Acknowledge in Spec 11's guarantee. Consider eventual archival strategy.

### 15. Near-Duplicate Privacy Copy
**Affects:** Specs 08, 11
**Severity:** LOW
**Current State:** Both add trust-building copy to adjacent settings surfaces with no harmonization.
**Resolution Required:** Coordinate copy between Specs 08 and 11. Consider shared string or distinct but complementary messaging.

---

## Dependency Graph (Sequencing)

```
installDate tracking (prerequisite)
├── Spec 01 (Yearly Recap)
├── Spec 06 (Anniversary Badge)
│   └── Spec 10 (Loyalty Milestone Rewards)
└── Spec 09 (Household Plan — also needs multi-profile)

ModuleDayStatusKind.paused + pause-aware streak calculators
├── Spec 04 (Life-Event Pause Mode)
│   └── Spec 03 (Archive/Revive — interacts with pause)
└── affects Spec 01 (Recap needs pause-aware dayStatus)

lastActivityAt tracking
└── Spec 02 (Re-Engagement Nudge)

Module enable/disable mechanism
└── Spec 07 (Progressive Module Unlock)

Achievement engine cross-cutting support
└── Spec 06 (Anniversary Badge)
    └── Spec 10 (Loyalty Milestone Rewards)

Copy additions (independent)
├── Spec 08 (Data Reassurance)
└── Spec 11 (Data Longevity — also needs audit)

Spec 09 (Household Plan) — blocked on multi-profile + Premium
```

---

## Recommended Implementation Order (3-4 Year Roadmap)

### Phase 1: Foundation (Run 16-17)
1. Install-date tracking (prerequisite for 4 specs)
2. `ModuleDayStatusKind.paused` + pause-aware streak calculators
3. `lastActivityAt` tracking
4. Module enable/disable mechanism

### Phase 2: Core Retention Features (Run 18-19)
5. Spec 04: Life-Event Pause Mode
6. Spec 02: Gentle Re-Engagement Nudge
7. Spec 03: Habit Archive with Revive Flow
8. Spec 05: Quarterly Goal-Recalibration Prompt

### Phase 3: Celebration & Trust (Run 20-21)
9. Spec 06: Anniversary Badge
10. Spec 01: Yearly Recap
11. Spec 08: Data Reassurance
12. Spec 11: Data Longevity Guarantee

### Phase 4: Advanced Retention (Run 22+, Year 2+)
13. Spec 10: Loyalty Milestone Cosmetic Rewards
14. Spec 07: Progressive Module Unlock Onboarding
15. Spec 09: Household/Family Plan (blocked on multi-profile + Premium)

---

## Next Steps

1. Update each spec with gaps addressed (acceptance criteria, edge cases, dependencies, 3-4 year considerations)
2. Create detailed implementation plan with low-level tasks
3. Verify implementation plan against codebase

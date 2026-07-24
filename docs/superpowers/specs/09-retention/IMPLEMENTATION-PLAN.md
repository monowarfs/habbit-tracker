# 09-Retention Category: Implementation Plan

**Date:** 2026-07-25
**Status:** Implementation-Ready (verified against codebase)
**Scope:** 11 specs across 4 phases, estimated 8-10 feature runs

---

## Phase 1: Foundation Infrastructure (Run 16-17)

These are cross-cutting infrastructure pieces that multiple specs depend on. They must be built first.

### Run 16: Install-Date Tracking + ModuleDayStatusKind.paused

**Goal:** Add the two foundational data points that 6+ specs depend on.

#### Task 16.1: Add `installDate` to `app_settings`
- **File:** `lib/core/database/tables/app_settings_table.dart`
  - Add `IntColumn get installDate => integer().nullable()('install_date');`
  - Note: All timestamps in this table use `IntColumn` (UTC epoch millis), not `DateTimeColumn`. The domain entity (`AppSettings`) converts via `_toDomain` mapper.
- **File:** `lib/core/database/app_database.dart`
  - Bump `schemaVersion` from 9 to 10
  - Add migration: `if (from < 10) { await m.addColumn(appSettings, appSettings.installDate); }`
- **File:** `lib/features/settings/domain/entities/app_settings.dart`
  - Add `DateTime? installDate` field to `AppSettings` Freezed class
- **File:** `lib/features/settings/domain/repositories/settings_repository.dart`
  - Add `Future<void> updateInstallDate(DateTime date)` to abstract interface
- **File:** `lib/features/settings/data/repositories/settings_repository_impl.dart`
  - In `_ensureSeeded()`, set `installDate` to `clock.now().millisecondsSinceEpoch` if null
  - Implement `updateInstallDate()` — writes millis to DB, updates in-memory cache
- **File:** `lib/main.dart`
  - In `main()`, after `ProviderContainer` creation, call `settingsRepository.updateInstallDate()` if not already set
- **Tests:** `test/features/settings/` — verify installDate is set on first launch, not overwritten on subsequent launches
- **Commit:** `feat: add installDate tracking to app_settings`

#### Task 16.2: Add `ModuleDayStatusKind.paused` variant
- **File:** `lib/core/modules/habit_module.dart`
  - Add `paused` to `ModuleDayStatusKind` enum
- **File:** `lib/core/reports/day_status_streaks.dart`
  - Update `longestStreak()` and `currentStreak()` to accept `Set<LocalDate> pausedDays` parameter
  - Paused days are skipped in streak walk (neither breaking nor extending)
- **File:** `lib/core/reports/aggregate_report_usecase.dart`
  - Update `execute()` to accept and exclude paused days from aggregation
- **File:** `lib/features/water/domain/usecases/calculate_water_streak.dart`
  - Add `pausedDays` parameter to `CalculateWaterStreakUseCase`
- **File:** `lib/features/prayer/domain/usecases/calculate_prayer_streak.dart`
  - Add `pausedDays` parameter to `CalculatePrayerStreakUseCase`
- **File:** `lib/features/medicine/domain/usecases/calculate_adherence.dart`
  - Add `pausedDays` parameter to `calculateAdherence()`
- **File:** `lib/core/widgets/habit_heatmap_calendar.dart`
  - Add `paused` case to `_colorFor()` with a distinct neutral color (e.g., striped pattern or light gray)
  - Update `heatmapAlphaFor()` to handle `paused`
- **File:** `lib/core/widgets/global_month_calendar.dart`
  - Add `paused` case to `combinedDayStatusKind()`
- **Tests:** `test/core/reports/` — verify paused days are excluded from streak calculations
- **Commit:** `feat: add ModuleDayStatusKind.paused variant and pause-aware streak calculators`

#### Task 16.3: Add `lastActivityAt` tracking
- **File:** `lib/core/database/tables/app_settings_table.dart`
  - Add `IntColumn get lastActivityAt => integer().nullable()('last_activity_at');`
- **File:** `lib/core/database/app_database.dart`
  - Include in schema version 10 migration
- **File:** `lib/features/settings/domain/entities/app_settings.dart`
  - Add `DateTime? lastActivityAt` field
- **File:** `lib/features/settings/domain/repositories/settings_repository.dart`
  - Add `Future<void> recordActivity()` to abstract interface
- **File:** `lib/features/settings/data/repositories/settings_repository_impl.dart`
  - Implement `recordActivity()` — writes `clock.now().millisecondsSinceEpoch` to `lastActivityAt`
- **File:** `lib/core/notifications/last_activity_repository.dart` (new)
  - Simple wrapper: `Future<DateTime?> getLastActivity()` reads from `app_settings`
  - Delegates to `SettingsRepository.recordActivity()` for writes
- **Files:** `lib/features/water/data/repositories/water_repository_impl.dart`, `lib/features/medicine/data/repositories/medicine_repository_impl.dart`, `lib/features/prayer/data/repositories/prayer_repository_impl.dart`
  - **Design note:** These repositories don't currently depend on `SettingsRepository`. Two options:
    - **Option A (preferred):** Inject `SettingsRepository` via constructor. Each module's repository already takes `AppDatabase`; add `SettingsRepository` as a second parameter.
    - **Option B:** Each module's presentation controller calls `recordActivity()` after repository writes. This keeps domain/data layers clean but requires controller changes.
  - After each write operation, call `settingsRepository.recordActivity()`
- **Tests:** `test/core/notifications/` — verify lastActivityAt updates on each module write
- **Commit:** `feat: add cross-module lastActivityAt tracking`

### Run 17: Module Enable/Disable + Archive Data Model

**Goal:** Add module visibility control and archive data model.

#### Task 17.1: Add module enable/disable mechanism
- **File:** `lib/core/database/tables/app_settings_table.dart`
  - Add `TextColumn get enabledModules => text().withDefault(const Constant('["water","medicine","prayer"]'))('enabled_modules');` (JSON array)
- **File:** `lib/core/database/app_database.dart`
  - Bump `schemaVersion` from 10 to 11
  - Add migration: `if (from < 11) { await m.addColumn(appSettings, appSettings.enabledModules); }`
- **File:** `lib/features/settings/domain/entities/app_settings.dart`
  - Add `List<String> enabledModules` field with default `['water', 'medicine', 'prayer']`
- **File:** `lib/features/settings/domain/repositories/settings_repository.dart`
  - Add `Future<void> toggleModule(String moduleId, bool enabled)` to interface
  - Add `bool isModuleEnabled(String moduleId)` to interface
- **File:** `lib/features/settings/data/repositories/settings_repository_impl.dart`
  - Implement `toggleModule()` and `isModuleEnabled()`
- **File:** `lib/core/modules/module_registry.dart`
  - Add `enabledModulesProvider` Riverpod provider (reads from `settingsRepositoryProvider`)
  - **DO NOT modify `buildHabitModules()`** — this function is used by background isolate and WorkManager callback, which need ALL modules regardless of enabled state
  - Create `visibleModulesProvider` that filters modules by enabled state for UI use
- **File:** `lib/core/router/app_router.dart`
  - `StatefulShellRoute` branches filter by `visibleModulesProvider`
- **File:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
  - Use `visibleModulesProvider` instead of `habitModulesProvider`
- **Tests:** `test/core/modules/` — verify module filtering works for UI, all modules still available for background
- **Commit:** `feat: add module enable/disable mechanism`

#### Task 17.2: Add archive data model
- **File:** `lib/features/water/data/tables/water_goals_table.dart`
  - Add `IntColumn get archivedAt => integer().nullable()('archived_at');`
  - Note: `water_goals` already has `deletedAt` for soft-delete. `archivedAt` is semantically different: archived = hidden but restorable, deleted = gone.
- **File:** `lib/features/medicine/data/tables/medicine_schedules_table.dart`
  - Add `IntColumn get archivedAt => integer().nullable()('archived_at');`
  - Note: `medicine_schedules` already has `deletedAt`. Also note that `medicines_table.dart` already has `archivedAt` at the medicine level — this is a different concept (schedule-level archive vs. medicine-level archive).
- **File:** `lib/core/database/app_database.dart`
  - Include in schema version 11 migration
- **File:** `lib/features/water/domain/entities/water_goal.dart`
  - Add `DateTime? archivedAt` field
- **File:** `lib/features/medicine/domain/entities/medicine_schedule.dart`
  - Add `DateTime? archivedAt` field
- **File:** `lib/features/water/data/repositories/water_repository_impl.dart`
  - Add `archiveGoal(String goalId)` method
  - Add `reviveGoal(String goalId)` method
  - Add `getArchivedGoals()` method
  - Update `allGoals()` to exclude archived goals (add `archivedAt.isNull()` filter)
- **File:** `lib/features/medicine/data/repositories/medicine_repository_impl.dart`
  - Add `archiveSchedule(String scheduleId)` method
  - Add `reviveSchedule(String scheduleId)` method
  - Add `getArchivedSchedules()` method
  - Update `allSchedules()` to exclude archived schedules
- **File:** `lib/features/medicine/domain/usecases/schedule_activity.dart`
  - Update `isScheduleActive()` to also check `archivedAt` — archived schedules are not active
  - Note: Water has no equivalent `isScheduleActive` usecase; water goal resolution uses `ResolveGoalForDateUseCase` which queries `allGoals()` (already filtered by archive status)
- **Tests:** `test/features/water/`, `test/features/medicine/` — verify archive/revive lifecycle
- **Commit:** `feat: add archive data model for water goals and medicine schedules`

---

## Phase 2: Core Retention Features (Run 18-19)

### Run 18: Life-Event Pause Mode + Re-Engagement Nudge

**Goal:** Implement the two highest-impact retention features.

#### Task 18.1: Life-Event Pause Mode (Spec 04)
- **File:** `lib/core/pause/pause_range.dart` (new)
  - `PauseRange` Freezed class: `id`, `moduleId` (nullable for app-wide), `startDate`, `endDate`, `reason` (optional, not displayed)
- **File:** `lib/core/database/tables/pause_ranges_table.dart` (new Drift table)
  - Columns: `id` (text, pk), `module_id` (text, nullable), `start_date` (integer — millis), `end_date` (integer — millis), `created_at` (integer — millis)
- **File:** `lib/core/database/app_database.dart`
  - Add `PauseRanges` table to `@DriftDatabase`
  - Bump `schemaVersion` from 11 to 12
  - Add migration for new table
- **File:** `lib/core/pause/pause_repository.dart` (new)
  - `createPause(PauseRange range)` — validate no overlap with existing pauses
  - `cancelPause(String pauseId)`
  - `getActivePausesForDate(LocalDate date)` — returns all pauses covering a given date
  - `getPausedDaysInRange(LocalDate start, LocalDate end)` — returns `Set<LocalDate>` for streak calculators
  - `watchPauses()` — stream for UI
- **File:** `lib/core/modules/habit_module.dart`
  - Add `Set<LocalDate> getPausedDays(LocalDate start, LocalDate end)` to `HabitModule` contract
- **Files:** Each module's `dayStatus()` implementation
  - Accept `pausedDays` parameter, return `ModuleDayStatusKind.paused` for paused days
- **File:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
  - Update `_DayCompletionIndicator` to exclude paused modules from count
- **File:** `lib/core/notifications/notification_planner.dart`
  - In `planAndApplyNotifications()`, skip notification scheduling for paused date ranges
- **File:** `lib/features/water/presentation/screens/water_settings_screen.dart` (or new screen)
  - Add "Pause Tracking" section with date range picker
- **File:** `lib/features/medicine/presentation/screens/medicine_settings_screen.dart` (or new screen)
  - Add "Pause Tracking" section
- **File:** `lib/core/widgets/habit_heatmap_calendar.dart`
  - Add paused visual treatment (striped pattern or distinct neutral color)
- **File:** `lib/core/widgets/global_month_calendar.dart`
  - Add paused rendering
- **Localization:** Add en/bn strings for pause-related UI
- **Tests:** `test/core/pause/`, `test/features/water/`, `test/features/medicine/`
- **Commit:** `feat: implement life-event pause mode`

#### Task 18.2: Gentle Re-Engagement Nudge (Spec 02)
- **File:** `lib/core/notifications/reengagement_nudge.dart` (new)
  - `ReengagementNudge` class with `evaluate()` method:
    - Read `lastActivityAt` from `app_settings`
    - If `lastActivityAt` is null OR `(clock.now() - lastActivityAt).inDays >= 7`:
      - Check if nudge already sent since last activity (query `notification_ledger` for `source_type = 'reengagement_nudge'` with `scheduled_for > lastActivityAt`)
      - If not sent, return a `PendingNotification` with system moduleId
- **File:** `lib/core/notifications/notification_planner.dart`
  - In `planAndApplyNotifications()`, after module notifications, call `ReengagementNudge().evaluate()`
  - If nudge is returned, add to pending notifications list
  - Ensure nudge has `quietHoursSuppressible: true` (gentle, not urgent)
- **File:** `lib/core/notifications/notification_action_handler.dart`
  - Handle `moduleId == '_system'` case — on tap, navigate to dashboard
  - On dismiss/snooze, no-op (single nudge, no reschedule)
- **File:** `lib/core/notifications/notification_ledger_repository.dart`
  - Add `hasNudgeFiredSince(DateTime since)` query method
- **Localization:** Add en/bn strings for nudge notification title/body
- **Tests:** `test/core/notifications/reengagement_nudge_test.dart`
- **Commit:** `feat: implement gentle re-engagement nudge after inactivity`

### Run 19: Archive/Revive UI + Quarterly Goal Recalibration

**Goal:** Complete the archive/revive user flow and add goal recalibration prompt.

#### Task 19.1: Archive/Revive UI (Spec 03)
- **File:** `lib/features/water/presentation/screens/water_archived_screen.dart` (new)
  - List archived water goals with "Revive" button
  - Empty state: "No archived goals"
- **File:** `lib/features/medicine/presentation/screens/medicine_archived_screen.dart` (new)
  - List archived medicine schedules with "Revive" button
  - Empty state: "No archived schedules"
- **File:** `lib/features/water/presentation/screens/water_settings_screen.dart`
  - Add "Archived Goals" navigation item
- **File:** `lib/features/medicine/presentation/screens/medicine_settings_screen.dart`
  - Add "Archived Schedules" navigation item
- **File:** Each module's presentation/controller
  - Add `archiveGoal/schedule()` action
  - Add `reviveGoal/schedule()` action
  - On revive: re-run activation logic (recompute next-due dates, re-register notifications)
- **File:** `lib/core/notifications/notification_planner.dart`
  - On archive: cancel all pending notifications for the archived item
  - On revive: the module's `pendingNotifications()` naturally includes the revived item
- **File:** `lib/features/reports/presentation/screens/reports_screen.dart`
  - Exclude archived items from active reports
  - Optionally add "Archived" filter toggle
- **Localization:** Add en/bn strings for archive/revive UI
- **Tests:** `test/features/water/`, `test/features/medicine/`
- **Commit:** `feat: add archive/revive UI for water goals and medicine schedules`

#### Task 19.2: Quarterly Goal-Recalibration Prompt (Spec 05)
- **File:** `lib/core/database/tables/app_settings_table.dart`
  - Add `IntColumn get lastGoalRecalibrationShownAt => integer().nullable()('last_goal_recalibration_shown_at');`
- **File:** `lib/core/database/app_database.dart`
  - Include in schema version 12 migration
- **File:** `lib/features/settings/domain/entities/app_settings.dart`
  - Add `DateTime? lastGoalRecalibrationShownAt` field
- **File:** `lib/core/goals/goal_recalibration_prompt.dart` (new)
  - `evaluateGoalRecalibration()` method:
    - Read `lastGoalRecalibrationShownAt` from settings
    - Read each module's goal last-edited timestamp
    - If `(clock.now() - lastGoalRecalibrationShownAt).inDays >= 90`:
      - Return prompt for each module whose goal hasn't been edited in 90+ days
- **File:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
  - Add `GoalRecalibrationBanner` widget at top of dashboard
  - Shows dismissible banner: "Still tracking [Water target]? [Update] [Not now]"
- **File:** `lib/features/water/presentation/screens/water_settings_screen.dart`
  - Ensure goal editing updates a `lastGoalEditedAt` timestamp (if not already tracked)
- **Localization:** Add en/bn strings for recalibration prompt
- **Tests:** `test/core/goals/`, `test/features/dashboard/`
- **Commit:** `feat: add quarterly goal-recalibration prompt`

---

## Phase 3: Celebration & Trust (Run 20-21)

### Run 20: Anniversary Badge + Data Trust Copy

**Goal:** Add tenure-based celebration and trust-building copy.

#### Task 20.1: Anniversary Badge (Spec 06)
- **File:** `lib/core/achievements/achievement_engine.dart`
  - Add `evaluateGlobal()` method for non-module achievements
  - Add trigger: on each app open, check if `installDate` anniversary has been crossed
- **File:** `lib/core/modules/habit_module.dart`
  - Add `AchievementDefinition` for system-level achievements (moduleId = `_system`)
  - Add `anniversary_1_year` definition
- **File:** `lib/core/achievements/achievement_repository.dart`
  - Add `watchByModuleAndKey(String moduleId, String key)` to check if already awarded
- **File:** `lib/core/database/app_database.dart`
  - Ensure `achievements` table has `milestone_value` column (for year number) — add in schema version 13 migration
- **File:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
  - On app open, trigger `achievementEngine.evaluateGlobal()` (once per day, not every resume)
- **Localization:** Add en/bn strings for anniversary badge title/description
- **Tests:** `test/core/achievements/`
- **Commit:** `feat: add anniversary badge for 1-year tenure`

#### Task 20.2: Data Trust Copy (Specs 08 + 11)
- **File:** `lib/features/settings/presentation/screens/data_settings_screen.dart`
  - Add `DataTrustCard` widget with two sections:
    - Section 1 (Spec 08): "Your data never left this device" — explains local-only storage
    - Section 2 (Spec 11): "Your history is never pruned" — explains data longevity guarantee
  - Consolidated into one card to avoid duplication
- **File:** `lib/core/l10n/app_en.arb`
  - Add keys: `dataTrustCardTitle`, `dataTrustCardBody`, `dataLongevityTitle`, `dataLongevityBody`
- **File:** `lib/core/l10n/app_bn.arb`
  - Add Bengali translations for all new keys
- **File:** `docs/engineering/retention-audit.md` (new)
  - Document every table's retention behavior (permanent/rolling/capped)
  - Confirm no silent pruning exists
  - Note notification_ledger FIFO eviction policy (excluded from guarantee)
- **Tests:** Widget tests for DataTrustCard rendering
- **Commit:** `feat: add data trust and longevity guarantee copy to Data settings`

### Run 21: Yearly Recap

**Goal:** Implement the year-in-review experience.

#### Task 21.1: YearSummary data shape
- **File:** `lib/core/reports/year_summary.dart` (new)
  - `YearSummary` Freezed class with per-module sub-objects:
    - `WaterYearStats`: totalMl, averageDailyMl, daysGoalMet, longestStreak
    - `MedicineYearStats`: adherencePercent, dosesTaken, dosesTotal, longestStreak
    - `PrayerYearStats`: onTimePercent, prayersCompleted, longestStreak
    - `OverallStats`: longestStreakAll, bestDay, totalActiveDays
  - `yearNumber` (1, 2, 3, ...), `installDate`, `generatedAt`
- **File:** `lib/core/reports/year_summary_repository.dart` (new)
  - `generateYearSummary(int yearNumber)` — calls each module's aggregation use cases
  - `saveYearSummary(YearSummary summary)` — persists to `recaps` table
  - `getYearSummary(int yearNumber)` — retrieves cached summary
  - `getStoredRecapYears()` — lists available recaps (max 5)
- **File:** `lib/core/database/tables/recaps_table.dart` (new Drift table)
  - Columns: `year_number` (integer, pk), `summary_json` (text), `generated_at` (integer — millis)
- **File:** `lib/core/database/app_database.dart`
  - Add `Recaps` table, bump schema version to 13
- **Tests:** `test/core/reports/year_summary_test.dart`
- **Commit:** `feat: add YearSummary data shape and repository`

#### Task 21.2: Recap presentation
- **File:** `lib/features/dashboard/presentation/screens/yearly_recap_screen.dart` (new)
  - Story-card flow: swipe through cards, one per module + combined card
  - Each card: hero stat, supporting stats, optional animation
  - "Not enough data" fallback screen (< 200 active days)
- **File:** `lib/features/dashboard/presentation/widgets/recap_card.dart` (new)
  - Reusable card widget for each module's hero stat
- **File:** `lib/core/router/app_router.dart`
  - Add `/recap` route
- **File:** `lib/main.dart`
  - In `didChangeAppLifecycleState(resumed)`, check if recap is due (rolling 365-day anniversary of installDate, once per day)
  - If due and not yet shown, navigate to `/recap`
- **File:** `lib/features/settings/presentation/screens/settings_home_screen.dart`
  - Add "Past Recaps" navigation item (max 5 stored)
- **Localization:** Add en/bn strings for all recap card text
- **Tests:** `test/features/dashboard/`
- **Commit:** `feat: implement yearly recap story-card flow`

---

## Phase 4: Advanced Retention (Run 22+, Year 2+)

### Run 22: Loyalty Milestone Cosmetic Rewards (Spec 10)

**Goal:** Add tenure-based cosmetic unlocks.

#### Task 22.1: Cosmetic unlock infrastructure
- **File:** `lib/core/achievements/cosmetic_unlock.dart` (new)
  - `CosmeticUnlock` Freezed class: `achievementKey`, `cosmeticType` (enum: themeAccent), `cosmeticValue` (String)
  - `CosmeticUnlockRepository`: `getUnlocks()`, `applyUnlock(String key)`, `getSelectedCosmetic()`
- **File:** `lib/core/database/tables/cosmetic_unlocks_table.dart` (new Drift table)
  - Columns: `achievement_key` (text, pk), `cosmetic_type` (text), `cosmetic_value` (text), `unlocked_at` (integer — millis)
- **File:** `lib/core/database/app_database.dart`
  - Add table, bump schema version to 14
- **File:** `lib/core/achievements/achievement_engine.dart`
  - Emit `Stream<AchievementEvent>` when achievements are awarded
  - Map `anniversary_2_year` achievement to cosmetic unlock
- **Tests:** `test/core/achievements/cosmetic_unlock_test.dart`
- **Commit:** `feat: add cosmetic unlock infrastructure`

#### Task 22.2: Cosmetic rewards UI
- **File:** `lib/features/settings/presentation/screens/cosmetic_unlocks_screen.dart` (new)
  - Gallery of unlocked cosmetics (theme accents)
  - "Apply" button for each, "Default" option
- **File:** `lib/features/settings/presentation/screens/settings_home_screen.dart`
  - Add "Unlocks" navigation item
- **File:** `lib/core/theme/app_theme.dart`
  - Add cosmetic accent override layer (extends `ModuleAccents`)
- **File:** `lib/core/theme/theme_controller.dart`
  - Read selected cosmetic from repository, apply accent override
- **Localization:** Add en/bn strings
- **Tests:** Widget tests for cosmetic unlocks screen
- **Commit:** `feat: add cosmetic rewards UI with theme accent support`

### Run 23: Progressive Module Unlock Onboarding (Spec 07)

**Goal:** Reshape onboarding for new users.

#### Task 23.1: Onboarding flow
- **File:** `lib/features/onboarding/presentation/screens/onboarding_welcome_screen.dart` (new)
  - Welcome screen: "Let's start with Water tracking"
- **File:** `lib/features/onboarding/presentation/screens/onboarding_water_setup_screen.dart` (new)
  - Guided water goal setup
- **File:** `lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart` (new)
  - "You're all set! We'll suggest Medicine and Prayer when you're ready."
- **File:** `lib/core/router/app_router.dart`
  - Add `/onboarding/*` routes
  - Redirect to `/onboarding` if `onboardingCompletedAt` is null
- **File:** `lib/core/database/tables/app_settings_table.dart`
  - Add `TextColumn get onboardingProgress => text().nullable()('onboarding_progress');` (JSON: current step, completed steps)
- **File:** `lib/core/database/app_database.dart`
  - Include in migration (schema version 15)
- **Tests:** `test/features/onboarding/`
- **Commit:** `feat: add progressive onboarding flow`

#### Task 23.2: Module suggestion system
- **File:** `lib/features/onboarding/presentation/widgets/module_suggestion_card.dart` (new)
  - Banner: "Ready to track Medicine? [Set up] [Not now]"
  - Appears on dashboard after 7 days + 10+ water logs
- **File:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
  - Add suggestion card logic (check onboarding progress, elapsed time, activity count)
- **File:** `lib/features/settings/presentation/screens/settings_home_screen.dart`
  - Add "Enable Modules" section with toggles for each module
- **Localization:** Add en/bn strings
- **Tests:** Widget tests for suggestion card
- **Commit:** `feat: add module suggestion system for new users`

---

## Phase 5: Household Plan (Run 24+, Year 2+, Blocked)

### Spec 09: Household/Family Plan Hook

**Status:** BLOCKED on multi-profile data model and Premium subscription infrastructure.

**Prerequisites (outside this category):**
1. Multi-profile data model (every table needs `profile_id` scoping)
2. Premium subscription/billing infrastructure
3. Profile switching UI

**When unblocked:**
- Add `profile_id` to all tables (massive migration)
- Add profile management screens
- Add household linking mechanism (device-to-device sync or shared code)
- Add family member tracking (separate data per profile)
- Position hook for year-2+ users

---

## Schema Migration Sequence

| Version | Tables Added/Modified | Specs |
|---------|----------------------|-------|
| 9 (current) | — | — |
| 10 | `app_settings`: add `install_date` (int), `last_activity_at` (int) | 01, 02, 05, 06 |
| 11 | `app_settings`: add `enabled_modules` (text); `water_goals`: add `archived_at` (int); `medicine_schedules`: add `archived_at` (int) | 03, 07 |
| 12 | `pause_ranges` (new table); `app_settings`: add `last_goal_recalibration_shown_at` (int) | 04, 05 |
| 13 | `recaps` (new table); `achievements`: add `milestone_value` (int) | 01, 06 |
| 14 | `cosmetic_unlocks` (new table) | 10 |
| 15 | `app_settings`: add `onboarding_progress` (text) | 07 |

**Note:** All migrations must be tested end-to-end: upgrade from version N-1 to N with existing data must not lose any rows. All timestamp columns use `IntColumn` (UTC epoch millis) to match existing table conventions.

---

## Verification Plan

After each run, verify:
1. `flutter analyze` — no new warnings
2. `flutter test` — all tests pass
3. `dart format --output=none --set-exit-if-changed .` — formatting check
4. Manual smoke test on Android/iOS simulator
5. Migration test: upgrade from previous schema version

After all 4 phases complete:
1. Full regression test suite
2. Performance test: database query times with 3+ years of simulated data
3. Accessibility audit: screen reader, reduced motion, color contrast
4. Localization parity check: en/bn string count match
5. Cross-spec integration test: pause + archive + streak + recap all interact correctly

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Schema migration conflicts between runs | High | Centralized migration plan (this document), version sequencing |
| Pause mode complexity breaks streak calculations | High | Extensive unit tests for streak calculators with paused days |
| Notification planner module-only contract | Medium | Extend with `_system` moduleId convention |
| Achievement engine can't handle cross-cutting achievements | Medium | Add `evaluateGlobal()` method |
| YearSummary data shape mismatch across modules | Medium | Define standardized Freezed class, enforce in tests |
| Archive/revive notification re-registration | Medium | Test revive path end-to-end with notification scheduler |
| `buildHabitModules()` filtering breaks background callers | Medium | Only filter at UI/router level, not in `buildHabitModules()` |
| Module repositories lack `SettingsRepository` dependency | Medium | Inject via constructor in Task 16.3 |
| Device storage growth over 3-4 years | Low | Monitor via retention audit, document in guarantee |
| Localization drift (en/bn mismatch) | Low | CI check for ARB key parity |

# 09-Retention Category: Consolidated Implementation Plan

**Date:** 2026-07-25
**Status:** Implementation-Ready (verified against codebase)
**Scope:** 11 specs, 81 tasks, 81 commits across 5 phases

---

## Dependency graph

```
Spec 01 (Yearly Recap) ─────────────────────────────────────────────┐
  ├─ installDate ──────────┬───────────────────────────────────────┤
  ├─ ModuleDayStatusKind.paused ─┬─────────────────────────────────┤
  └─ Pause-aware streaks ───────┤                                  │
                                │                                  │
Spec 02 (Re-engagement Nudge) ──┤ (needs installDate + paused)     │
                                │                                  │
Spec 03 (Archive/Revive) ───────┤ (needs paused + streaks)         │
                                │                                  │
Spec 04 (Life-Event Pause) ─────┤ (needs paused + streaks)         │
                                │                                  │
Spec 05 (Quarterly Recalibration) (needs installDate)              │
                                │                                  │
Spec 06 (Anniversary Badge) ────┤ (needs installDate)              │
  │                             │                                  │
  └─ Spec 10 (Cosmetic Rewards) ┤ (needs Spec 06 achievements)    │
                                │                                  │
Spec 07 (Progressive Onboarding) (independent — new system)        │
                                                                ◄──┘
Spec 08 (Data Reassurance) ───── (independent — copy only)
  │
  └─ Spec 11 (Data Longevity) ── (needs Spec 08 copy)

Spec 09 (Household Plan) ─────── BLOCKED on multi-profile (outside category)
```

**Critical path:** Spec 01 → Spec 03/04 → Spec 06 → Spec 10

---

## Execution phases

### Phase 1: Foundation (Spec 01 + cross-cutting infrastructure)

All 5 later specs depend on these foundations. Build them first.

#### Run 16: installDate + ModuleDayStatusKind.paused + lastActivityAt

| Task | Spec | What | Files | Commit |
|------|------|------|-------|--------|
| 16.1 | 01 | `installDate` column on `app_settings` | `app_settings_table.dart`, `app_settings.dart`, `settings_repository_impl.dart`, `app_database.dart` (migration v10), `main.dart` | `feat(db): add installDate column to app_settings (migration 10)` |
| 16.2 | 01 | `ModuleDayStatusKind.paused` variant + pause-aware streaks | `habit_module.dart`, `day_status_streaks.dart`, `calculate_water_streak.dart`, `calculate_adherence.dart`, `calculate_prayer_streak.dart` | `feat: add ModuleDayStatusKind.paused and pause-aware streak calculators` |
| 16.3 | 02 | `lastActivityAt` + `nudgeSentAfter` on `app_settings` | `app_settings_table.dart` (add 2 cols), `settings_repository_impl.dart`, `app_database.dart` (same migration v10) | `feat(db): add last_activity_at and nudge_sent_after to app_settings` |

#### Run 17: Archive data model + module enable/disable

| Task | Spec | What | Files | Commit |
|------|------|------|-------|--------|
| 17.1 | 03 | `archived_at` columns on `water_goals` + `medicine_schedules` | `water_goals_table.dart`, `medicine_schedules_table.dart`, `app_database.dart` (migration v12) | `feat(db): add archived_at columns to water_goals and medicine_schedules (migration 12)` |
| 17.2 | 03 | Archive/revive logic in Water repository | `water_repository_impl.dart`, `water_goal.dart` | `feat(water): add archive/revive logic for water goals` |
| 17.3 | 03 | Archive/revive logic in Medicine repository | `medicine_repository_impl.dart`, `medicine.dart` | `feat(medicine): add archive/revive logic for medicine schedules` |
| 17.4 | 03 | `dayStatus()` returns `paused` for archived days | `water_module.dart`, `medicine_module.dart` | `feat: dayStatus returns paused for days where all items are archived` |

---

### Phase 2: Core retention features

#### Run 18: Life-Event Pause + Re-engagement Nudge

| Task | Spec | What | Files | Commit |
|------|------|------|-------|--------|
| 18.1 | 04 | `pause_ranges` table + `PauseRepository` | `pause_ranges_table.dart` (new), `pause_repository.dart` (new), `app_database.dart` (migration v13) | `feat(db): add pause_ranges table (migration 13)` |
| 18.2 | 04 | `PauseService` — create/cancel/paused-days | `pause_service.dart` (new) | `feat(pauses): add PauseService with notification suppression` |
| 18.3 | 04 | Wire pause into `dayStatus()` for all modules | `water_module.dart`, `medicine_module.dart`, `prayer_module.dart` | `feat: dayStatus returns paused for days within active pause ranges` |
| 18.4 | 04 | Pause UI — create/edit/cancel | `create_pause_screen.dart` (new), `active_pauses_card.dart` (new), module settings screens | `feat(pauses): add create/edit/cancel pause UI` |
| 18.5 | 04 | Dashboard calendar — paused visual indicator | `global_month_calendar.dart` | `feat(dashboard): render paused days with distinct visual indicator` |
| 18.6 | 04 | Achievement freeze during pause | `achievement_engine.dart` | `feat(achievements): freeze progress during module pauses` |
| 18.7 | 02 | `LastActivityRepository` — cross-module query | `last_activity_repository.dart` (new) | `feat(nudges): add LastActivityRepository for cross-module activity query` |
| 18.8 | 02 | Re-engagement trigger logic (pure) | `reengagement_trigger.dart` (new) | `feat(nudges): add re-engagement trigger logic (pure)` |
| 18.9 | 02 | System-level nudge builder | `reengagement_nudge.dart` (new) | `feat(nudges): add system-level re-engagement notification builder` |
| 18.10 | 02 | Wire trigger into app lifecycle + planner | `reengagement_check.dart` (new), `main.dart`, `notification_planner.dart` | `feat(nudges): wire re-engagement check into app lifecycle and planner` |
| 18.11 | 02 | Settings toggle + activity tracking on writes | `app_settings.dart`, `settings_repository.dart`, module controllers | `feat(nudges): add settings toggle and activity tracking on module writes` |
| 18.12 | 02 | Dashboard fallback banner | `reengagement_banner.dart` (new), `dashboard_screen.dart` | `feat(dashboard): add re-engagement fallback banner` |

#### Run 19: Archive UI + Quarterly Recalibration + Anniversary Badge

| Task | Spec | What | Files | Commit |
|------|------|------|-------|--------|
| 19.1 | 03 | Archived items screens + revive UI | `archived_goals_screen.dart` (new), `archived_schedules_screen.dart` (new) | `feat: add archived items screens and revive UI for water/medicine` |
| 19.2 | 03 | Reports "(Archived)" label | `reports_screen.dart` | `feat(reports): show (Archived) label for archived periods` |
| 19.3 | 05 | `recalibration_markers` table | `recalibration_markers_table.dart` (new), `app_database.dart` (migration v14) | `feat(db): add recalibration_markers table (migration 14)` |
| 19.4 | 05 | `RecalibrationRepository` + `RecalibrationService` | `recalibration_repository.dart` (new), `recalibration_service.dart` (new) | `feat(recalibration): add RecalibrationRepository and service` |
| 19.5 | 05 | Recalibration trigger logic (pure) | `recalibration_trigger.dart` (new) | `feat(recalibration): add recalibration trigger logic (pure)` |
| 19.6 | 05 | `RecalibrationCard` widget | `recalibration_card.dart` (new) | `feat(recalibration): add RecalibrationCard widget` |
| 19.7 | 05 | Wire into Water + Medicine screens | `water_home_screen.dart`, `medicine_home_screen.dart` | `feat: wire recalibration prompt into module screens` |
| 19.8 | 05 | Goal-edit timestamp tracking | Water/Medicine repositories | `feat: track goal-edit timestamps for recalibration anchoring` |
| 19.9 | 05 | Settings toggle + session-level cap | `app_settings.dart`, `recalibration_session_tracker.dart` (new) | `feat(settings): add recalibration prompts toggle` |
| 19.10 | 06 | `milestone_value` column on `achievements` | `achievements_table.dart`, `app_database.dart` (migration v15) | `feat(db): add milestone_value column to achievements table (migration 15)` |
| 19.11 | 06 | Tenure evaluator (pure) | `tenure_evaluator.dart` (new) | `feat(achievements): add tenure milestone evaluator` |
| 19.12 | 06 | Wire tenure evaluation into app lifecycle | `tenure_check.dart` (new), `main.dart` | `feat(achievements): wire tenure evaluation into app lifecycle` |
| 19.13 | 06 | Tenure achievement display definitions | `achievement_definitions.dart` (new) | `feat(achievements): add tenure achievement display definitions` |

---

### Phase 3: Celebration + trust

#### Run 20: Yearly Recap + Data Trust

| Task | Spec | What | Files | Commit |
|------|------|------|-------|--------|
| 20.1 | 01 | `recaps` table + `RecapRepository` | `recaps_table.dart` (new), `recap_repository.dart` (new), `app_database.dart` (migration v16) | `feat(db): add recaps table (migration 16)` |
| 20.2 | 01 | `YearSummary` / `ModuleYearStats` data shapes | `year_summary.dart` (new) | `feat(recaps): add YearSummary and ModuleYearStats data shapes` |
| 20.3 | 01 | `YearRecapGeneratorUseCase` | `recap_generator.dart` (new) | `feat(recaps): add RecapRepository and YearRecapGeneratorUseCase` |
| 20.4 | 01 | Recap trigger mechanism | `recap_trigger.dart` (new), `recap_check.dart` (new) | `feat(recaps): add trigger mechanism and app-lifecycle wiring` |
| 20.5 | 01 | Yearly recap story-card UI | `yearly_recap_screen.dart` (new), card widgets | `feat(recaps): add yearly recap story cards and full-screen UI` |
| 20.6 | 01 | "Past Recaps" settings screen | `past_recaps_screen.dart` (new) | `feat(recaps): add Past Recaps screen in Settings` |
| 20.7 | 08 | Data privacy reassurance card | `data_privacy_reassurance_card.dart` (new), `data_settings_screen.dart` | `feat(settings): add data privacy reassurance card to Data settings` |
| 20.8 | 11 | Data longevity guarantee card | `data_longevity_guarantee_card.dart` (new), `data_settings_screen.dart` | `feat(settings): add data longevity guarantee card to Data settings` |
| 20.9 | 11 | Notification ledger bounded cleanup | `notification_ledger_repository.dart` | `feat(notifications): add bounded cleanup for notification_ledger (90-day FIFO)` |
| 20.10 | 11 | Retention audit document | `docs/engineering/retention-audit.md` (new) | `docs: add retention-audit.md documenting every table's retention behavior` |

---

### Phase 4: Onboarding + cosmetic rewards

#### Run 21: Progressive Module Unlock + Cosmetic Rewards

| Task | Spec | What | Files | Commit |
|------|------|------|-------|--------|
| 21.1 | 07 | `module_settings` + `onboarding_progress` tables | `module_settings_table.dart` (new), `onboarding_progress_table.dart` (new), `app_database.dart` (migration v17) | `feat(db): add module_settings and onboarding_progress tables (migration 17)` |
| 21.2 | 07 | `ModuleSettingsRepository` | `module_settings_repository.dart` (new) | `feat(modules): add ModuleSettingsRepository for enable/disable` |
| 21.3 | 07 | Wire module filtering into `module_registry` | `module_registry.dart` | `feat(modules): wire module enable/disable into module_registry` |
| 21.4 | 07 | Onboarding flow — screens + routing | `onboarding_welcome_screen.dart` (new), `onboarding_module_selection_screen.dart` (new), `onboarding_complete_screen.dart` (new), `app_router.dart` | `feat(onboarding): add progressive module unlock onboarding flow` |
| 21.5 | 07 | Dashboard suggestion card | `module_suggestion_card.dart` (new), `dashboard_screen.dart` | `feat(dashboard): add "You might also like" module suggestion card` |
| 21.6 | 07 | Notification re-plan on module toggle | `module_settings_repository.dart` | `feat(modules): re-plan notifications on module enable/disable` |
| 21.7 | 07 | Settings module toggles | `settings_home_screen.dart` | `feat(settings): add module enable/disable toggles` |
| 21.8 | 10 | `cosmetic_unlocks` table | `cosmetic_unlocks_table.dart` (new), `app_database.dart` (migration v18) | `feat(db): add cosmetic_unlocks table (migration 18)` |
| 21.9 | 10 | Achievement engine stream events | `achievement_engine.dart` | `feat(achievements): emit stream events on achievement unlock` |
| 21.10 | 10 | `CosmeticUnlockEngine` + `CosmeticRepository` | `cosmetic_unlock_engine.dart` (new), `cosmetic_repository.dart` (new) | `feat(cosmetics): add CosmeticUnlockEngine and CosmeticRepository` |
| 21.11 | 10 | "Midnight" theme accent | `app_theme.dart`, `cosmetic_accent_provider.dart` (new) | `feat(theme): add Midnight accent cosmetic option` |
| 21.12 | 10 | Settings "Unlocks" section | `unlocks_screen.dart` (new), `settings_home_screen.dart` | `feat(settings): add Unlocks section for cosmetic rewards` |
| 21.13 | 10 | Wire cosmetic evaluation into lifecycle | `main.dart` | `feat: wire cosmetic evaluation into app lifecycle` |

---

### Phase 5: Household (blocked)

#### Spec 09: Household/Family Plan Hook

**Status:** BLOCKED on multi-profile data model and Premium subscription infrastructure (outside this category).

**When unblocked — implementation tasks from individual plan:**

| Task | What | Files |
|------|------|-------|
| 22.1 | `household_banner_dismissed` on `app_settings` | `app_settings_table.dart`, `app_database.dart` (migration) |
| 22.2 | Tenure-based banner trigger (pure) | `household_trigger.dart` (new) |
| 22.3 | Dashboard household banner | `household_banner.dart` (new), `dashboard_screen.dart` |
| 22.4 | Settings "Household" placeholder | `household_settings_screen.dart` (new) |
| 22.5 | Positioning documentation | `docs/engineering/household-plan-positioning.md` (new) |

---

## Localization summary

| Spec | New keys (en/bn) |
|------|-------------------|
| 01 — Yearly Recap | ~30 |
| 02 — Re-engagement Nudge | ~8 |
| 03 — Archive/Revive | ~15 |
| 04 — Life-Event Pause | ~20 |
| 05 — Quarterly Recalibration | ~12 |
| 06 — Anniversary Badge | ~6 |
| 07 — Progressive Onboarding | ~20 |
| 08 — Data Reassurance | ~3 |
| 09 — Household Plan | ~8 |
| 10 — Cosmetic Rewards | ~8 |
| 11 — Data Longevity | ~5 |
| **Total** | **~135** |

---

## Schema migration sequence

| Version | What changes | Specs |
|---------|-------------|-------|
| 9 (current) | — | — |
| 10 | `app_settings`: +`install_date`, +`last_activity_at`, +`nudge_sent_after` | 01, 02 |
| 11 | *(reserved — module enable/disable if coalesced here)* | — |
| 12 | `water_goals`: +`archived_at`; `medicine_schedules`: +`archived_at` | 03 |
| 13 | `pause_ranges` (new table) | 04 |
| 14 | `recalibration_markers` (new table) | 05 |
| 15 | `achievements`: +`milestone_value` | 06 |
| 16 | `recaps` (new table) | 01 |
| 17 | `module_settings` (new); `onboarding_progress` (new) | 07 |
| 18 | `cosmetic_unlocks` (new table) | 10 |

**Note:** All migrations must be tested end-to-end: upgrade from version N-1 to N with existing data must not lose any rows. All timestamp columns use `IntColumn` (UTC epoch millis) to match existing table conventions.

---

## Commit sequence (all 81)

| # | Commit | Spec |
|---|--------|------|
| 1 | `feat(db): add installDate column to app_settings (migration 10)` | 01 |
| 2 | `feat(settings): add installDate, recapEnabled, lastRecapYear to AppSettings` | 01 |
| 3 | `feat: add ModuleDayStatusKind.paused and pause-aware streak calculators` | 01 |
| 4 | `feat(recaps): add YearSummary and ModuleYearStats data shapes` | 01 |
| 5 | `feat(recaps): add RecapRepository and YearRecapGeneratorUseCase` | 01 |
| 6 | `feat(recaps): add trigger mechanism and app-lifecycle wiring` | 01 |
| 7 | `feat(recaps): add yearly recap story cards and full-screen UI` | 01 |
| 8 | `feat(recaps): add Past Recaps screen in Settings` | 01 |
| 9 | `feat(i18n): add en/bn localization for yearly recap` | 01 |
| 10 | `feat(settings): add recap feature toggle` | 01 |
| 11 | `feat(db): add last_activity_at and nudge_sent_after to app_settings (migration 11)` | 02 |
| 12 | `feat(nudges): add LastActivityRepository for cross-module activity query` | 02 |
| 13 | `feat(nudges): add re-engagement trigger logic (pure)` | 02 |
| 14 | `feat(nudges): add system-level re-engagement notification builder` | 02 |
| 15 | `feat(nudges): wire re-engagement check into app lifecycle and planner` | 02 |
| 16 | `feat(nudges): add settings toggle and activity tracking on module writes` | 02 |
| 17 | `feat(i18n): add en/bn strings for re-engagement nudge` | 02 |
| 18 | `feat(db): add archived_at columns to water_goals and medicine_schedules (migration 12)` | 03 |
| 19 | `feat(water): add archive/revive logic for water goals` | 03 |
| 20 | `feat(medicine): add archive/revive logic for medicine schedules` | 03 |
| 21 | `feat: dayStatus returns paused for days where all items are archived` | 03 |
| 22 | `feat: add archived items screens and revive UI for water/medicine` | 03 |
| 23 | `feat(reports): show (Archived) label for archived periods` | 03 |
| 24 | `feat(i18n): add en/bn strings for archive/revive flow` | 03 |
| 25 | `feat(db): add pause_ranges table (migration 13)` | 04 |
| 26 | `feat(pauses): add PauseRepository with overlap validation` | 04 |
| 27 | `feat(pauses): add PauseService with notification suppression` | 04 |
| 28 | `feat: dayStatus returns paused for days within active pause ranges` | 04 |
| 29 | `feat: wire pause-aware pausedDays into streak calculators` | 04 |
| 30 | `feat(pauses): add create/edit/cancel pause UI` | 04 |
| 31 | `feat(dashboard): render paused days with distinct visual indicator` | 04 |
| 32 | `feat(achievements): freeze progress during module pauses` | 04 |
| 33 | `feat(settings): add pause management entry` | 04 |
| 34 | `feat(i18n): add en/bn strings for pause mode` | 04 |
| 35 | `feat(db): add recalibration_markers table (migration 14)` | 05 |
| 36 | `feat(recalibration): add RecalibrationRepository` | 05 |
| 37 | `feat(recalibration): add recalibration trigger logic (pure)` | 05 |
| 38 | `feat(recalibration): add RecalibrationService orchestration` | 05 |
| 39 | `feat(recalibration): add RecalibrationCard widget` | 05 |
| 40 | `feat(water): wire recalibration prompt into water home screen` | 05 |
| 41 | `feat(medicine): wire recalibration prompt into medicine home screen` | 05 |
| 42 | `feat: track goal-edit timestamps for recalibration anchoring` | 05 |
| 43 | `feat(settings): add recalibration prompts toggle` | 05 |
| 44 | `feat(recalibration): add session-level prompt cap` | 05 |
| 45 | `feat(i18n): add en/bn strings for recalibration prompts` | 05 |
| 46 | `feat(db): add milestone_value column to achievements table (migration 15)` | 06 |
| 47 | `feat(achievements): add tenure milestone evaluator` | 06 |
| 48 | `feat(achievements): wire tenure evaluation into app lifecycle` | 06 |
| 49 | `feat(achievements): add tenure achievement display definitions` | 06 |
| 50 | `feat(i18n): add en/bn strings for tenure anniversary badges` | 06 |
| 51 | `feat(db): add module_settings and onboarding_progress tables (migration 17)` | 07 |
| 52 | `feat(modules): add ModuleSettingsRepository for enable/disable` | 07 |
| 53 | `feat(modules): wire module enable/disable into module_registry` | 07 |
| 54 | `feat(onboarding): add progressive module unlock onboarding flow` | 07 |
| 55 | `feat(onboarding): add onboarding state providers` | 07 |
| 56 | `feat(dashboard): add "You might also like" module suggestion card` | 07 |
| 57 | `feat(modules): re-plan notifications on module enable/disable` | 07 |
| 58 | `feat(settings): add module enable/disable toggles` | 07 |
| 59 | `feat(i18n): add en/bn strings for onboarding and module suggestions` | 07 |
| 60 | `feat(settings): add data privacy reassurance card to Data settings` | 08 |
| 61 | `feat(i18n): audit and consolidate near-duplicate privacy copy` | 08 |
| 62 | `feat(i18n): add en/bn strings for data privacy reassurance` | 08 |
| 63 | `feat(db): add household_banner_dismissed to app_settings (migration 17)` | 09 |
| 64 | `feat(household): add tenure-based banner trigger logic` | 09 |
| 65 | `feat(dashboard): add household plan suggestion banner` | 09 |
| 66 | `feat(settings): add household settings placeholder screen` | 09 |
| 67 | `docs: add household plan positioning document` | 09 |
| 68 | `feat(i18n): add en/bn strings for household plan hook` | 09 |
| 69 | `feat(db): add cosmetic_unlocks table (migration 18)` | 10 |
| 70 | `feat(achievements): emit stream events on achievement unlock` | 10 |
| 71 | `feat(cosmetics): add CosmeticUnlockEngine for achievement-to-cosmetic mapping` | 10 |
| 72 | `feat(cosmetics): add CosmeticRepository` | 10 |
| 73 | `feat(theme): add Midnight accent cosmetic option` | 10 |
| 74 | `feat(settings): add Unlocks section for cosmetic rewards` | 10 |
| 75 | `feat: wire cosmetic evaluation into app lifecycle` | 10 |
| 76 | `feat(i18n): add en/bn strings for cosmetic unlocks` | 10 |
| 77 | `docs: add retention-audit.md documenting every table's retention behavior` | 11 |
| 78 | `feat(settings): add data longevity guarantee card to Data settings` | 11 |
| 79 | `feat(notifications): add bounded cleanup for notification_ledger (90-day FIFO)` | 11 |
| 80 | `docs: add data longevity check to schema migration checklist` | 11 |
| 81 | `feat(i18n): add en/bn strings for data longevity guarantee` | 11 |

---

## Verification plan

After each run:
1. `flutter analyze` — no new warnings
2. `flutter test` — all tests pass
3. `dart format --output=none --set-exit-if-changed .` — formatting check
4. Manual smoke test on Android/iOS simulator
5. Migration test: upgrade from previous schema version

After all phases complete:
1. Full regression test suite
2. Performance test: database query times with 3+ years of simulated data
3. Accessibility audit: screen reader, reduced motion, color contrast
4. Localization parity check: en/bn string count match
5. Cross-spec integration test: pause + archive + streak + recap all interact correctly

---

## Risk register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Schema migration conflicts between runs | High | Centralized migration plan (this document), version sequencing |
| Pause mode complexity breaks streak calculations | High | Extensive unit tests for streak calculators with paused days |
| Notification planner module-only contract | Medium | Extend with system-level candidate injection (Spec 02) |
| Achievement engine can't handle cross-cutting achievements | Medium | Add tenure evaluator as separate app-lifecycle path (Spec 06) |
| YearSummary data shape mismatch across modules | Medium | Define standardized Freezed class, enforce in tests |
| Archive/revive notification re-registration | Medium | Test revive path end-to-end with notification scheduler |
| `buildHabitModules()` filtering breaks background callers | Medium | Only filter at UI/router level, not in `buildHabitModules()` (Spec 07) |
| Module repositories lack `SettingsRepository` dependency | Medium | Activity tracking via presentation controllers (Option B, Spec 02) |
| Device storage growth over 3-4 years | Low | Monitor via retention audit, document in guarantee (Spec 11) |
| Localization drift (en/bn mismatch) | Low | CI check for ARB key parity |
| Spec 09 blocked on multi-profile | High | Implement trigger/UI now, defer profile management to Premium category |
| Notification ledger unbounded growth | Low | Add 90-day FIFO cleanup (Spec 11 T3) |

---

## Individual plan files

Each spec has a detailed implementation plan with file-level task breakdowns:

| Spec | Plan file |
|------|-----------|
| 01 — Yearly Recap | `plans/2026-07-25-yearly-wrapped-recap.md` |
| 02 — Re-engagement Nudge | `plans/2026-07-25-gentle-reengagement-nudge.md` |
| 03 — Archive/Revive | `plans/2026-07-25-habit-archive-revive-flow.md` |
| 04 — Life-Event Pause | `plans/2026-07-25-life-event-pause-mode.md` |
| 05 — Quarterly Recalibration | `plans/2026-07-25-quarterly-goal-recalibration-prompt.md` |
| 06 — Anniversary Badge | `plans/2026-07-25-anniversary-badge.md` |
| 07 — Progressive Onboarding | `plans/2026-07-25-progressive-module-unlock.md` |
| 08 — Data Reassurance | `plans/2026-07-25-data-reassurance.md` |
| 09 — Household Plan | `plans/2026-07-25-household-family-plan-hook.md` |
| 10 — Cosmetic Rewards | `plans/2026-07-25-loyalty-milestone-cosmetic-rewards.md` |
| 11 — Data Longevity | `plans/2026-07-25-silent-data-longevity-guarantee.md` |

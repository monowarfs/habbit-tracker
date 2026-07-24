# Adaptive Quest Difficulty (Gamification Tie-In) — Implementation Plan

**Spec:** [08-adaptive-quest-difficulty-design.md](./08-adaptive-quest-difficulty-design.md)
**Run:** TBD
**Estimated effort:** L (19 tasks, new table + new feature module + engine integration)
**Estimated duration:** 2–3 focused sessions
**Dependencies:** Achievements engine and repository (Run 15); each module's log/completion history as input to rolling averages

## Pre-requisites

- Flutter SDK `^3.12.2` installed and `flutter pub get` working
- Achievements engine (`core/achievements/achievement_engine.dart`) and repository from Run 15 fully functional
- `HabitModule` contract supports `dayStatus(range)` for all three modules (Water, Medicine, Prayer)
- `localDayKey()` and `DateRange` utilities available from `core/utils/`
- Drift database at schema version 7 (this spec bumps to 8)
- `module_registry.dart` providing `habitModulesProvider`

## Tasks

### Task 1: Create `WeeklyQuestsTable` Drift table
**Effort:** S
**Files to create:** `lib/core/database/tables/weekly_quests_table.dart`
**Description:** Define the `weekly_quests` table with columns: `id` (UUID, PK), `moduleId`, `weekStartMillis` (ISO week start Monday as epoch millis), `targetCount`, `baselineCount`, `sampleDays`, `currentProgress`, `isCompleted`, `createdAt`, `updatedAt`, `deletedAt` (nullable soft-delete). Table is dedicated rather than reusing `achievements` because quests are weekly-rolling and ephemeral.
**Acceptance criteria:** Table definition compiles; `@DataClassName('WeeklyQuestRow')` generated.
**Test:** N/A (schema definition — verified via repository tests)

### Task 2: Register table in `AppDatabase`, bump schema, add migration
**Effort:** S
**Files to modify:** `lib/core/database/app_database.dart`
**Description:** Import `WeeklyQuestsTable`, add to `@DriftDatabase(tables: [...])`. Bump `schemaVersion` from 7 to 8. Add migration: `if (from < 8) { await m.createTable(weeklyQuestsTable); }`.
**Acceptance criteria:** `build_runner build` succeeds; schema version is 8; migration creates the table on upgrade.
**Test:** `dart run build_runner build --delete-conflicting-outputs` succeeds without errors.

### Task 3: Create `WeeklyQuest` freezed entity
**Effort:** S
**Files to create:** `lib/features/quests/domain/entities/weekly_quest.dart`
**Description:** Freezed entity with fields: `id`, `moduleId`, `weekStart` (DateTime, Monday of quest week), `targetCount`, `baselineCount`, `sampleDays`, `currentProgress`, `isCompleted`. Include computed getter `progressFraction` (0.0–1.0 clamped).
**Acceptance criteria:** Freezed codegen succeeds; `progressFraction` computes correctly.
**Test:** N/A (tested via use case tests)

### Task 4: Create `QuestDefinition` entity
**Effort:** S
**Files to create:** `lib/features/quests/domain/entities/quest_definition.dart`
**Description:** Immutable class with `moduleId` and `computeWeeklyCount` closure (`Future<int> Function()`). Analogous to `AchievementDefinition` — the module provides the calculation closure, the engine evaluates it.
**Acceptance criteria:** Compiles; each module can provide a `QuestDefinition` with its own closure.
**Test:** N/A (interface definition)

### Task 5: Create `CalculateWeeklyQuestUseCase` (pure, heavily tested)
**Effort:** M
**Files to create:** `lib/features/quests/domain/usecases/calculate_weekly_quest_usecase.dart`
**Description:** Pure use case computing weekly quest target from rolling average:
- Parameters: `lookbackWeeks` (default 4), `stretchFactorPct` (default 15%), `floorTarget` (default 1)
- Algorithm: `baseline = average of last N weeks' counts (excluding current week)`, `target = max(floorTarget, round(baseline * (1 + stretchFactorPct / 100)))`
- Edge cases: zero baseline → floorTarget (1); 1 week of history → use that week; < 1 week → return null; very high baseline → still applies stretch (15% keeps it modest)
- Returns `WeeklyQuest` with `currentProgress = currentWeekCount`, `isCompleted = currentProgress >= targetCount`
**Acceptance criteria:** All edge cases handled; returns null for insufficient data; stretch factor applied correctly.
**Test:** `test/features/quests/domain/usecases/calculate_weekly_quest_usecase_test.dart` — baseline 0 → target 1; baseline 3 → target 4; baseline 7 → target 8; baseline 1 → target 1; 1-week history → quest generated; empty list → null; all zeros → floor target.

### Task 6: Create `WeeklyQuestRepository`
**Effort:** M
**Files to create:** `lib/features/quests/data/weekly_quest_repository.dart`
**Description:** CRUD over `weekly_quests` table:
- `byModuleAndWeek(moduleId, weekStart)` → `WeeklyQuestRow?`
- `watchByModule(moduleId)` → `Stream<List<WeeklyQuestRow>>`
- `watchAll()` → `Stream<List<WeeklyQuestRow>>`
- `upsertQuest(moduleId, weekStart, targetCount, baselineCount, sampleDays, currentProgress)` → creates or updates
- `pruneOldQuests(keepWeeks)` → soft-deletes old quests (called on app startup)
**Acceptance criteria:** All CRUD operations work; `upsertQuest` correctly creates or updates; `pruneOldQuests` soft-deletes beyond `keepWeeks`.
**Test:** `test/features/quests/data/weekly_quest_repository_test.dart` — byModuleAndWeek, upsert, pruneOldQuests with Drift test DB.

### Task 7: Create `EvaluateWeeklyQuestUseCase`
**Effort:** M
**Files to create:** `lib/features/quests/domain/usecases/evaluate_weekly_quest_usecase.dart`
**Description:** Evaluates one module's weekly quest and persists progress. Called from the module's own write path (same pattern as `AchievementEngine`):
1. Get or create this week's quest row (use `CalculateWeeklyQuestUseCase` if no row exists)
2. Get current progress from the quest definition's closure
3. Update `currentProgress`, mark `isCompleted` if >= target
**Acceptance criteria:** Creates quest if none exists; updates progress; marks completed at target; handles existing row.
**Test:** `test/features/quests/domain/usecases/evaluate_weekly_quest_usecase_test.dart` — creates quest, updates progress, marks completed, handles existing row.

### Task 8: Add `questDefinition` to `HabitModule` contract
**Effort:** S
**Files to modify:** `lib/core/modules/habit_module.dart`
**Description:** Add optional getter to `HabitModule`: `QuestDefinition? get questDefinition => null;`. Default is null (module doesn't support quests). Each module that supports quests overrides this.
**Acceptance criteria:** Contract compiles; existing modules unaffected (default null).
**Test:** N/A (contract change)

### Task 9: Implement `questDefinition` in Water, Medicine, Prayer
**Effort:** M
**Files to modify:**
- `lib/features/water/water_module.dart`
- `lib/features/medicine/medicine_module.dart`
- `lib/features/prayer/prayer_module.dart`
**Description:** Each module overrides `questDefinition` to provide a `QuestDefinition` with its `computeWeeklyCount` closure:
- Water: counts days this week where total logged >= goal
- Medicine: counts doses taken this week
- Prayer: counts days where all prayers were completed this week
All use `localDayKey(clock.now())` and `DateRange` for week calculation.
**Acceptance criteria:** Each module's closure returns correct count for current week; uses `localDayKey` for DST safety.
**Test:** Covered by evaluate use case tests (Task 7)

### Task 10: Add `evaluateWeeklyQuests` to `AchievementEngine`
**Effort:** S
**Files to modify:** `lib/core/achievements/achievement_engine.dart`
**Description:** Add `evaluateWeeklyQuests(String moduleId)` method alongside existing `evaluate(String moduleId)`. Looks up module's `questDefinition`, calls `EvaluateWeeklyQuestUseCase` if definition exists.
**Acceptance criteria:** Method callable; no-ops for modules without quest definitions; called from same write path as `evaluate()`.
**Test:** N/A (wiring — tested via integration)

### Task 11: Add quest providers
**Effort:** S
**Files to create:** `lib/features/quests/presentation/providers/quest_providers.dart`
**Files to modify:** `lib/core/achievements/achievement_providers.dart`
**Description:** Add `@riverpod` providers: `weeklyQuestRepositoryProvider` (keepAlive), `evaluateWeeklyQuestUseCaseProvider`, `currentWeekQuests` (Stream provider watching `repository.watchAll()`).
**Acceptance criteria:** Providers compile; `currentWeekQuests` emits live-updating stream.
**Test:** N/A (provider wiring)

### Task 12: Create `QuestProgressCard` widget
**Effort:** S
**Files to create:** `lib/features/quests/presentation/widgets/quest_progress_card.dart`
**Description:** Card showing: module icon + name, "This week's quest: X/Y days" with `LinearProgressIndicator`, baseline note ("Based on your average of Z days/week"), completed state with checkmark + "Quest completed!".
**Acceptance criteria:** Renders progress bar; shows baseline; shows completed state.
**Test:** `test/features/quests/presentation/widgets/quest_progress_card_test.dart` — renders progress bar, shows baseline, shows completed state.

### Task 13: Create `QuestCompletionDialog` widget
**Effort:** S
**Files to create:** `lib/features/quests/presentation/widgets/quest_completion_dialog.dart`
**Description:** Simple `AlertDialog` with congratulatory message when a quest is completed mid-week. Triggered when `WeeklyQuest` stream emits a row where `isCompleted` just became true.
**Acceptance criteria:** Shows congratulatory message; dismisses on tap.
**Test:** N/A (simple dialog — verified via integration)

### Task 14: Add quest section to dashboard
**Effort:** M
**Files to modify:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
**Description:** Add `_QuestSection` widget between `_QuickActionsRow` and module summaries. Loads all modules' current weekly quests via `currentWeekQuestsProvider`. Renders horizontal `ListView` of `QuestProgressCard` widgets. Empty state: no cards shown (quests not yet generated for new users).
**Acceptance criteria:** Quest cards appear on dashboard when quests exist; hidden when none; horizontal scrolling works.
**Test:** `test/features/dashboard/presentation/screens/dashboard_screen_test.dart` (existing file, add case) — quest section appears when quests exist, hidden when none.

### Task 15: Add L10n strings (en/bn)
**Effort:** S
**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`
**Description:** Add quest-related localization keys (see Localization Keys section below). Run `flutter gen-l10n` after adding.
**Acceptance criteria:** All new keys present in both ARB files; `flutter gen-l10n` generates without errors.
**Test:** N/A (localization only)

### Task 16: Write unit tests for `CalculateWeeklyQuestUseCase`
**Effort:** M
**Files to create:** `test/features/quests/domain/usecases/calculate_weekly_quest_usecase_test.dart`
**Description:** Test rolling average algorithm with all edge cases: zero baseline, 1-week history, 4-week history, all zeros, stretch factor calculation, floor target. All tests are pure — no mocks needed.
**Acceptance criteria:** All test cases pass; edge cases covered.
**Test:** `test/features/quests/domain/usecases/calculate_weekly_quest_usecase_test.dart`

### Task 17: Write unit tests for `EvaluateWeeklyQuestUseCase`
**Effort:** S
**Files to create:** `test/features/quests/domain/usecases/evaluate_weekly_quest_usecase_test.dart`
**Description:** Test quest evaluation: creates quest if none exists, updates progress, marks completed, handles existing quest row. Mock repository.
**Acceptance criteria:** All test cases pass.
**Test:** `test/features/quests/domain/usecases/evaluate_weekly_quest_usecase_test.dart`

### Task 18: Write widget tests for quest cards
**Effort:** S
**Files to create:** `test/features/quests/presentation/widgets/quest_progress_card_test.dart`
**Description:** Test `QuestProgressCard` renders progress bar, shows baseline text, shows completed state with checkmark.
**Acceptance criteria:** Widget renders correctly in all states.
**Test:** `test/features/quests/presentation/widgets/quest_progress_card_test.dart`

### Task 19: Run `build_runner build`, verify no analysis errors
**Effort:** S
**Files to modify:** (none — verification step)
**Description:** Run `dart run build_runner build --delete-conflicting-outputs` to generate all `*.g.dart` files. Run `flutter analyze` to verify no lint or analysis errors. Run `dart format --output=none --set-exit-if-changed .` to verify formatting.
**Acceptance criteria:** All generated files produced; zero analysis errors; formatting clean.
**Test:** `flutter analyze` passes; `dart format` clean.

## Schema Migration

**New table: `weekly_quests`**

Migration in `app_database.dart`:
```dart
if (from < 8) {
  await m.createTable(weeklyQuestsTable);
}
```

Column definitions:
| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT | UUID, primary key |
| `moduleId` | TEXT | 'water', 'medicine', 'prayer' |
| `weekStartMillis` | INTEGER | ISO week start (Monday) as epoch millis |
| `targetCount` | INTEGER | Stretch target for this week |
| `baselineCount` | INTEGER | Rolling average that produced target (for display) |
| `sampleDays` | INTEGER | Days of history used to compute baseline |
| `currentProgress` | INTEGER | Current progress toward target |
| `isCompleted` | BOOLEAN | Whether quest was completed |
| `createdAt` | INTEGER | UTC epoch millis |
| `updatedAt` | INTEGER | UTC epoch millis, bumped on every write |
| `deletedAt` | INTEGER | Nullable, soft-delete marker |

**Note:** If spec 09 (Cross-Module Correlation Insight) also bumps to schema 8, coordinate — one spec takes 8, the other takes 9.

## Localization Keys

**English (`app_en.arb`):**
```json
"questTitle": "Weekly Quest",
"questProgress": "{current}/{target} days",
"questBaseline": "Based on your average of {baseline} days/week",
"questCompleted": "Quest completed! Great work!",
"questNoData": "Keep logging to unlock your first quest",
"questModuleName": "{module} Quest"
```

**Bangla (`app_bn.arb`):** Corresponding Bangla translations for all keys above.

## Risk Notes

1. **Schema version coordination:** This spec bumps `schemaVersion` to 8. If spec 09 (Cross-Module Correlation Insight) also adds a table, coordinate version numbers — one takes 8, the other takes 9. Check spec 09's implementation before starting.
2. **Stretch factor tuning:** 15% above baseline is a starting point. Real users may find this too easy or too hard. The `stretchFactorPct` parameter is configurable per-instance for easy tuning without code changes.
3. **Zero-baseline users:** New users or users who rarely log get `floorTarget = 1` (do it once this week). This is intentionally modest — the quest system shouldn't punish inconsistency.
4. **Weekly reset timing:** Quests reset every Monday regardless of completion. Partial progress does NOT roll over — each week starts fresh because the target adapts. This is by design.
5. **Quest generation timing:** Quests are generated lazily (on first access per week) via `EvaluateWeeklyQuestUseCase`, not on a schedule. This avoids background work and ensures the baseline is always up-to-date.
6. **Module `dayStatus` dependency:** Each module's `computeWeeklyCount` closure calls `dayStatus(range)`. Verify all three modules implement `dayStatus` correctly before wiring quest definitions.

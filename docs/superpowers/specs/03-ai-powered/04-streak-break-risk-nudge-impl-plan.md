# Streak-Break Risk Nudge — Implementation Plan

**Spec:** [04-streak-break-risk-nudge-design.md](04-streak-break-risk-nudge-design.md)
**Run:** TBD
**Estimated effort:** M
**Dependencies:** Existing streak calculators (Water, Medicine, Prayer), existing `core/notifications` scheduling/ledger infrastructure, `app_settings` table, `HabitModule` contract.

## Pre-requisites

- All three modules (Water, Medicine, Prayer) are registered in `module_registry.dart` and wired into the router.
- Streak calculators exist for each module (`CalculateWaterStreakUseCase`, Medicine/Prayer equivalents).
- `core/notifications/notification_planner.dart` is functional with `planAndApplyNotifications` and the `notification_ledger` dedup logic.
- `flutter gen-l10n` produces valid `AppLocalizations`.

## Tasks

### Task 1: Create `StreakBreakRisk` entity + Freezed class
**Effort:** S
**Files to create:**
- `lib/features/core/streak_break/domain/entities/streak_break_risk.dart`

**Files to modify:** (none)
**Description:** Create the domain entity representing detected streak-break risk for one module on a given day. Includes a `StreakBreakRiskLevel` enum (`high`, `moderate`, `none`) and a `@freezed` `StreakBreakRisk` class with fields: `moduleId`, `riskLevel`, `currentStreak`, `typicalCompletionTime`, `hasLoggedToday`, `isActive`. Run `build_runner build --delete-conflicting-outputs` to generate the `.freezed.dart` file.

**Acceptance criteria:**
- `StreakBreakRisk` compiles after codegen.
- Entity is immutable and uses Freezed.
- Three-level enum is defined.

**Test:** `build_runner build --delete-conflicting-outputs` succeeds without errors.

---

### Task 2: Create `DetectStreakBreakRiskUseCase` + unit tests
**Effort:** M
**Files to create:**
- `lib/features/core/streak_break/domain/usecases/detect_streak_break_risk.dart`
- `test/features/core/streak_break/domain/usecases/detect_streak_break_risk_test.dart`

**Files to modify:** (none)
**Description:** Implement the pure use case. Accept `moduleId`, `completionHistory` (list of `CompletionRecord` with `day` + `completedAt`), `today`, `now`, `currentStreak`. Logic:
1. `currentStreak == 0` → `StreakBreakRiskLevel.none`
2. `completionHistory.length < minDaysOfHistory` (default 3) → `none`
3. Compute median completion time-of-day from history.
4. If today's time-of-day is past the median and no completion today → `high`
5. If within 30 minutes before the median → `moderate`
6. Otherwise → `none`

Write comprehensive tests covering: zero streak, insufficient history, past-median, within-30-min, before-median, already-logged, exactly-at-median, all-same-time history, DST transition edge case.

**Acceptance criteria:**
- Use case is pure (no DB, no plugin dependency).
- All 9+ test cases pass.
- `completionHistory` list is typed with the `CompletionRecord` value class (defined in the same file).

**Test:** `flutter test test/features/core/streak_break/domain/usecases/detect_streak_break_risk_test.dart`

---

### Task 3: Add `streakBreakHistory()` to `HabitModule` contract
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/core/modules/habit_module.dart`

**Description:** Add an optional method to `HabitModule`:
```dart
/// Completion-time history for streak-break nudge detection.
/// Returns null if this module doesn't support streak-break nudging.
Future<List<CompletionRecord>?> streakBreakHistory() async => null;
```
The `CompletionRecord` class is defined in Task 1's file and imported here. Default implementation returns `null` so existing modules don't break. The method must be `Ref`-free (same constraint as `onNotificationAction`).

**Acceptance criteria:**
- `HabitModule` compiles with the new method.
- All three module subclasses still compile (inherited default returns `null`).
- Method takes no `Ref` parameter.

**Test:** `flutter analyze` passes clean.

---

### Task 4: Implement `streakBreakHistory()` in Water module
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/water/water_module.dart`

**Description:** Override `streakBreakHistory()` in `WaterModule`. Query `water_logs` for the user's historical entries, map each to a `CompletionRecord` with the log's day and timestamp. Filter to days where `totalAmount >= goal` (i.e., the day was a "hit" for streak purposes). Return the list sorted by day ascending.

**Acceptance criteria:**
- Returns `List<CompletionRecord>` with at least one entry if water logs exist.
- Returns `null` or empty list if no data.
- No `Ref` dependency.

**Test:** `flutter test` (existing Water module tests still pass).

---

### Task 5: Implement `streakBreakHistory()` in Medicine module
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/medicine/medicine_module.dart`

**Description:** Override `streakBreakHistory()` in `MedicineModule`. Query `medicine_doses` for historical `done`/`skipped` doses. For each day, find the earliest `scheduledAt` or `takenAt` time. Map to `CompletionRecord`. Return days where at least one dose was taken.

**Acceptance criteria:**
- Returns completion records for days with at least one dose taken.
- No `Ref` dependency.

**Test:** `flutter test` (existing Medicine module tests still pass).

---

### Task 6: Implement `streakBreakHistory()` in Prayer module
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/prayer/prayer_module.dart`

**Description:** Override `streakBreakHistory()` in `PrayerModule`. Query `prayer_records` for historical `prayed` records. Map each day's earliest prayer to a `CompletionRecord`. Return the list.

**Acceptance criteria:**
- Returns completion records for days with at least one prayer logged.
- No `Ref` dependency.

**Test:** `flutter test` (existing Prayer module tests still pass).

---

### Task 7: Add `streakBreakNudgeDisabledModules` column + migration
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/core/database/tables/app_settings_table.dart`

**Description:** Add a new `TextColumn` to `AppSettingsTable`:
```dart
TextColumn get streakBreakNudgeDisabledModules =>
    text().withDefault(const Constant('[]'))();
```
This stores a JSON array of module id strings (e.g. `["water"]`). Write a Drift migration step in the database's `schemaVersion` migration to `ALTER TABLE app_settings ADD COLUMN streak_break_nudge_disabled_modules TEXT NOT NULL DEFAULT '[]'`.

**Acceptance criteria:**
- `build_runner build` generates updated Drift code.
- Migration step compiles and `flutter analyze` passes.
- Default value is `'[]'` (empty array).

**Test:** `flutter test` (existing settings/database tests still pass).

---

### Task 8: Update `AppSettings` entity + repository
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/settings/domain/entities/app_settings.dart`
- `lib/features/settings/domain/repositories/settings_repository.dart`
- `lib/features/settings/data/repositories/settings_repository_impl.dart`

**Description:**
1. Add `Set<String> streakBreakNudgeDisabledModules` field to `AppSettings` Freezed entity (default to empty set).
2. Add `updateStreakBreakNudgeDisabledModules(Set<String> modules)` method to `SettingsRepository` abstract class.
3. Implement the method in `SettingsRepositoryImpl`: serialize `Set<String>` to JSON array, write to the new column.

**Acceptance criteria:**
- `AppSettings` entity compiles after codegen.
- Repository interface and impl both compile.
- Serialization round-trips correctly (`Set<String>` ↔ JSON array string).

**Test:** `flutter analyze` passes; existing settings repository tests still pass.

---

### Task 9: Wire nudge detection into `planAndApplyNotifications`
**Effort:** M
**Files to create:**
- `test/core/notifications/streak_break_nudge_integration_test.dart`

**Files to modify:**
- `lib/core/notifications/notification_planner.dart`

**Description:** In `planAndApplyNotifications`, after the existing per-module `pendingNotifications()` loop, add streak-break nudge detection:
1. For each module, call `module.streakBreakHistory()`.
2. If non-null and non-empty, get the module's current streak from its streak calculator.
3. Call `DetectStreakBreakRiskUseCase().execute(...)`.
4. If risk is not `none`, create a `PendingNotification` with:
   - `id`: `'streak_nudge_{moduleId}_{YYYYMMDD}'` (natural dedup)
   - `sourceType`: `'streak_break_nudge'`
   - `deepLinkRoute`: module's home route
   - `quietHoursSuppressible`: `true`
   - Title/body from localized strings
5. Check `streakBreakNudgeDisabledModules` — skip modules in the disabled set.

The nudge `PendingNotification` is added to the same list the existing planner deduplicates against, so same-module-same-day is automatically handled.

**Acceptance criteria:**
- Nudge notifications appear in the planner output for modules with active streaks past median time.
- Disabled modules produce no nudge.
- Same module + same day → only one nudge across multiple re-planning passes.
- No new notification channels needed.

**Test:** `flutter test test/core/notifications/streak_break_nudge_integration_test.dart` — verify correct `PendingNotification` shape, dedup behavior, opt-out behavior.

---

### Task 10: Add settings UI toggle + localization
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/settings/presentation/screens/settings_screen.dart`
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**Description:**
1. In the notification settings section of the Settings screen, add a "Streak-break nudge" `SwitchListTile` with per-module chips (Water / Medicine / Prayer) to toggle individual modules. Wire to `streakBreakNudgeDisabledModules` via a new settings controller method.
2. Add ARB keys: `streakBreakNudgeTitle`, `streakBreakNudgeDescription`, `streakBreakNudgeBody`, plus Bangla equivalents.

**Acceptance criteria:**
- Settings screen renders the new toggle.
- Per-module chips toggle on/off and persist to DB.
- `flutter gen-l10n` produces valid output with no missing keys.
- Both en/bn translations present.

**Test:** `flutter analyze` passes; manual smoke test of settings screen.

---

### Task 11: Integration tests for nudge dedup + opt-out
**Effort:** M
**Files to create:**
- `test/core/notifications/streak_break_nudge_integration_test.dart` (expansion of Task 9 file)

**Files to modify:** (none)
**Description:** Write integration-level tests that verify:
1. Nudge `PendingNotification` has correct `id`, `sourceType`, `deepLinkRoute`, `quietHoursSuppressible`.
2. Dedup: same module same day → only one nudge after multiple re-plan calls.
3. Opt-out: disabled module produces no nudge.
4. No nudge when `currentStreak == 0`.
5. No nudge when `hasLoggedToday == true`.

**Acceptance criteria:**
- All integration test cases pass.
- Tests are deterministic (mock time with `package:clock`).

**Test:** `flutter test test/core/notifications/streak_break_nudge_integration_test.dart`

---

## Schema Migration

```sql
ALTER TABLE app_settings ADD COLUMN streak_break_nudge_disabled_modules TEXT NOT NULL DEFAULT '[]';
```

Added as a Drift migration step. Default `'[]'` means all modules enabled by default (no nudge disabled).

## Localization Keys

### `app_en.arb`
| Key | Value |
|-----|-------|
| `streakBreakNudgeTitle` | `"Streak-break nudge"` |
| `streakBreakNudgeDescription` | `"Gentle reminder when a streak is at risk"` |
| `streakBreakNudgeBody` | `"You haven't logged {module} today, and your streak is at risk."` |
| `streakBreakNudgeNotificationTitle` | `"Streak at risk"` |
| `streakBreakNudgeNotificationBody` | `"You haven't logged {module} today — your {streak}-day streak is at risk."` |

### `app_bn.arb`
Bangla equivalents for all keys above.

## Risk Notes

- **False positive tuning:** The "past median" threshold may nag irregular users. The `minDaysOfHistory = 3` floor helps, but real-world tuning during dogfooding may require raising it. Keep it configurable.
- **DST transitions:** A median computation over time-of-day may produce ambiguous results on DST change days. The use case should use wall-clock time-of-day (hours + minutes), not absolute `DateTime` comparisons.
- **Background isolate compatibility:** `streakBreakHistory()` is called from the notification planner, which may run in a background isolate. Implementations must not use `Ref` or any Riverpod provider — only DB queries via the module's own repository.
- **Notification ledger namespace:** The nudge `id` uses `streak_nudge_` prefix to avoid collision with module-specific notification ids (e.g. Water uses `water_reminder_`, Medicine uses bare UUIDs). This is a soft convention — Prayer's dose ids are bare UUIDs.

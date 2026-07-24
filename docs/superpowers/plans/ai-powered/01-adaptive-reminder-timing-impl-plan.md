# Adaptive Reminder Timing — Implementation Plan

**Spec:** [Adaptive Reminder Timing Design](./01-adaptive-reminder-timing-design.md)
**Run:** TBD
**Estimated effort:** M (8 tasks)
**Dependencies:** Notification ledger (existing), `NotificationLedgerRepository`, `NotificationPlanner`, `AppSettings` table, Settings screen

## Pre-requisites
- Notification engine (`core/notifications/`) is complete and tested (Run 08+)
- `notification_ledger` table has been populated with real `done`/`actionAt` entries
- `app_settings` table exists with the `onUpgrade` migration pattern established
- Riverpod codegen, Drift, Freezed are all configured and working

---

## Tasks

### Task 1: Add `adaptiveReminderEnabled` column + migration + entity field
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/core/database/tables/app_settings_table.dart`
- `lib/core/database/app_database.dart`
- `lib/features/settings/domain/entities/app_settings.dart`
- `lib/features/settings/data/repositories/settings_repository_impl.dart`

**Description:**
1. Add a new `BoolColumn` `adaptiveReminderEnabled` to `AppSettingsTable` with `defaultValue: const Constant(false)`.
2. In `app_database.dart`, bump `schemaVersion` to 8 and add a migration block in `onUpgrade`:
   ```dart
   if (from < 8) {
     await m.addColumn(appSettingsTable, appSettingsTable.adaptiveReminderEnabled);
   }
   ```
3. Add `bool adaptiveReminderEnabled` field to the `AppSettings` Freezed class (default `false`).
4. Update `_settingsFromRow` and `updateSettings` in `SettingsRepositoryImpl` to read/write the new column.

**Acceptance criteria:**
- App compiles after `dart run build_runner build --delete-conflicting-outputs`
- `SettingsRepositoryImpl` round-trips `adaptiveReminderEnabled` through DB write/read
- Migration runs cleanly on upgrade from schema version < 8

**Test:** `test/features/settings/...settings_repository_test.dart` — extend existing tests: write `adaptiveReminderEnabled: true`, read it back, confirm value persists.

---

### Task 2: Create `ReminderAdjustment` Freezed entity
**Effort:** S
**Files to create:**
- `lib/core/notifications/entities/reminder_adjustment.dart`

**Files to modify:** (none)

**Description:**
Create the `ReminderAdjustment` Freezed sealed class in `lib/core/notifications/entities/`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'reminder_adjustment.freezed.dart';

@freezed
sealed class ReminderAdjustment with _$ReminderAdjustment {
  const factory ReminderAdjustment({
    required String moduleId,
    String? sourceType,
    required int offsetMinutes,
    required int sampleCount,
    required String confidence,
    required int windowDays,
  }) = _ReminderAdjustment;
}
```

Run `dart run build_runner build --delete-conflicting-outputs` after creating the file.

**Acceptance criteria:**
- `reminder_adjustment.freezed.dart` is generated
- File imports without errors

**Test:** No dedicated test needed — entity is a data class. Verified by compilation.

---

### Task 3: Add `actionedDoneRows()` to ledger repository
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/core/notifications/notification_ledger_repository.dart`

**Description:**
Add a new query method to `NotificationLedgerRepository`:
```dart
Future<List<NotificationLedgerRow>> actionedDoneRows({
  required int windowDays,
  required DateTime now,
}) async {
  final since = now.subtract(Duration(days: windowDays));
  return (_db.select(_db.notificationLedgerTable)
    ..where(
      (t) =>
          t.deletedAt.isNull() &
          t.action.equals('done') &
          t.actionAt.isNotNull() &
          t.scheduledFor.isBiggerOrEqualValue(
            since.toUtc().millisecondsSinceEpoch,
          ),
    ))
    .get();
}
```

**Acceptance criteria:**
- Method returns only rows where `action == 'done'`, `actionAt` is non-null, and `scheduledFor` is within the window
- Rows with `deletedAt != null` are excluded

**Test:** Extend existing ledger repository test: insert known rows (some done, some pending, some deleted), call `actionedDoneRows`, verify only the correct subset is returned.

---

### Task 4: Implement `CalculateAdaptiveOffsetUseCase`
**Effort:** M
**Files to create:**
- `lib/core/notifications/usecases/calculate_adaptive_offset_use_case.dart`
- `test/core/notifications/usecases/calculate_adaptive_offset_use_case_test.dart`

**Files to modify:** (none)

**Description:**
Implement the pure use case that computes median time offsets from ledger history:
1. Query `actionedDoneRows` for the rolling window (default 30 days).
2. Group by `(moduleId, sourceType)`.
3. For each group, compute `actionAt - scheduledFor` per row → list of offset-millis.
4. Compute **median** offset (robust to outliers).
5. Convert to minutes, clamp to `[-maxOffsetMinutes, maxOffsetMinutes]` (default ±120).
6. Classify confidence: ≥20 samples → `'high'`, ≥10 → `'medium'`, <10 → skip.
7. Return one `ReminderAdjustment` per qualifying group.

**Acceptance criteria:**
- Median calculation is correct for odd/even sample counts
- Samples below `minSamples` are excluded
- Offsets are clamped to the max
- Empty ledger returns empty list

**Test:** `test/core/notifications/usecases/calculate_adaptive_offset_use_case_test.dart` — test with known ledger snapshots: consistent offset → correct median, alternating offsets → median detection, all-same-time → 0 offset, empty ledger → empty list, single source type, multiple source types.

---

### Task 5: Add `moduleOffsetsMinutes` to `planNotifications` and wiring
**Effort:** M
**Files to create:** (none)
**Files to modify:**
- `lib/core/notifications/notification_planner.dart`

**Description:**
1. Add optional parameter `Map<String, int>? moduleOffsetsMinutes` to the `planNotifications` pure function.
2. Inside the function, when computing `scheduledAt` for each pending notification, if `moduleOffsetsMinutes` contains an entry for the current module, add the offset:
   ```dart
   final adjustedScheduledAt = pending.scheduledAt.add(
     Duration(minutes: moduleOffsetsMinutes?[moduleId] ?? 0),
   );
   ```
3. Update `planAndApplyNotifications` wiring: before calling `planNotifications`, check `adaptiveReminderEnabled` from settings. If enabled, run `CalculateAdaptiveOffsetUseCase` to build the `moduleOffsetsMinutes` map, then pass it through.

**Acceptance criteria:**
- When `moduleOffsetsMinutes` is null or empty, behavior is identical to before (no regression)
- When an offset is provided, `scheduledAt` is shifted by that many minutes
- Offsets interact correctly with the existing window/cap/diff logic

**Test:** `test/core/notifications/notification_planner_test.dart` (extend existing) — test offset shifts `scheduledAt`, offset of 0 is identity, absent module key is no-op, combined with quiet hours.

---

### Task 6: Settings toggle UI + localization
**Effort:** S
**Files to create:** (none)
**Files to modify:**
- `lib/features/settings/presentation/screens/` (settings screen)
- `lib/features/settings/presentation/providers/` (toggle provider)
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**Description:**
1. Add a `SwitchListTile` toggle for "Adaptive Reminders" in the Settings screen, below the existing reminder-related settings.
2. Brief explainer text below the toggle: "Automatically adjust reminder times based on when you typically respond."
3. Expose a provider/method to read and write `adaptiveReminderEnabled` through the settings controller.
4. Add ARB keys for all new strings (see Localization Keys below).
5. Run `flutter gen-l10n`.

**Acceptance criteria:**
- Toggle persists to `app_settings.adaptiveReminderEnabled`
- Toggle state reflects the DB value on app restart
- Strings appear in both en and bn

**Test:** Widget test verifying the toggle appears, toggles, and calls the settings controller.

---

### Task 7: Unit tests for use case + planner changes
**Effort:** M
**Files to create:** (none)
**Files to modify:**
- `test/core/notifications/usecases/calculate_adaptive_offset_use_case_test.dart` (created in T4, expand if needed)
- `test/core/notifications/notification_planner_test.dart`

**Description:**
Ensure full test coverage for the use case and planner integration:
- Use case: all edge cases from T4
- Planner: offset integration, offset + quiet hours interaction, offset + window/cap boundary behavior
- Settings: `adaptiveReminderEnabled` round-trip

**Acceptance criteria:**
- `flutter test test/core/notifications/usecases/calculate_adaptive_offset_use_case_test.dart` passes
- `flutter test test/core/notifications/notification_planner_test.dart` passes
- `flutter test test/features/settings/...settings_repository_test.dart` passes

**Test:** Run each test file individually with `flutter test <path>`.

---

### Task 8: Integration test / manual verification
**Effort:** S
**Files to create:** (none)
**Files to modify:** (none)

**Description:**
Manual verification checklist:
1. Enable the Adaptive Reminders toggle in Settings
2. Simulate multiple `done` actions with consistent offset (e.g. always respond 30 min late)
3. Trigger `planAndApplyNotifications` and verify scheduled times are shifted
4. Disable the toggle — verify shifts stop
5. Verify no regression: existing notifications still schedule correctly when toggle is off
6. Test with empty ledger (new install) — no crash, no suggestions

**Acceptance criteria:**
- All checklist items pass
- No crashes or regressions in notification scheduling

**Test:** Manual QA — no automated test file needed.

---

## Schema Migration

**Table:** `app_settings`  
**Change:** Add column `adaptive_reminder_enabled INTEGER NOT NULL DEFAULT 0`

```sql
ALTER TABLE app_settings ADD COLUMN adaptive_reminder_enabled INTEGER NOT NULL DEFAULT 0;
```

**Drift migration (in `app_database.dart`):**
```dart
if (from < 8) {
  await m.addColumn(appSettingsTable, appSettingsTable.adaptiveReminderEnabled);
}
```

**Bump:** `schemaVersion` from 7 to 8.

---

## Localization Keys

| Key | en | bn |
|-----|----|----|
| `adaptiveReminderTitle` | Adaptive Reminders | অভিযোজিত রিমাইন্ডার |
| `adaptiveReminderDescription` | Automatically adjust reminder times based on when you typically respond. | আপনি সাধারণত কখন উত্তর দেন তার ভিত্তিতে রিমাইন্ডার সময় স্বয়ংক্রিয়ভাবে সামঞ্জস্য করুন। |
| `adaptiveReminderToggleLabel` | Enable adaptive reminders | অভিযোজিত রিমাইন্ডার সক্রিয় করুন |

---

## Risk Notes

- **Median vs mean:** Median is chosen for robustness against outliers (e.g. overnight Snooze chains). If the codebase later needs per-module vs per-slot granularity, the `sourceType` field on `ReminderAdjustment` already supports it.
- **Max offset clamp:** Hard-capped at ±120 minutes. This prevents absurd shifts (e.g. user went on vacation and missed 2 weeks of reminders).
- **Empty ledger on new installs:** The use case returns an empty list. No suggestions are surfaced until ≥10 samples accumulate.
- **Planner regression risk:** The `planNotifications` pure function is well-tested. Adding an optional parameter preserves backward compatibility, but the offset-adjusted `scheduledAt` must still pass through the existing window/cap/diff logic correctly — test this explicitly.
- **No new packages required.** This is arithmetic over existing data.

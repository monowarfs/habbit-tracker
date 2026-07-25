# Implementation Plan: Personal-Record Tracking

**Spec:** `02-personal-record-tracking-design.md`
**Complexity:** S · **Estimated effort:** 1 day
**Depends on:** Reports module, `longestStreak()` from `day_status_streaks.dart`

---

## Task 1: Create personal record repository

**File:** `lib/core/analytics/personal_record_repository.dart`

```dart
class PersonalRecordRepository {
  final AppDatabase db;

  Future<PersonalRecord?> getRecord({
    required String moduleId,
    required String recordType,
  });

  Future<void> setRecord({
    required String moduleId,
    required String recordType,
    required int value,
  });

  /// Checks if [newValue] exceeds the current record.
  /// If so, updates and returns true.
  Future<bool> checkAndUpdate({
    required String moduleId,
    required String recordType,
    required int newValue,
  });
}
```

---

## Task 2: Add `personal_records` Drift table

**File:** `lib/core/database/app_database.dart`

```dart
class PersonalRecords extends Table {
  TextColumn get id => text()();
  TextColumn get moduleId => text()();
  TextColumn get recordType => text()();
  IntColumn get recordValue => integer()();
  IntColumn get achievedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}
```

---

## Task 3: Create record detection use case

**File:** `lib/core/analytics/record_detection_use_case.dart`

```dart
class RecordDetectionUseCase {
  final PersonalRecordRepository repo;

  /// Checks if a new streak/adherence value breaks the record.
  /// Returns RecordBrokenEvent if so.
  Future<RecordBrokenEvent?> checkRecord({
    required String moduleId,
    required String recordType,
    required int currentValue,
  }) async {
    final broken = await repo.checkAndUpdate(
      moduleId: moduleId,
      recordType: recordType,
      newValue: currentValue,
    );
    if (broken) {
      return RecordBrokenEvent(
        moduleId: moduleId,
        recordType: recordType,
        newValue: currentValue,
      );
    }
    return null;
  }
}
```

---

## Task 4: Wire to achievement engine

**File:** `lib/core/analytics/record_integration.dart`

After each streak calculation, check for record break:
```dart
Future<void> checkRecordsAfterStreak({
  required String moduleId,
  required int currentStreak,
}) async {
  final event = await recordDetectionUseCase.checkRecord(
    moduleId: moduleId,
    recordType: 'longest_streak',
    newValue: currentStreak,
  );
  if (event != null) {
    // Show "New Record!" celebration
  }
}
```

---

## Task 5: Add record display to stats screens

**Files:** Per-module stats screens (`water_stats_screen.dart`, etc.)

Add a "Personal Record" section showing:
- Current longest streak: X days
- Badge/celebration if this is a new record

---

## Task 6: Backfill on first launch

**File:** `lib/core/analytics/record_backfill.dart`

On feature first launch, compute all-time records from historical data
and persist them to `personal_records` table.

---

## Task 7: Add localization strings

```json
"personalRecordTitle": "Personal Record",
"personalRecordLongestStreak": "Longest Streak: {count} days",
"personalRecordNewRecord": "New Record!",
"personalRecordPrevious": "Previous: {count} days"
```

---

## Performance considerations

- **Record check:** O(1) comparison against persisted value. No scan.
- **Backfill:** runs once on first launch, caches result.
- **Caching:** record values are persisted — no recomputation needed.

## Testing

- `test/core/analytics/personal_record_repository_test.dart` — CRUD
  tests.
- Unit test: record detection (new record vs. no record).
- Unit test: backfill from historical data.
- Widget test: "New Record!" celebration display.

## Localization

ARB keys listed in Task 7.

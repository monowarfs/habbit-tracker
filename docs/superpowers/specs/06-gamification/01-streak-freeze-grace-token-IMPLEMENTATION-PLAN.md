# Implementation Plan: Streak Freeze / Grace Token

**Spec:** 01-streak-freeze-grace-token-design.md
**Complexity:** M | **Estimated effort:** 2 days
**Dependencies:** Existing streak calculators (Water/Medicine/Prayer), dashboard day-completion indicator, history calendar

---

## Overview

A once-per-calendar-month grace token per module that protects a streak from resetting after a single missed day. The token is consumed when applied, marking the day as "protected" rather than "completed" in history. Core logic extends existing streak calculators with a `protectedMiss` concept.

---

## Implementation Tasks

### Task 1: Grace Token Drift Table

**Files to create/modify:**
- `lib/core/database/tables/grace_tokens_table.dart` (create)
- `lib/core/database/app_database.dart` (modify — add to tables list + migration)

**Drift table definition:**
```dart
@DataClassName('GraceTokenRow')
class GraceTokensTable extends Table {
  @override
  String get tableName => 'grace_tokens';

  TextColumn get id => text()();
  TextColumn get moduleId => text()();        // 'water' | 'medicine' | 'prayer'
  TextColumn get monthKey => text()();         // 'YYYY-MM' format
  IntColumn get consumedAt => integer().nullable()(); // null = available, non-null = used
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {moduleId, monthKey},
  ];
}
```

**Database migration:** Add `if (from < 18)` block in `app_database.dart` calling `m.createTable(graceTokensTable)`. Bump `schemaVersion` to 18.

**Integration:** Add import and table to the `@DriftDatabase(tables: [...])` list.

---

### Task 2: Grace Token Repository

**Files to create:**
- `lib/core/gamification/grace_token_repository.dart`

**Classes/methods:**
```dart
class GraceTokenRepository {
  GraceTokenRepository(this._db);
  final AppDatabase _db;

  /// Returns the token row for [moduleId] in [monthKey], or null.
  Future<GraceTokenRow?> findByModuleAndMonth(String moduleId, String monthKey);

  /// Returns true if a token is still available (consumedAt == null).
  Future<bool> isAvailable(String moduleId, String monthKey);

  /// Consumes the token — sets consumedAt to now.
  Future<void> consume(String moduleId, String monthKey, {required DateTime now});

  /// Ensures a token row exists for the given module/month (upsert).
  Future<void> ensureTokenExists(String moduleId, String monthKey, {required DateTime now});
}
```

**Integration:** Use `generateId()` from `core/utils/uuid.dart` for new row IDs. Follow same pattern as `AchievementRepository` (constructor takes `AppDatabase`).

---

### Task 3: Grace-Aware Streak Calculator Extension

**Files to modify:**
- `lib/features/water/domain/usecases/calculate_water_streak.dart`

**Changes:**
- Add optional `Set<LocalDate> graceProtectedDays` parameter to `execute()` (default empty set).
- When a day would break the streak AND is in `graceProtectedDays`, treat it as neutral (streak not broken, not incremented).
- A grace-protected day does NOT add to the running streak count — it only prevents the reset.

**New use case file:**
- `lib/core/gamification/resolve_grace_token_usecase.dart`

```dart
class ResolveGraceTokenUseCase {
  const ResolveGraceTokenUseCase({required this.repository});
  final GraceTokenRepository repository;

  /// Returns the set of dates where a grace token was applied for [moduleId].
  Future<Set<LocalDate>> protectedDaysForModule(
    String moduleId, DateRange range,
  );

  /// Consumes a grace token for [moduleId] in the current calendar month.
  Future<void> consumeToken(String moduleId, {required DateTime now});

  /// Returns whether a token is still available for this month.
  Future<bool> isTokenAvailable(String moduleId, {required DateTime now});
}
```

**Integration:** Each module's controller (Water's `WaterController`, Medicine's controller, Prayer's controller) calls `resolveGraceToken` before passing `graceProtectedDays` to the streak calculator. The `dayStatus()` implementation in each module also consults grace-protected days to mark them as a distinct status.

---

### Task 4: ModuleDayStatus Extension for Grace-Protected Days

**Files to modify:**
- `lib/core/modules/habit_module.dart`

**Changes:**
Add a new `ModuleDayStatusKind` value:
```dart
enum ModuleDayStatusKind {
  complete,
  partial,
  missed,
  paused,
  none,
  graceProtected, // NEW — streak preserved but not incremented
}
```

**Integration:** Each module's `dayStatus()` method returns `graceProtected` for days where the grace token was consumed, instead of `missed`. This requires each module to consult `GraceTokenRepository` when computing day status.

---

### Task 5: Dashboard Shield Icon

**Files to modify:**
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

**Changes:**
- In `_DayCompletionIndicator`, add logic to detect if today is a grace-protected day.
- Display a small shield icon overlay when a grace token has been used this month.
- Add a `GraceTokenIndicator` widget that shows "Grace token used" / "Grace token available" status.

**New widget file:**
- `lib/features/dashboard/presentation/widgets/grace_token_indicator.dart`

```dart
class GraceTokenIndicator extends ConsumerWidget {
  /// Shows shield icon + "Grace token available" or "Used this month".
}
```

---

### Task 6: History Calendar Shield Visual

**Files to modify (per-module stats screens):**
- Water history calendar widget (in `lib/features/water/presentation/`)
- Medicine dose timeline
- Prayer history calendar

**Changes:**
- Days marked as `graceProtected` render with a distinct visual: a small shield icon overlay on the calendar cell.
- Use the existing `GlobalMonthCalendar` widget's `statusesByModule` — the `graceProtected` kind triggers a different cell color/icon.

---

### Task 7: Retroactive Grace Token Application UI

**Files to create:**
- `lib/core/gamification/grace_token_dialog.dart`

**Widget:**
```dart
Future<bool> showGraceTokenDialog(BuildContext context, {
  required String moduleId,
  required LocalDate missedDay,
});
```

**Changes to dashboard/module screens:**
- When a user taps a `missed` day in the history calendar, if a grace token is available, show an option to "Protect this day with grace token".
- On confirmation, consume the token and refresh the day status.

---

### Task 8: Localization

**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**ARB keys to add:**
```
"graceTokenUsedTitle": "Grace Token Used",
"graceTokenUsedBody": "Your streak was protected for {date}.",
"graceTokenAvailable": "Grace token available",
"graceTokenUnavailable": "No grace tokens remaining this month",
"graceTokenShieldLabel": "Grace-protected day",
"graceTokenApplyTitle": "Protect this day?",
"graceTokenApplyBody": "Use your monthly grace token to keep your streak alive?",
"graceTokenApplyButton": "Use Grace Token",
"graceTokenNextReset": "Next token available {date}"
```

---

## Performance Considerations

- **Caching:** Cache grace token availability per module in memory (invalidate on month boundary). The `isAvailable` query is a single-row lookup by `(moduleId, monthKey)` — fast, but avoiding re-querying on every frame matters.
- **Lazy loading:** Grace token status for non-current months is never queried. Only the current `monthKey` is relevant for availability checks.
- **Memory:** `graceProtectedDays` set per module is small (max 1 per month = 12/year).

---

## Testing

**Files to create:**
- `test/core/gamification/grace_token_repository_test.dart`
- `test/core/gamification/resolve_grace_token_usecase_test.dart`
- `test/features/water/domain/usecases/calculate_water_streak_grace_test.dart`
- `test/features/dashboard/presentation/widgets/grace_token_indicator_test.dart`
- `test/core/gamification/grace_token_dialog_test.dart`

**Coverage:**
| Test | Covers |
|---|---|
| `grace_token_repository_test.dart` | Token creation, consumption, availability, month boundary |
| `resolve_grace_token_usecase_test.dart` | Token consumption logic, month rollover, double-consume prevention |
| `calculate_water_streak_grace_test.dart` | Streak with grace-protected day (preserved), streak without (broken), consecutive misses |
| `grace_token_indicator_test.dart` | Shield icon renders when available, hides when consumed |
| `grace_token_dialog_test.dart` | Dialog shows when token available, hides when consumed |

---

## Edge Cases

- **Medicine partial-day completion:** A day with 4/5 doses is NOT a miss — Medicine's `effectiveDoseStatus` already handles this. Grace token only fires when the day is classified as `missed`.
- **Retroactive application:** Token can be applied after the fact. Consumes the current month's token, does NOT restore the streak — only prevents the break.
- **Month boundary:** Miss on last day of month, token applied after midnight → consumes new month's token. Acceptable per spec.
- **All tokens consumed:** Show "No grace tokens remaining this month" with reset date message.
- **Month key generation:** Use `DateTime(year, month)` → `'YYYY-MM'` format. DST-safe since `localDayKey` is already used elsewhere.

# Implementation Plan: Additional Habit Modules Pack

**Spec:** `04-additional-habit-modules-pack-design.md`
**Complexity:** M · **Estimated effort:** 10-12 days (4 modules × 2-3 days each)
**Depends on:** `HabitModule` contract, spec 07 (entitlements), `docs/strategies/future-expansion.md`

---

## Task 1: Sleep Module

### Task 1.1: Domain entities
**File:** `lib/features/sleep/domain/entities/sleep_log.dart`

```dart
@freezed
class SleepLog with _$SleepLog {
  const factory SleepLog({
    required String id,
    required DateTime bedTime,
    required DateTime wakeTime,
    required int durationMinutes,
    int? quality, // 1-5
    required DateTime createdAt,
  }) = _SleepLog;
}
```

### Task 1.2: Drift table
**File:** `lib/core/database/app_database.dart`

Add `sleep_logs` table: `id`, `profile_id`, `bed_time`, `wake_time`,
`duration_minutes`, `quality`, `created_at`, `updated_at`, `deleted_at`.

### Task 1.3: Repository
**File:** `lib/features/sleep/data/repositories/sleep_repository_impl.dart`

Methods: `logSleep`, `getLogs`, `getStreak`, `deleteLog`.

### Task 1.4: Use cases
**Files:** `lib/features/sleep/domain/usecases/`
- `log_sleep_use_case.dart` — validates bed/wake times.
- `calculate_sleep_streak.dart` — consecutive nights with logs.

### Task 1.5: Module implementation
**File:** `lib/features/sleep/sleep_module.dart`

Implement `HabitModule` with all required methods.

### Task 1.6: Presentation
**Files:** `lib/features/sleep/presentation/`
- Screens: home, log form, stats, history.
- Providers: sleep logs, streak, settings.

### Task 1.7: Register in module_registry.dart

### Task 1.8: Localization keys

### Task 1.9: Tests

---

## Task 2: Blood Pressure Module

### Task 2.1: Domain entities
**File:** `lib/features/blood_pressure/domain/entities/blood_pressure_log.dart`

```dart
@freezed
class BloodPressureLog with _$BloodPressureLog {
  const factory BloodPressureLog({
    required String id,
    required int systolic,
    required int diastolic,
    int? pulse,
    String? note,
    required DateTime loggedAt,
    required BpClassification classification,
  }) = _BloodPressureLog;
}

enum BpClassification {
  normal, elevated, hypertension1, hypertension2, hypertensionCrisis
}
```

### Task 2.2: Drift tables
Add `blood_pressure_logs` and `blood_pressure_classifications` tables.

### Task 2.3: Repository + use cases
- `classify_bp_use_case.dart` — pure classifier based on AHA guidelines.
- `bp_repository_impl.dart` — CRUD + trend queries.

### Task 2.4: Module implementation
**File:** `lib/features/blood_pressure/blood_pressure_module.dart`

### Task 2.5: Presentation
Screens: home, log form, trend chart, history.

### Task 2.6: Register + localize + test

---

## Task 3: Mood Module

### Task 3.1: Domain entities
**File:** `lib/features/mood/domain/entities/mood_log.dart`

```dart
@freezed
class MoodLog with _$MoodLog {
  const factory MoodLog({
    required String id,
    required int moodValue, // 1-5
    String? emoji,
    String? note,
    required DateTime loggedAt,
  }) = _MoodLog;
}
```

### Task 3.2: Drift table
Add `mood_logs` table.

### Task 3.3: Repository + use cases
- `log_mood_use_case.dart`
- `calculate_mood_streak.dart`

### Task 3.4: Module implementation
**File:** `lib/features/mood/mood_module.dart`

### Task 3.5: Presentation
Screens: home (quick log), history, stats (mood distribution chart).

### Task 3.6: Register + localize + test

---

## Task 4: Exercise Module

### Task 4.1: Domain entities
**File:** `lib/features/exercise/domain/entities/exercise_log.dart`

```dart
@freezed
class ExerciseLog with _$ExerciseLog {
  const factory ExerciseLog({
    required String id,
    required String exerciseType,
    required int durationMinutes,
    int? calories,
    String? note,
    required DateTime loggedAt,
  }) = _ExerciseLog;
}
```

### Task 4.2: Drift tables
Add `exercise_logs` and `exercise_settings` tables.

### Task 4.3: Repository + use cases
- `log_exercise_use_case.dart`
- `calculate_exercise_streak.dart`
- `aggregate_weekly_minutes.dart`

### Task 4.4: Module implementation
**File:** `lib/features/exercise/exercise_module.dart`

### Task 4.5: Presentation
Screens: home, log form, stats (weekly minutes chart), history.

### Task 4.6: Register + localize + test

---

## Task 5: Premium gate in module_registry.dart

Wrap the four new modules in a premium check:
```dart
if (entitlementService.isPremium) ...[
  (id: 'sleep', module: SleepModule(...)),
  // ...
]
```

---

## Task 6: Add all tables to AppDatabase

Add all new table classes to `AppDatabase`'s table manifest.

---

## Task 7: Run build_runner and gen-l10n

```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

---

## Review checklist

- [ ] Each module implements all `HabitModule` methods.
- [ ] No changes to Water/Medicine/Prayer code.
- [ ] All new tables in `AppDatabase`.
- [ ] en/bn localization for all modules.
- [ ] Premium gate hides modules for non-premium users.
- [ ] Each module has unit tests for use cases.

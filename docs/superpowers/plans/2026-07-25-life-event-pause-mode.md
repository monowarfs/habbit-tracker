# Life-Event Pause Mode (Travel / Illness) — Implementation Plan

**Spec:** `docs/superpowers/specs/09-retention/04-life-event-pause-mode-design.md`
**Date:** 2026-07-25
**Status:** Ready for implementation

---

## Architecture overview

```
┌──────────────────────────────────────────────────────────┐
│  Module screen / Settings                                │
│  → "Pause" button → date-range picker → create pause     │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  core/pauses/pause_repository.dart                       │
│  CRUD for pause_ranges table                             │
│  validates no overlapping pauses per module              │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  core/pauses/pause_service.dart                          │
│  createPause → suppress notifications for range          │
│  cancelPause → resume notifications                      │
│  activePauses(moduleId) → Set<LocalDate>                 │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  dayStatus() → paused for days in active pause ranges    │
│  streak calculators → skip paused days                   │
│  notification planner → skip paused module during range  │
└──────────────────────────────────────────────────────────┘
```

---

## Resolved dependencies

| Dep | Source |
|-----|--------|
| `ModuleDayStatusKind.paused` | Spec 01 T3 |
| Pause-aware streak calculators | Spec 01 T3 |
| Schema migration v10 | Spec 01 T1 |

---

## Implementation tasks

### T1: Schema migration — `pause_ranges` table

**Files:**
- `lib/core/database/tables/pause_ranges_table.dart` — **new file**
- `lib/core/database/app_database.dart` — add `PauseRangesTable`, bump `schemaVersion` to 13

**Table definition:**
```dart
@DataClassName('PauseRangeRow')
class PauseRangesTable extends Table {
  @override
  String get tableName => 'pause_ranges';

  TextColumn get id => text()();
  TextColumn get moduleId => text()();        // 'water', 'medicine', 'prayer'
  TextColumn get startDate => text()();       // 'YYYY-MM-DD' local
  TextColumn get endDate => text()();         // 'YYYY-MM-DD' local
  IntColumn get createdAt => integer()();     // UTC epoch millis

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [];
}
```

**Migration (from < 13):**
```dart
if (from < 13) {
  await m.createTable(pauseRangesTable);
}
```

**Tests:** Migration test.

---

### T2: `PauseRepository` — CRUD + overlap validation

**Files:**
- `lib/core/pauses/pause_repository.dart` — **new file**

```dart
class PauseRepository {
  const PauseRepository(this._db);
  final AppDatabase _db;

  /// All pauses for [moduleId], ordered by start date.
  Future<List<PauseRangeRow>> forModule(String moduleId);

  /// All active (not yet ended) pauses for [moduleId].
  Future<List<PauseRangeRow>> activeForModule(String moduleId);

  /// Overlapping pauses for [moduleId] that intersect [start, end].
  Future<List<PauseRangeRow>> overlapping({
    required String moduleId,
    required LocalDate start,
    required LocalDate end,
    String? excludeId,
  });

  /// Creates a pause. Throws if overlapping (caller must check first).
  Future<void> create(PauseRangeRow pause);

  /// Cancels/deletes a pause by id.
  Future<void> cancel(String id);

  /// All pauses across all modules (for settings/past-pauses view).
  Future<List<PauseRangeRow>> all();
}
```

**Tests:** `test/core/pauses/pause_repository_test.dart` — CRUD, overlap detection, per-module isolation.

---

### T3: `PauseService` — business logic + notification suppression

**Files:**
- `lib/core/pauses/pause_service.dart` — **new file**

```dart
class PauseService {
  const PauseService({
    required this.pauseRepository,
    required this.notificationService,
  });

  /// Creates a pause, validates no overlaps, suppresses notifications.
  Future<void> createPause({
    required String moduleId,
    required LocalDate startDate,
    required LocalDate endDate,
  });

  /// Cancels a pause, re-enables notifications.
  Future<void> cancelPause(String pauseId);

  /// Returns the set of paused days for [moduleId] within [range].
  /// Used by streak calculators and dayStatus.
  Future<Set<LocalDate>> pausedDaysInRange({
    required String moduleId,
    required DateRange range,
  });

  /// All active pause ranges for [moduleId].
  Future<List<PauseRangeRow>> activePauses(String moduleId);
}
```

**Notification suppression on create:**
1. Query pending notifications for this module via ledger.
2. Cancel each via `NotificationService.cancel()`.
3. Mark them as cancelled in the ledger.

**Notification re-enable on cancel:**
- No immediate action needed — the planner re-plans on next app resume, which will re-schedule anything due.

**Tests:** `test/core/pauses/pause_service_test.dart` — create with overlap rejection, cancel, paused days computation.

---

### T4: `dayStatus()` integration — paused days

**Files:**
- `lib/features/water/water_module.dart` — in `dayStatus()`, for each day in range, check if it falls in any active pause. If so, return `ModuleDayStatusKind.paused`.
- `lib/features/medicine/medicine_module.dart` — same.
- `lib/features/prayer/prayer_module.dart` — same.

**Integration approach:** Each module's `dayStatus` already walks days. Add a pre-computed `Set<LocalDate> pausedDays` (fetched once per `dayStatus` call) and check membership. This is O(1) per day.

**Tests:** Verify `dayStatus` returns `paused` for days within a pause range.

---

### T5: Streak calculators — pause-aware (final wiring)

**Files:**
- `lib/features/water/domain/usecases/calculate_water_streak.dart` — already has `pausedDays` param from Spec 01 T3. Now wire it from the Water controller.
- `lib/features/medicine/domain/usecases/calculate_adherence.dart` — same.
- `lib/features/prayer/domain/usecases/calculate_prayer_streak.dart` — same.

**Wiring in controllers:**
- `lib/features/water/presentation/providers/water_controller.dart` — when computing streaks, fetch `pausedDaysInRange` and pass to `CalculateWaterStreakUseCase`.
- Medicine/Prayer controllers — same pattern.

**Tests:** Streak calculation with active pauses — verify streak continuity across pause boundaries.

---

### T6: Pause UI — create/edit/cancel

**Files:**
- `lib/core/pauses/pause_providers.dart` — **new file**, Riverpod providers
- `lib/features/water/presentation/screens/water_settings_screen.dart` — add "Pause Water" option
- `lib/features/medicine/presentation/screens/medicine_home_screen.dart` — add "Pause" option (per-schedule)
- `lib/core/pauses/presentation/create_pause_screen.dart` — **new file**, date-range picker
- `lib/core/pauses/presentation/active_pauses_card.dart` — **new file**, shows active pause with cancel button

**Create pause screen:**
- Module selector (if called from a global pause entry) or pre-selected (if called from module screen).
- Start date picker, end date picker.
- Validation: end > start, no overlaps.
- "Create" button → calls `PauseService.createPause`.
- Backfill confirmation: if start date is in the past, show "This will mark days X–Y as paused. Continue?"

**Active pauses card:**
- Shown at top of module screen if an active pause exists.
- Shows "Paused from X to Y" with "Cancel Pause" button.
- Tap cancel → confirmation → calls `PauseService.cancelPause`.

**Tests:** Widget tests for create screen, active pauses card, backfill confirmation.

---

### T7: Dashboard day-completion indicator — paused state

**Files:**
- `lib/core/widgets/global_month_calendar.dart` — add paused color/style for `ModuleDayStatusKind.paused`
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` — no changes needed (calendar already reads `dayStatus`)

**Visual:** Paused days render with a distinct muted color (e.g., gray with a small pause icon or hatched pattern), different from green (complete), yellow (partial), red (missed).

**Tests:** Calendar rendering test with paused days.

---

### T8: Achievement freeze during pause

**Files:**
- `lib/core/achievements/achievement_engine.dart` — add pause awareness: when evaluating achievements for a module, exclude paused days from progress calculation
- `lib/core/achievements/achievement_repository.dart` — no schema changes needed (progress is stored as a count, not date-bounded)

**Approach:** The achievement engine's `evaluate` calls `definition.currentProgress()` which is a closure over the module's own use cases. Since the use cases now accept `pausedDays`, achievements automatically freeze when the module is paused — the progress count doesn't increase during the pause.

**Tests:** Verify achievement progress doesn't advance during a pause.

---

### T9: Settings — pause management

**Files:**
- `lib/features/settings/presentation/screens/settings_home_screen.dart` — add "Manage Pauses" entry (optional, could also live per-module)

**Tests:** Settings navigation test.

---

### T10: Localization

**Files:**
- `lib/core/l10n/app_en.arb` — ~20 new keys
- `lib/core/l10n/app_bn.arb` — Bangla translations

**Keys:**
- `pauseModuleTitle` — "Pause {module}"
- `pauseStartDate` — "Start date"
- `pauseEndDate` — "End date"
- `pauseCreateButton` — "Create Pause"
- `pauseCancelButton` — "Cancel Pause"
- `pauseConfirmCreate` — "Pause {module} from {start} to {end}?"
- `pauseConfirmBackfill` — "This will mark days {start}–{end} as paused. Continue?"
- `pauseConfirmCancel` — "Cancel this pause? Streaks will resume."
- `pauseActiveLabel` — "Paused until {date}"
- `pauseOverlapError` — "This range overlaps with an existing pause."
- `pauseEmptyState` — "No active pauses."
- `pausePastTitle` — "Past Pauses"

---

## Task sequencing

```
T1 (schema) ──→ T2 (repository) ──→ T3 (service) ──→ T4 (dayStatus)
                                                       │
T5 (streak wiring) ────────────────────────────────────┘
                                                       │
T6 (UI) ──→ T7 (calendar) ──→ T8 (achievements) ──→ T10 (i18n)
                                                      T9 (settings)
```

---

## Commit plan

| Commit | Tasks | Message |
|--------|-------|---------|
| 1 | T1 | `feat(db): add pause_ranges table (migration 13)` |
| 2 | T2 | `feat(pauses): add PauseRepository with overlap validation` |
| 3 | T3 | `feat(pauses): add PauseService with notification suppression` |
| 4 | T4 | `feat: dayStatus returns paused for days within active pause ranges` |
| 5 | T5 | `feat: wire pause-aware pausedDays into streak calculators` |
| 6 | T6 | `feat(pauses): add create/edit/cancel pause UI` |
| 7 | T7 | `feat(dashboard): render paused days with distinct visual indicator` |
| 8 | T8 | `feat(achievements): freeze progress during module pauses` |
| 9 | T9 | `feat(settings): add pause management entry` |
| 10 | T10 | `feat(i18n): add en/bn strings for pause mode` |

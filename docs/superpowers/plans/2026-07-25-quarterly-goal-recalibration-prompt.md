# Quarterly Goal-Recalibration Prompt — Implementation Plan

**Spec:** `docs/superpowers/specs/09-retention/05-quarterly-goal-recalibration-prompt-design.md`
**Date:** 2026-07-25
**Status:** Ready for implementation

---

## Architecture overview

```
┌──────────────────────────────────────────────────────────┐
│  Module screen (Water/Medicine)                          │
│  → on build, check recalibration trigger                 │
│  → if due, show inline RecalibrationCard at top          │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  core/recalibration/recalibration_trigger.dart           │
│  pure logic: compare lastGoalEditedAt vs now             │
│  returns RecalibrationAction { none | show | ... }       │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  core/recalibration/recalibration_repository.dart        │
│  reads/writes last_shown_at per module                   │
│  reads lastGoalEditedAt from module's goal entity        │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  presentation/widgets/recalibration_card.dart            │
│  inline banner: "Is your goal still right?"              │
│  "Still right" → dismiss + 90-day timer                  │
│  "Remind later" → dismiss + 30-day timer                 │
└──────────────────────────────────────────────────────────┘
```

---

## Resolved dependencies

| Dep | Source |
|-----|--------|
| `installDate` on `AppSettings` | Spec 01 T1-T2 |
| Schema migration v10 | Spec 01 T1 |

---

## Implementation tasks

### T1: Schema migration — per-module recalibration timestamps

**Files:**
- `lib/core/database/tables/recalibration_markers_table.dart` — **new file**
- `lib/core/database/app_database.dart` — add `RecalibrationMarkersTable`, bump `schemaVersion` to 14

**Table definition:**
```dart
@DataClassName('RecalibrationMarkerRow')
class RecalibrationMarkersTable extends Table {
  @override
  String get tableName => 'recalibration_markers';

  TextColumn get moduleId => text()();       // 'water', 'medicine'
  IntColumn get lastShownAt => integer()();  // UTC epoch millis
  IntColumn get lastGoalEditedAt => integer()(); // UTC epoch millis
  IntColumn get consecutiveDismissals => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {moduleId};
}
```

**Migration (from < 14):**
```dart
if (from < 14) {
  await m.createTable(recalibrationMarkersTable);
}
```

**Seeding:** On first app open after migration, seed each active module's marker with `lastShownAt = installDate`, `lastGoalEditedAt = installDate`. This ensures the first prompt appears 90 days after install.

---

### T2: `RecalibrationRepository` — marker CRUD

**Files:**
- `lib/core/recalibration/recalibration_repository.dart` — **new file**

```dart
class RecalibrationRepository {
  const RecalibrationRepository(this._db);
  final AppDatabase _db;

  /// Gets the marker for [moduleId], seeding defaults if absent.
  Future<RecalibrationMarkerRow> forModule(String moduleId);

  /// Records that the prompt was shown now.
  Future<void> markShown(String moduleId);

  /// Records that the user dismissed with "Still right" (reset to 90 days).
  Future<void> markConfirmed(String moduleId);

  /// Records that the user dismissed with "Remind later" (reset to 30 days).
  Future<void> markDeferred(String moduleId);

  /// Records that the goal was edited (resets timer to now = 90 days out).
  Future<void> markGoalEdited(String moduleId);
}
```

**Tests:** `test/core/recalibration/recalibration_repository_test.dart`

---

### T3: Recalibration trigger logic (pure)

**Files:**
- `lib/core/recalibration/recalibration_trigger.dart` — **new file**, pure logic

```dart
enum RecalibrationAction {
  /// No recalibration due.
  none,

  /// Show the recalibration prompt.
  showPrompt,
}

/// Maximum prompts per app session (cap at 2 per spec).
const maxPromptsPerSession = 2;

RecalibrationAction checkRecalibration({
  required DateTime lastGoalEditedAt,
  required DateTime lastShownAt,
  required int consecutiveDismissals,
  required DateTime now,
  required bool recalibrationEnabled,
});
```

**Logic:**
1. If `!recalibrationEnabled`, return `none`.
2. Compute `daysSinceEdit = now.difference(lastGoalEditedAt).inDays`.
3. If `daysSinceEdit < 90`, return `none`.
4. Compute `daysSinceShown = now.difference(lastShownAt).inDays`.
5. If `daysSinceShown < 30`, return `none`.
6. Return `showPrompt`.

**Fatigue backoff:**
- `consecutiveDismissals >= 3` → extend interval to 60 days (check `daysSinceShown < 60`).
- `consecutiveDismissals >= 5` → extend to 90 days.

**Tests:** `test/core/recalibration/recalibration_trigger_test.dart` — pure unit tests.

---

### T4: `RecalibrationService` — orchestration

**Files:**
- `lib/core/recalibration/recalibration_service.dart` — **new file**

```dart
class RecalibrationService {
  const RecalibrationService({required this.repository});

  final RecalibrationRepository repository;

  /// Checks if a recalibration prompt is due for [moduleId].
  Future<bool> isDue(String moduleId, {required bool enabled});

  /// Marks the prompt as shown.
  Future<void> onPromptShown(String moduleId);

  /// Handles "Still right" dismissal.
  Future<void> onConfirmed(String moduleId);

  /// Handles "Remind later" dismissal.
  Future<void> onDeferred(String moduleId);

  /// Records a goal edit (resets timer).
  Future<void> onGoalEdited(String moduleId);
}
```

**Tests:** `test/core/recalibration/recalibration_service_test.dart`

---

### T5: `RecalibrationCard` — inline prompt widget

**Files:**
- `lib/core/recalibration/presentation/widgets/recalibration_card.dart` — **new file**

**Design:**
```
┌─────────────────────────────────────────────┐
│  🎯  Is your goal still right for you?      │
│                                             │
│  It's been 90+ days since your last update. │
│                                             │
│  [ Still right ]    [ Remind later ]        │
└─────────────────────────────────────────────┘
```

- Rendered as a `Card` with the module's accent color tint.
- Placed at the top of the module's main screen (Water home, Medicine home).
- Dismissible — tapping either button hides it and updates the marker.

**Tests:** Widget test — renders when due, buttons call correct callbacks.

---

### T6: Wire into Water module screen

**Files:**
- `lib/features/water/presentation/screens/water_home_screen.dart` — add `RecalibrationCard` at top of screen
- `lib/features/water/presentation/providers/water_controller.dart` — add `recalibrationServiceProvider` provider
- `lib/features/water/domain/usecases/resolve_goal_for_date.dart` — after goal edit, call `recalibrationService.onGoalEdited('water')`

**Integration:**
- In `WaterHomeScreen.build()`, watch `recalibrationService.isDue('water')`.
- If due, show `RecalibrationCard` above existing content.
- On "Still right": `recalibrationService.onConfirmed('water')`.
- On "Remind later": `recalibrationService.onDeferred('water')`.

**Tests:** Integration test — prompt appears after 90 days, disappears on confirm.

---

### T7: Wire into Medicine module screen

**Files:**
- `lib/features/medicine/presentation/screens/medicine_home_screen.dart` — add `RecalibrationCard` at top
- `lib/features/medicine/presentation/controllers/medicine_controller.dart` — add recalibration service
- `lib/features/medicine/domain/usecases/expand_repeat_rule.dart` — after schedule edit, call `onGoalEdited('medicine')`

**Tests:** Same pattern as T6.

---

### T8: Goal-edit timestamp tracking

**Files:**
- `lib/features/water/domain/entities/water_goal.dart` — add `DateTime? lastEditedAt` to Freezed class (or use `updatedAt` from the table)
- `lib/features/water/data/repositories/water_repository_impl.dart` — after any goal update, call `recalibrationService.onGoalEdited('water')`
- `lib/features/medicine/data/repositories/medicine_repository_impl.dart` — after any schedule update, call `recalibrationService.onGoalEdited('medicine')`

**Strategy:** Use the existing `updatedAt` column on the goal/schedule tables rather than adding a new field. The recalibration marker's `lastGoalEditedAt` is the source of truth; the goal entity's timestamp is just for display.

---

### T9: Settings toggle

**Files:**
- `lib/features/settings/domain/entities/app_settings.dart` — add `@Default(true) bool recalibrationPromptsEnabled`
- `lib/features/settings/domain/repositories/settings_repository.dart` — add `updateRecalibrationPromptsEnabled`
- `lib/features/settings/data/repositories/settings_repository_impl.dart` — implement
- `lib/features/settings/presentation/screens/settings_home_screen.dart` — add toggle tile

**Tests:** Settings toggle test.

---

### T10: Session-level prompt cap

**Files:**
- `lib/core/recalibration/presentation/recalibration_session_tracker.dart` — **new file**, in-memory counter

```dart
/// Tracks how many recalibration prompts have been shown this app session.
/// Resets on app restart.
class RecalibrationSessionTracker {
  int _shownCount = 0;

  bool get canShowMore => _shownCount < maxPromptsPerSession;
  void recordShown() => _shownCount++;
}
```

**Wire:** In `RecalibrationService.isDue()`, also check `sessionTracker.canShowMore`.

---

### T11: Localization

**Files:**
- `lib/core/l10n/app_en.arb` — ~12 new keys
- `lib/core/l10n/app_bn.arb` — Bangla translations

**Keys:**
- `recalibrationTitle` — "Is your goal still right?"
- `recalibrationBody` — "It's been a while since you updated your goal."
- `recalibrationConfirm` — "Still right"
- `recalibrationDefer` — "Remind later"
- `recalibrationSettingsLabel` — "Goal recalibration prompts"
- `recalibrationSettingsDescription` — "Periodically check if your goals still fit"

---

## Task sequencing

```
T1 (schema) ──→ T2 (repository) ──→ T3 (trigger) ──→ T4 (service)
                                                       │
T8 (goal-edit tracking) ───────────────────────────────┘
                                                       │
T5 (card widget) ──→ T6 (water) ──→ T7 (medicine) ──→ T11 (i18n)
                                   T9 (settings)
                                   T10 (session cap)
```

---

## Commit plan

| Commit | Tasks | Message |
|--------|-------|---------|
| 1 | T1 | `feat(db): add recalibration_markers table (migration 14)` |
| 2 | T2 | `feat(recalibration): add RecalibrationRepository` |
| 3 | T3 | `feat(recalibration): add recalibration trigger logic (pure)` |
| 4 | T4 | `feat(recalibration): add RecalibrationService orchestration` |
| 5 | T5 | `feat(recalibration): add RecalibrationCard widget` |
| 6 | T6 | `feat(water): wire recalibration prompt into water home screen` |
| 7 | T7 | `feat(medicine): wire recalibration prompt into medicine home screen` |
| 8 | T8 | `feat: track goal-edit timestamps for recalibration anchoring` |
| 9 | T9 | `feat(settings): add recalibration prompts toggle` |
| 10 | T10 | `feat(recalibration): add session-level prompt cap` |
| 11 | T11 | `feat(i18n): add en/bn strings for recalibration prompts` |

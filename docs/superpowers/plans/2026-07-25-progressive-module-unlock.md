# Progressive Module Unlock in Onboarding — Implementation Plan

**Spec:** `docs/superpowers/specs/09-retention/07-progressive-module-unlock-onboarding-design.md`
**Date:** 2026-07-25
**Status:** Ready for implementation

---

## Architecture overview

```
┌──────────────────────────────────────────────────────────┐
│  /onboarding route                                       │
│  Step 1: Welcome + Water setup (enabled by default)      │
│  Step 2: "Also available" — Medicine, Prayer (opt-in)    │
│  Step 3: Complete → enable selected modules              │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  core/modules/module_settings.dart                       │
│  module_settings table (new)                             │
│  tracks enabled/disabled per module per user             │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  module_registry.dart                                    │
│  reads module_settings to filter enabled modules         │
│  habitModulesProvider respects enabled filter            │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  Dashboard: "You might also like" suggestion card        │
│  appears after trigger (3 entries or 3 days)             │
│  per-module dismiss tracking                             │
└──────────────────────────────────────────────────────────┘
```

---

## Resolved dependencies

| Dep | Status |
|-----|--------|
| `installDate` on `AppSettings` | Spec 01 T1-T2 |
| Schema migration v10 | Spec 01 T1 |

**Note:** This spec requires new infrastructure (module enable/disable, onboarding flow) that doesn't exist yet. This is the most self-contained new-system spec in the retention category.

---

## Implementation tasks

### T1: Schema migration — `module_settings` + `onboarding_progress` tables

**Files:**
- `lib/core/database/tables/module_settings_table.dart` — **new file**
- `lib/core/database/tables/onboarding_progress_table.dart` — **new file**
- `lib/core/database/app_database.dart` — add both tables, bump `schemaVersion` to 16

**`module_settings` table:**
```dart
@DataClassName('ModuleSettingsRow')
class ModuleSettingsTable extends Table {
  @override
  String get tableName => 'module_settings';

  TextColumn get moduleId => text()();     // 'water', 'medicine', 'prayer'
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {moduleId};
}
```

**`onboarding_progress` table:**
```dart
@DataClassName('OnboardingProgressRow')
class OnboardingProgressTable extends Table {
  @override
  String get tableName => 'onboarding_progress';

  TextColumn get id => text()();           // 'singleton'
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get completedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Migration (from < 16):**
```dart
if (from < 16) {
  await m.createTable(moduleSettingsTable);
  await m.createTable(onboardingProgressTable);
  // Seed Water as enabled by default (backward-compatible for existing users)
  await into(moduleSettingsTable).insert(
    ModuleSettingsTableCompanion.insert(
      moduleId: 'water',
      enabled: const Constant(true),
      createdAt: now,
      updatedAt: now,
    ),
  );
  // Mark onboarding as completed for existing users
  await into(onboardingProgressTable).insert(
    OnboardingProgressTableCompanion.insert(
      id: 'singleton',
      completed: const Constant(true),
      completedAt: Value(now),
    ),
  );
}
```

**Tests:** Migration test — verify Water seeded as enabled, Medicine/Prayer disabled, onboarding marked complete for existing users.

---

### T2: `ModuleSettingsRepository` — enable/disable

**Files:**
- `lib/core/modules/module_settings_repository.dart` — **new file**

```dart
class ModuleSettingsRepository {
  const ModuleSettingsRepository(this._db);
  final AppDatabase _db;

  /// Whether [moduleId] is enabled.
  Future<bool> isEnabled(String moduleId);

  /// Stream of enabled state for [moduleId].
  Stream<bool> watchEnabled(String moduleId);

  /// Enables or disables [moduleId]. Triggers notification re-plan.
  Future<void> setEnabled(String moduleId, {required bool enabled});

  /// All enabled module ids.
  Future<Set<String>> enabledModuleIds();
}
```

**Tests:** `test/core/modules/module_settings_repository_test.dart`

---

### T3: Wire module enable/disable into `module_registry.dart`

**Files:**
- `lib/core/modules/module_registry.dart` — modify `buildHabitModules` to accept enabled module filter
- `lib/core/database/database_provider.dart` — no changes (providers read from registry)

**Approach:** `buildHabitModules(AppDatabase db)` now also takes `Set<String> enabledModules`. If the set is empty (legacy path / background isolate), return all modules (backward-compatible). If populated, filter to only enabled modules.

**Tests:** Verify filtering works, backward-compatible when no settings exist.

---

### T4: Onboarding flow — screens + routing

**Files:**
- `lib/core/router/app_router.dart` — add `/onboarding` route
- `lib/features/onboarding/presentation/screens/onboarding_welcome_screen.dart` — **new file**
- `lib/features/onboarding/presentation/screens/onboarding_module_selection_screen.dart` — **new file**
- `lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart` — **new file**

**Flow:**
1. **Welcome screen:** App logo, "Welcome to Habit Tracker", brief description. "Get Started" button.
2. **Module selection screen:** Water shown as recommended (pre-selected, toggleable). Medicine and Prayer shown as "Also available" with opt-in toggles. "I know what I want" escape hatch to skip to complete. "Continue" button.
3. **Complete screen:** "You're all set! Water is ready." Shows next step (first water log prompt). "Start" button → navigates to `/water`.

**Route guard:** If onboarding is not completed, all routes redirect to `/onboarding`.

**Tests:** Widget tests for each screen, route guard test.

---

### T5: Onboarding state management

**Files:**
- `lib/features/onboarding/presentation/providers/onboarding_providers.dart` — **new file**
- `lib/features/onboarding/data/onboarding_repository.dart` — **new file** (wraps `OnboardingProgressTable`)

```dart
@riverpod
Future<bool> onboardingCompleted(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final row = await (db.select(db.onboardingProgressTable)
    ..where((t) => t.id.equals('singleton'))).getSingleOrNull();
  return row?.completed ?? false;
}
```

**Tests:** Provider tests.

---

### T6: Dashboard suggestion card — "You might also like"

**Files:**
- `lib/features/dashboard/presentation/widgets/module_suggestion_card.dart` — **new file**
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` — add suggestion card at top

**Card design:**
```
┌─────────────────────────────────────────────┐
│  💡 You might also like                     │
│                                             │
│  Track your medicine schedules with         │
│  Medicine — never miss a dose.              │
│                                             │
│  [ Enable Medicine ]    [ Not now ]         │
└─────────────────────────────────────────────┘
```

**Trigger logic:**
1. If all modules are already enabled, don't show.
2. If user has already dismissed a module suggestion, don't re-show.
3. If user has logged >= 3 water entries OR >= 3 days have passed since onboarding, show for the first non-dismissed, non-enabled module.

**Dismiss tracking:** New column `suggestionDismissedModuleIds` on `module_settings` or a separate `onboarding_suggestions` table. Simple approach: add a `suggestionDismissed` bool column to `module_settings`.

**Add to `module_settings_table`:**
```dart
BoolColumn get suggestionDismissed => boolean().withDefault(const Constant(false))();
```

**Tests:** Widget test — card shows after trigger, dismiss works, no re-show.

---

### T7: Notification re-plan on module toggle

**Files:**
- `lib/core/modules/module_settings_repository.dart` — in `setEnabled`, call `planAndApplyNotifications(db)` after toggle

**Tests:** Verify notifications are cancelled when module disabled, re-planned when enabled.

---

### T8: Settings — module enable/disable

**Files:**
- `lib/features/settings/presentation/screens/settings_home_screen.dart` — add "Modules" section with toggles for each module
- Water cannot be disabled (always on, recommended starting point)

**Tests:** Settings toggle test.

---

### T9: Localization

**Files:**
- `lib/core/l10n/app_en.arb` — ~20 new keys
- `lib/core/l10n/app_bn.arb` — Bangla translations

**Keys:**
- `onboardingWelcomeTitle` — "Welcome to Habit Tracker"
- `onboardingWelcomeBody` — "Build lasting habits, one day at a time."
- `onboardingGetStarted` — "Get Started"
- `onboardingModuleTitle` — "Choose your modules"
- `onboardingModuleRecommended` — "Recommended"
- `onboardingModuleAlsoAvailable` — "Also available"
- `onboardingModuleSkip` — "I know what I want"
- `onboardingCompleteTitle` — "You're all set!"
- `onboardingCompleteBody` — "{module} is ready. Let's start building habits."
- `moduleSuggestionTitle` — "You might also like"
- `moduleSuggestionEnable` — "Enable {module}"
- `moduleSuggestionDismiss` — "Not now"
- `settingsModulesTitle` — "Modules"

---

## Task sequencing

```
T1 (schema) ──→ T2 (repository) ──→ T3 (registry filter)
                                    ──→ T7 (notification re-plan)
T2 ──→ T5 (onboarding state) ──→ T4 (onboarding screens)
T2 ──→ T6 (suggestion card)
T3 ──→ T8 (settings toggles)
T4 + T6 + T8 ──→ T9 (i18n)
```

---

## Commit plan

| Commit | Tasks | Message |
|--------|-------|---------|
| 1 | T1 | `feat(db): add module_settings and onboarding_progress tables (migration 16)` |
| 2 | T2 | `feat(modules): add ModuleSettingsRepository for enable/disable` |
| 3 | T3 | `feat(modules): wire module enable/disable into module_registry` |
| 4 | T4 | `feat(onboarding): add progressive module unlock onboarding flow` |
| 5 | T5 | `feat(onboarding): add onboarding state providers` |
| 6 | T6 | `feat(dashboard): add "You might also like" module suggestion card` |
| 7 | T7 | `feat(modules): re-plan notifications on module enable/disable` |
| 8 | T8 | `feat(settings): add module enable/disable toggles` |
| 9 | T9 | `feat(i18n): add en/bn strings for onboarding and module suggestions` |

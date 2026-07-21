# PIN Lock: Fix Biometric/Screen-Privacy Toggles + Test Coverage — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `PinSettingsScreen`'s biometric and screen-privacy toggles
real (persisted, actually gate behavior) instead of hardcoded/no-op stubs,
and add test coverage for the `/lock` redirect gate and these toggles —
per `docs/superpowers/specs/2026-07-21-pin-lock-toggles-fix-design.md`.

**Architecture:** Two new `AppSettings` boolean fields
(`biometricEnabled`, `screenPrivacyEnabled`), backed by two new
`app_settings` DB columns (schema v3), flow through the same
repository/provider pattern `pinEnabled` already uses. `LockScreen` reads
`biometricEnabled` before attempting biometric auth. Screen-privacy
application moves to a single `ref.listen` in `main.dart` (cold start +
every settings change) instead of being called directly from the
Settings toggle. `PinLockController.disablePin()` resets both to their
defaults.

**Tech Stack:** Flutter/Dart, Riverpod (codegen), Drift (codegen),
`flutter_test`.

## Global Constraints

- New DB columns: `biometric_enabled` (bool, default `true`),
  `screen_privacy_enabled` (bool, default `false`) on `app_settings`.
- `schemaVersion` → `3`, migrated via `m.addColumn` (existing seam at
  `app_database.dart:70-72`).
- `ScreenPrivacyService` is applied from exactly one call site
  (`main.dart`'s `ref.listen`), never from `PinSettingsScreen` directly.
- `PinLockController.disablePin()` resets `biometricEnabled` → `true`,
  `screenPrivacyEnabled` → `false`.
- Import of an older backup (missing the two new JSON keys) must not
  crash — fallback to `true`/`false` respectively.
- After every task: `dart run build_runner build --delete-conflicting-outputs`
  regenerates `*.freezed.dart`/`*.g.dart`; run it whenever `AppSettings`,
  `AppSettingsTable`, or a `@riverpod` provider changes.

---

### Task 1: Data layer — schema, entity, repository, backup round-trip

**Files:**
- Modify: `lib/core/database/tables/app_settings_table.dart`
- Modify: `lib/core/database/app_database.dart:54,57-74`
- Modify: `lib/features/settings/domain/entities/app_settings.dart:44-52`
- Modify: `lib/features/settings/domain/repositories/settings_repository.dart`
- Modify: `lib/features/settings/data/repositories/settings_repository_impl.dart:70-76,117-129`
- Modify: `lib/core/backup/export_orchestrator.dart:39-45`
- Modify: `lib/core/backup/import_orchestrator.dart:161-175`
- Test: `test/features/settings/data/repositories/settings_repository_impl_test.dart`

**Interfaces:**
- Produces: `AppSettings.biometricEnabled` (`bool`),
  `AppSettings.screenPrivacyEnabled` (`bool`) — consumed by Task 2's UI
  and `main.dart` wiring.
- Produces: `SettingsRepository.updateBiometricEnabled({required bool enabled})`,
  `SettingsRepository.updateScreenPrivacyEnabled({required bool enabled})`
  — consumed by Task 2.

- [ ] **Step 1: Write the failing repository test**

Add to `test/features/settings/data/repositories/settings_repository_impl_test.dart`,
inside the existing `test(...)` block, right after the existing
`expect(firstRead.themeMode, AppThemeMode.system);` line:

```dart
    expect(firstRead.biometricEnabled, isTrue);
    expect(firstRead.screenPrivacyEnabled, isFalse);
```

And right after the existing
`final updateResult = await repo1.updateThemeMode(AppThemeMode.dark);`
block (before `await db1.close();`), add:

```dart
    final biometricResult = await repo1.updateBiometricEnabled(
      enabled: false,
    );
    expect(biometricResult, isA<Success<void>>());
    final privacyResult = await repo1.updateScreenPrivacyEnabled(
      enabled: true,
    );
    expect(privacyResult, isA<Success<void>>());
```

And right after the existing `expect(afterRestart.themeMode, AppThemeMode.dark);`,
add:

```dart
    expect(afterRestart.biometricEnabled, isFalse);
    expect(afterRestart.screenPrivacyEnabled, isTrue);
```

- [ ] **Step 2: Run it, confirm it fails to compile**

Run: `flutter test test/features/settings/data/repositories/settings_repository_impl_test.dart`
Expected: compile error — `biometricEnabled`/`screenPrivacyEnabled`/
`updateBiometricEnabled`/`updateScreenPrivacyEnabled` don't exist yet.

- [ ] **Step 3: Add the DB columns**

In `lib/core/database/tables/app_settings_table.dart`, add after the
`pinLockTimeoutSeconds` column (before `onboardingCompletedAt`):

```dart
  /// Whether biometric unlock is offered on `/lock`, when the device
  /// supports it (D-15/`strategies/security.md`) — default `true`
  /// because that's the pre-existing always-on behavior this column
  /// makes visible and opt-out-able, not a new default.
  BoolColumn get biometricEnabled =>
      boolean().withDefault(const Constant(true))();

  /// `FLAG_SECURE` (Android) / app-switcher blur (iOS) toggle
  /// (`strategies/security.md`) — default `false`, opt-in.
  BoolColumn get screenPrivacyEnabled =>
      boolean().withDefault(const Constant(false))();
```

- [ ] **Step 4: Bump schema version and add the migration**

In `lib/core/database/app_database.dart`, change:

```dart
  @override
  int get schemaVersion => 2;
```

to:

```dart
  @override
  int get schemaVersion => 3;
```

And change the `migration` getter's `onUpgrade` body from:

```dart
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Medicine + Prayer tables added after the initial release.
        await m.createTable(medicinesTable);
        await m.createTable(medicineSchedulesTable);
        await m.createTable(medicineDosesTable);
        await m.createTable(medicineStockEventsTable);
        await m.createTable(prayerSettingsTable);
        await m.createTable(prayerRecordsTable);
        await m.createTable(prayerQadhaCountersTable);
      }
      // Seam: when schemaVersion increments further, add
      // `if (from < N) ...` blocks here — no other file needs to
      // change for a schema migration.
    },
```

to:

```dart
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Medicine + Prayer tables added after the initial release.
        await m.createTable(medicinesTable);
        await m.createTable(medicineSchedulesTable);
        await m.createTable(medicineDosesTable);
        await m.createTable(medicineStockEventsTable);
        await m.createTable(prayerSettingsTable);
        await m.createTable(prayerRecordsTable);
        await m.createTable(prayerQadhaCountersTable);
      }
      if (from < 3) {
        // Biometric-unlock and screen-privacy toggles.
        await m.addColumn(appSettingsTable, appSettingsTable.biometricEnabled);
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.screenPrivacyEnabled,
        );
      }
      // Seam: when schemaVersion increments further, add
      // `if (from < N) ...` blocks here — no other file needs to
      // change for a schema migration.
    },
```

- [ ] **Step 5: Add the entity fields**

In `lib/features/settings/domain/entities/app_settings.dart`, change the
`AppSettings` factory from:

```dart
  const factory AppSettings({
    required AppLocale locale,
    required AppThemeMode themeMode,
    required WaterUnit waterUnit,
    required bool pinEnabled,
    required int pinLockTimeoutSeconds,
    DateTime? onboardingCompletedAt,
  }) = _AppSettings;
```

to:

```dart
  const factory AppSettings({
    required AppLocale locale,
    required AppThemeMode themeMode,
    required WaterUnit waterUnit,
    required bool pinEnabled,
    required int pinLockTimeoutSeconds,
    required bool biometricEnabled,
    required bool screenPrivacyEnabled,
    DateTime? onboardingCompletedAt,
  }) = _AppSettings;
```

- [ ] **Step 6: Add the repository interface methods**

In `lib/features/settings/domain/repositories/settings_repository.dart`,
add after `updatePinLockTimeoutSeconds`:

```dart
  /// Enables or disables offering biometric unlock on `/lock`.
  Future<Result<void>> updateBiometricEnabled({required bool enabled});

  /// Enables or disables screen-privacy protection (`FLAG_SECURE`/
  /// app-switcher blur).
  Future<Result<void>> updateScreenPrivacyEnabled({required bool enabled});
```

- [ ] **Step 7: Implement them and wire `_toDomain`**

In `lib/features/settings/data/repositories/settings_repository_impl.dart`,
add after `updatePinLockTimeoutSeconds`'s implementation:

```dart
  @override
  Future<Result<void>> updateBiometricEnabled({required bool enabled}) =>
      _update(AppSettingsTableCompanion(biometricEnabled: Value(enabled)));

  @override
  Future<Result<void>> updateScreenPrivacyEnabled({required bool enabled}) =>
      _update(
        AppSettingsTableCompanion(screenPrivacyEnabled: Value(enabled)),
      );
```

Change `_toDomain` from:

```dart
  AppSettings _toDomain(AppSettingsRow row) => AppSettings(
    locale: AppLocaleDb.fromDb(row.locale),
    themeMode: AppThemeModeDb.fromDb(row.themeMode),
    waterUnit: WaterUnitDb.fromDb(row.waterUnit),
    pinEnabled: row.pinEnabled,
    pinLockTimeoutSeconds: row.pinLockTimeoutSeconds,
    onboardingCompletedAt: row.onboardingCompletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.onboardingCompletedAt!,
            isUtc: true,
          ),
  );
```

to:

```dart
  AppSettings _toDomain(AppSettingsRow row) => AppSettings(
    locale: AppLocaleDb.fromDb(row.locale),
    themeMode: AppThemeModeDb.fromDb(row.themeMode),
    waterUnit: WaterUnitDb.fromDb(row.waterUnit),
    pinEnabled: row.pinEnabled,
    pinLockTimeoutSeconds: row.pinLockTimeoutSeconds,
    biometricEnabled: row.biometricEnabled,
    screenPrivacyEnabled: row.screenPrivacyEnabled,
    onboardingCompletedAt: row.onboardingCompletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.onboardingCompletedAt!,
            isUtc: true,
          ),
  );
```

Also update `restoreSettings`'s written companion (find the
`AppSettingsTableCompanion(` inside `restoreSettings`) from:

```dart
        AppSettingsTableCompanion(
          locale: Value(settings.locale.toDb()),
          themeMode: Value(settings.themeMode.toDb()),
          waterUnit: Value(settings.waterUnit.toDb()),
          pinEnabled: Value(settings.pinEnabled),
          pinLockTimeoutSeconds: Value(settings.pinLockTimeoutSeconds),
          updatedAt: Value(now),
        ),
```

to:

```dart
        AppSettingsTableCompanion(
          locale: Value(settings.locale.toDb()),
          themeMode: Value(settings.themeMode.toDb()),
          waterUnit: Value(settings.waterUnit.toDb()),
          pinEnabled: Value(settings.pinEnabled),
          pinLockTimeoutSeconds: Value(settings.pinLockTimeoutSeconds),
          biometricEnabled: Value(settings.biometricEnabled),
          screenPrivacyEnabled: Value(settings.screenPrivacyEnabled),
          updatedAt: Value(now),
        ),
```

- [ ] **Step 8: Wire backup export/import**

In `lib/core/backup/export_orchestrator.dart`, change `_appSettingsToJson`
from:

```dart
Map<String, Object?> _appSettingsToJson(AppSettings settings) => {
  'locale': settings.locale.name,
  'themeMode': settings.themeMode.name,
  'waterUnit': settings.waterUnit.name,
  'pinEnabled': settings.pinEnabled,
  'pinLockTimeoutSeconds': settings.pinLockTimeoutSeconds,
};
```

to:

```dart
Map<String, Object?> _appSettingsToJson(AppSettings settings) => {
  'locale': settings.locale.name,
  'themeMode': settings.themeMode.name,
  'waterUnit': settings.waterUnit.name,
  'pinEnabled': settings.pinEnabled,
  'pinLockTimeoutSeconds': settings.pinLockTimeoutSeconds,
  'biometricEnabled': settings.biometricEnabled,
  'screenPrivacyEnabled': settings.screenPrivacyEnabled,
};
```

In `lib/core/backup/import_orchestrator.dart`, change the `AppSettings(`
construction from:

```dart
          AppSettings(
            locale: AppLocale.values.byName(
              appSettingsJson['locale'] as String,
            ),
            themeMode: AppThemeMode.values.byName(
              appSettingsJson['themeMode'] as String,
            ),
            waterUnit: WaterUnit.values.byName(
              appSettingsJson['waterUnit'] as String,
            ),
            pinEnabled: appSettingsJson['pinEnabled'] as bool,
            pinLockTimeoutSeconds:
                appSettingsJson['pinLockTimeoutSeconds'] as int,
          ),
```

to:

```dart
          AppSettings(
            locale: AppLocale.values.byName(
              appSettingsJson['locale'] as String,
            ),
            themeMode: AppThemeMode.values.byName(
              appSettingsJson['themeMode'] as String,
            ),
            waterUnit: WaterUnit.values.byName(
              appSettingsJson['waterUnit'] as String,
            ),
            pinEnabled: appSettingsJson['pinEnabled'] as bool,
            pinLockTimeoutSeconds:
                appSettingsJson['pinLockTimeoutSeconds'] as int,
            // `?? true`/`?? false` fallback: an older export made before
            // these two fields existed must still import cleanly, at the
            // same defaults a fresh install gets.
            biometricEnabled:
                appSettingsJson['biometricEnabled'] as bool? ?? true,
            screenPrivacyEnabled:
                appSettingsJson['screenPrivacyEnabled'] as bool? ?? false,
          ),
```

- [ ] **Step 9: Regenerate code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0, regenerates `app_settings.freezed.dart` and
`app_database.g.dart` (both gitignored, not committed) with the new
fields/columns.

- [ ] **Step 10: Run the test, confirm it passes**

Run: `flutter test test/features/settings/data/repositories/settings_repository_impl_test.dart`
Expected: `+1: All tests passed!`

- [ ] **Step 11: Full analyze + test sweep**

Run: `flutter analyze`
Expected: `No issues found!` — this will also catch any other call site
that constructs `AppSettings(...)` without the two new required fields
(there should be none besides `import_orchestrator.dart`, already fixed
above).

Run: `flutter test`
Expected: same 2 pre-existing failures as before this task (unrelated,
documented in `docs/superpowers/plans/2026-07-21-app-icon-splash.md`),
no new failures.

- [ ] **Step 12: Commit**

```bash
git add lib/core/database/tables/app_settings_table.dart \
  lib/core/database/app_database.dart \
  lib/features/settings/domain/entities/app_settings.dart \
  lib/features/settings/domain/repositories/settings_repository.dart \
  lib/features/settings/data/repositories/settings_repository_impl.dart \
  lib/core/backup/export_orchestrator.dart \
  lib/core/backup/import_orchestrator.dart \
  test/features/settings/data/repositories/settings_repository_impl_test.dart
git commit -m "feat(settings): add biometricEnabled/screenPrivacyEnabled fields"
```

---

### Task 2: Wire the toggles to real behavior

**Files:**
- Modify: `lib/features/settings/presentation/screens/pin_settings_screen.dart:78-100`
- Modify: `lib/core/security/lock_screen.dart:47-56`
- Modify: `lib/core/security/pin_lock_controller.dart:127-133`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `AppSettings.biometricEnabled`/`screenPrivacyEnabled`,
  `SettingsRepository.updateBiometricEnabled`/
  `updateScreenPrivacyEnabled` from Task 1.
- Produces: `LockScreen` now honors `biometricEnabled`; `main.dart`
  applies `ScreenPrivacyService` reactively — consumed by Task 3's tests.

- [ ] **Step 1: Fix the biometric toggle**

In `lib/features/settings/presentation/screens/pin_settings_screen.dart`,
change the class declaration and constructor from:

```dart
class PinSettingsScreen extends ConsumerWidget {
  /// Creates the PIN settings screen.
  const PinSettingsScreen({super.key});

  static const _timeoutOptions = [0, 60, 300, 1800];
```

to:

```dart
class PinSettingsScreen extends ConsumerWidget {
  /// Creates the PIN settings screen. [biometricAvailable] overrides the
  /// real `BiometricService().isAvailable` check — test-only seam, since
  /// `local_auth`'s platform channel isn't available under `flutter test`.
  const PinSettingsScreen({super.key, this.biometricAvailable});

  /// Test seam for [BiometricService.isAvailable].
  final Future<bool> Function()? biometricAvailable;

  static const _timeoutOptions = [0, 60, 300, 1800];
```

Then change the biometric `FutureBuilder` block from:

```dart
            FutureBuilder<bool>(
              future: BiometricService().isAvailable(),
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return SwitchListTile(
                  title: Text(l10n.pinSettingsBiometric),
                  value: false,
                  onChanged: (_) {},
                );
              },
            ),
            SwitchListTile(
              title: Text(l10n.pinSettingsScreenPrivacy),
              value: false,
              onChanged: (enable) async {
                final service = ScreenPrivacyService();
                if (enable) {
                  await service.enable();
                } else {
                  await service.disable();
                }
              },
            ),
```

to:

```dart
            FutureBuilder<bool>(
              future: (biometricAvailable ?? BiometricService().isAvailable)(),
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return SwitchListTile(
                  title: Text(l10n.pinSettingsBiometric),
                  value: settings?.biometricEnabled ?? true,
                  onChanged: (enable) async {
                    await ref
                        .read(settingsRepositoryProvider)
                        .updateBiometricEnabled(enabled: enable);
                  },
                );
              },
            ),
            SwitchListTile(
              title: Text(l10n.pinSettingsScreenPrivacy),
              value: settings?.screenPrivacyEnabled ?? false,
              onChanged: (enable) async {
                await ref
                    .read(settingsRepositoryProvider)
                    .updateScreenPrivacyEnabled(enabled: enable);
              },
            ),
```

Remove the now-unused `ScreenPrivacyService` import (the toggle no longer
calls it directly — `main.dart` does):

```dart
import 'package:habit_tracker/core/security/screen_privacy_service.dart';
```

- [ ] **Step 2: Gate biometric attempts in `LockScreen`**

In `lib/core/security/lock_screen.dart`, add the settings import:

```dart
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
```

Change `_tryBiometric` from:

```dart
  Future<void> _tryBiometric() async {
    final biometric = BiometricService();
    if (!await biometric.isAvailable()) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final ok = await biometric.authenticate(
      localizedReason: l10n.lockScreenTitle,
    );
    if (ok) await _unlock();
  }
```

to:

```dart
  Future<void> _tryBiometric() async {
    final biometricEnabled =
        ref.read(appSettingsProvider).valueOrNull?.biometricEnabled ?? true;
    if (!biometricEnabled) return;
    final biometric = BiometricService();
    if (!await biometric.isAvailable()) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final ok = await biometric.authenticate(
      localizedReason: l10n.lockScreenTitle,
    );
    if (ok) await _unlock();
  }
```

- [ ] **Step 3: Reset both prefs on `disablePin`**

In `lib/core/security/pin_lock_controller.dart`, change `disablePin` from:

```dart
  /// Disables PIN lock, requiring the current PIN first.
  Future<bool> disablePin(String pin) async {
    if (!await verify(pin)) return false;
    await _service.clearAll();
    await _settingsRepository.updatePinEnabled(enabled: false);
    return true;
  }
```

to:

```dart
  /// Disables PIN lock, requiring the current PIN first. Also resets the
  /// biometric/screen-privacy toggles to their own defaults — both are
  /// only ever shown while PIN is enabled, so re-enabling PIN later
  /// should start from a clean slate rather than silently re-arming a
  /// stale preference (`strategies/security.md`).
  Future<bool> disablePin(String pin) async {
    if (!await verify(pin)) return false;
    await _service.clearAll();
    await _settingsRepository.updatePinEnabled(enabled: false);
    await _settingsRepository.updateBiometricEnabled(enabled: true);
    await _settingsRepository.updateScreenPrivacyEnabled(enabled: false);
    return true;
  }
```

- [ ] **Step 4: Apply screen-privacy reactively from `main.dart`**

In `lib/main.dart`, add imports:

```dart
import 'package:habit_tracker/core/security/screen_privacy_service.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
```

In `_HabitTrackerAppState.build`, change:

```dart
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final isBangla = locale.languageCode == 'bn';
    return MaterialApp.router(
```

to:

```dart
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final isBangla = locale.languageCode == 'bn';
    // Single call site for applying screen privacy (`strategies/
    // security.md`): fires once on cold start with whatever was
    // persisted, and again on every Settings toggle — never called
    // directly from `PinSettingsScreen`.
    ref.listen<AsyncValue<AppSettings>>(appSettingsProvider, (
      previous,
      next,
    ) {
      final enabled = next.valueOrNull?.screenPrivacyEnabled;
      if (enabled == null) return;
      if (previous?.valueOrNull?.screenPrivacyEnabled == enabled) return;
      unawaited(
        enabled
            ? ScreenPrivacyService().enable()
            : ScreenPrivacyService().disable(),
      );
    });
    return MaterialApp.router(
```

- [ ] **Step 5: Analyze and run the existing suite**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: same 2 pre-existing failures as before, no new ones — Task 3
adds the tests that actually exercise this new behavior.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/screens/pin_settings_screen.dart \
  lib/core/security/lock_screen.dart \
  lib/core/security/pin_lock_controller.dart \
  lib/main.dart
git commit -m "fix(security): wire biometric/screen-privacy toggles to real state"
```

---

### Task 3: Test coverage for the lock flow and the fixed toggles

**Files:**
- Create: `test/support/test_secure_storage.dart`
- Modify: `test/core/security/pin_lock_controller_test.dart` (use the
  shared fixture instead of its own private copy)
- Modify: `test/core/router/app_router_test.dart` (new test)
- Create: `test/features/settings/presentation/screens/pin_settings_screen_test.dart`

**Interfaces:**
- Consumes: `PinLockController`, `PinLockService`, `SettingsRepositoryImpl`,
  `PinSettingsScreen(biometricAvailable: ...)` from Tasks 1-2.

- [ ] **Step 1: Promote the shared `InMemorySecureStorage` fixture**

Create `test/support/test_secure_storage.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A trivial in-memory [FlutterSecureStorage] fake — avoids the real
/// platform channel entirely, shared by every test that needs a real
/// [PinLockService]/[PinLockController] (not the shallow
/// `FakePinLockService`, which stubs `PinLockService` itself out
/// entirely and can't exercise real hash/backoff logic).
class InMemorySecureStorage implements FlutterSecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

In `test/core/security/pin_lock_controller_test.dart`, remove the
private `_InMemoryStorage` class (the whole
`class _InMemoryStorage implements FlutterSecureStorage { ... }` block
at the bottom of the file) and its now-unused
`import 'package:flutter_secure_storage/flutter_secure_storage.dart';`
line, replacing every `_InMemoryStorage()` call with
`InMemorySecureStorage()`, and add:

```dart
import '../../support/test_secure_storage.dart';
```

Run: `flutter test test/core/security/pin_lock_controller_test.dart`
Expected: `+11: All tests passed!` (unchanged behavior, just relocated).

- [ ] **Step 2: Write the failing router/lock-flow test**

Add to `test/core/router/app_router_test.dart`, new top-level imports:

```dart
import 'package:clock/clock.dart';
import 'package:habit_tracker/core/security/pin_lock_service.dart';
```

and:

```dart
import '../../support/test_secure_storage.dart';
```

Then add a second `testWidgets` after the existing one:

```dart
  testWidgets(
    'a locked app redirects to /lock; wrong PIN shows an error and stays '
    'locked; the correct PIN unlocks back to the dashboard',
    (tester) async {
      final db = testDatabase();
      addTearDown(db.close);
      final settingsRepo = SettingsRepositoryImpl(db);
      final service = PinLockService(storage: InMemorySecureStorage());
      final controller = PinLockController(service, settingsRepo);

      // Everything below runs under one fixed clock — real wall-clock
      // gaps aren't this codebase's convention for these tests (see
      // `pin_lock_controller_test.dart`), and `isCurrentlyLocked`'s
      // `clock.now()` needs to land reliably after `backgroundedAt`.
      final unlockedAt = DateTime.utc(2026, 7, 21, 10);
      final backgroundedAt = unlockedAt.add(const Duration(minutes: 5));
      final checkAt = backgroundedAt.add(const Duration(minutes: 5));

      await withClock(Clock.fixed(unlockedAt), () async {
        // setPin() records an unlock; writing a later "backgrounded at"
        // puts the app owing a fresh unlock (default timeout is 0/
        // immediate, so any backgrounding after the last unlock locks
        // it).
        await controller.setPin('1234');
      });
      await service.writeLastBackgroundedAt(backgroundedAt);

      await withClock(Clock.fixed(checkAt), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              settingsRepositoryProvider.overrideWithValue(settingsRepo),
              pinLockControllerProvider.overrideWithValue(controller),
            ],
            child: Consumer(
              builder: (context, ref, _) => MaterialApp.router(
                routerConfig: ref.watch(appRouterProvider),
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Redirected to the lock screen instead of the dashboard.
        expect(find.byType(LockScreen), findsOneWidget);
        expect(find.widgetWithText(AppBar, 'Dashboard'), findsNothing);

        // Wrong PIN: shows the error, stays locked.
        for (final digit in ['9', '9', '9', '9']) {
          await tester.tap(find.text(digit));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.lockScreenWrongPin), findsOneWidget);
        expect(find.byType(LockScreen), findsOneWidget);

        // Correct PIN: unlocks back to the dashboard.
        for (final digit in ['1', '2', '3', '4']) {
          await tester.tap(find.text(digit));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.byType(LockScreen), findsNothing);
        expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      });
    },
  );
```

Add the missing `LockScreen` import at the top of the file:

```dart
import 'package:habit_tracker/core/security/lock_screen.dart';
```

- [ ] **Step 3: Run it, confirm it passes**

Run: `flutter test test/core/router/app_router_test.dart`
Expected: `+2: All tests passed!` (both the pre-existing nav test and
the new lock-flow test).

(This is a widget-level test exercising real production code end to
end — there's no "confirm it fails first" step because there's no bug
to reproduce here, unlike Task 1/2's TDD steps; the router redirect and
`LockScreen` already work correctly per the audit, this test is purely
new coverage.)

- [ ] **Step 4: Write the PinSettingsScreen toggle test**

Create `test/features/settings/presentation/screens/pin_settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/settings/presentation/screens/pin_settings_screen.dart';

import '../../../../support/test_database.dart';

void main() {
  testWidgets(
    'biometric and screen-privacy toggles persist and reflect the stored '
    'value on rebuild',
    (tester) async {
      final db = testDatabase();
      addTearDown(db.close);
      final settingsRepo = SettingsRepositoryImpl(db);
      // PIN must already be enabled for either toggle row to render.
      await settingsRepo.updatePinEnabled(enabled: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PinSettingsScreen(
              biometricAvailable: () async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Both start at their defaults: biometric on, screen-privacy off.
      final biometricTile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, l10n.pinSettingsBiometric),
      );
      expect(biometricTile.value, isTrue);
      final privacyTile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, l10n.pinSettingsScreenPrivacy),
      );
      expect(privacyTile.value, isFalse);

      // Toggling biometric off persists it.
      await tester.tap(
        find.widgetWithText(SwitchListTile, l10n.pinSettingsBiometric),
      );
      await tester.pumpAndSettle();
      expect(
        (await settingsRepo.watchSettings().first).biometricEnabled,
        isFalse,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, l10n.pinSettingsBiometric),
            )
            .value,
        isFalse,
      );

      // Toggling screen-privacy on persists it.
      await tester.tap(
        find.widgetWithText(SwitchListTile, l10n.pinSettingsScreenPrivacy),
      );
      await tester.pumpAndSettle();
      expect(
        (await settingsRepo.watchSettings().first).screenPrivacyEnabled,
        isTrue,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(
                SwitchListTile,
                l10n.pinSettingsScreenPrivacy,
              ),
            )
            .value,
        isTrue,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
```

- [ ] **Step 5: Run it, confirm it passes**

Run: `flutter test test/features/settings/presentation/screens/pin_settings_screen_test.dart`
Expected: `+1: All tests passed!`

This test would have failed against the pre-fix code (hardcoded
`value: false`/no-op `onChanged`) — it's the regression guard for the
exact bug this whole change fixes.

- [ ] **Step 6: Full suite + analyze + format**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `dart format --output=none --set-exit-if-changed .`
Expected: exits 0 (no formatting diffs). If it fails, run
`dart format .` and re-check.

Run: `flutter test`
Expected: same 2 pre-existing unrelated failures as documented in
`docs/superpowers/plans/2026-07-21-app-icon-splash.md`, all new/modified
tests passing.

- [ ] **Step 7: Commit**

```bash
git add test/support/test_secure_storage.dart \
  test/core/security/pin_lock_controller_test.dart \
  test/core/router/app_router_test.dart \
  test/features/settings/presentation/screens/pin_settings_screen_test.dart
git commit -m "test(security): cover the /lock redirect flow and the fixed toggles"
```

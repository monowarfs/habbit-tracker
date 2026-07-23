# Sound Design Pass, Optional Off by Default Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional, off-by-default in-app chime when a Medicine
dose is marked done, per `docs/superpowers/specs/02-delightful/
10-optional-sound-design-pass-design.md`.

**Architecture:** A new `soundEnabled` `BoolColumn` (default `false`) on
`AppSettingsTable`, following the exact `biometricEnabled`/
`screenPrivacyEnabled` pattern. A new `ChimePlayer` (`core/audio/`,
mirrors `notification_service.dart`'s "one file owns the plugin"
convention) wraps the new `audioplayers` dependency with a silent-mode-
respecting `AudioContext`. The chime is wired into exactly one call
site: `_markDoneAndCelebrate` in `medicine_home_screen.dart` (UI-only),
never into `MedicineController`/`MedicineRepository`/`MedicineModule`,
because `MedicineModule.onNotificationAction` (the Done/Snooze/Skip
background-isolate path) calls the repository directly and has no audio
session to play into.

**Tech Stack:** Flutter/Dart, Riverpod (codegen), Drift (codegen),
`audioplayers` (new dependency), `gen_l10n`, `flutter_test`, `mocktail`.

## Global Constraints

- **New dependency:** `audioplayers` (confirmed absent from
  `pubspec.yaml` by grep). No other new package.
- **New asset:** `assets/sounds/dose_done_chime.mp3`, registered in
  `pubspec.yaml`'s `flutter.assets`.
- **Schema migration coordination (read this before touching
  `schemaVersion`):** Read `lib/core/database/app_database.dart`'s
  current `schemaVersion` value. As of this plan being written it is
  `7`. If it is still `7` when you implement Task 1, bump it to `8` and
  add a new `if (from < 8) { ... }` block containing your one
  `addColumn` call. If it is already `8` (because
  `06-why-this-matters-micro-education-cards-design.md`'s two hint-seen
  columns, `11-personalized-dashboard-greeting-design.md`'s
  `displayName`, or `12-seasonal-theme-accents-design.md`'s
  `seasonalAccentsEnabled` landed first), add your `addColumn` call
  inside that existing `if (from < 8)` block instead of bumping to `9`.
- **`soundEnabled` is `required bool` in the `AppSettings` Freezed
  union** (it always has a DB default, unlike the two nullable
  `*HintSeenAt` fields the "why this matters" spec adds) — every
  existing `AppSettings(...)` construction must be updated to compile:
  `import_orchestrator.dart`'s `applyImport`,
  `settings_repository_impl.dart`'s `_toDomain`, and the test-only
  `_testSettings`/`_ReactiveSettingsRepo`/`_StubSettingsRepo` fixtures in
  `test/core/security/lock_screen_test.dart` and
  `test/features/settings/presentation/screens/pin_settings_screen_test.dart`.
  All are handled in Task 1.
- **Default is off** (`soundEnabled: false`) — no behavior change for
  any existing user until they opt in via the new Settings toggle.
- `ChimePlayer` is the only new file importing `package:audioplayers`,
  mirroring `notification_service.dart`'s "one file owns the plugin"
  convention.
- No change to `core/notifications/` at all — the OS notification sound
  and this in-app chime are fully independent.
- Per this repo's CLAUDE.md spec-implementation workflow: one commit per
  task, run only that task's own test file (never the full `flutter
  test` suite mid-task), pipe `build_runner`/`test`/`gen-l10n` output
  through `| tail -10`.

---

### Task 1: Data layer — schema, entity, repository, backup round-trip

**Files:**
- Modify: `lib/core/database/tables/app_settings_table.dart`
- Modify: `lib/core/database/app_database.dart:54,100-106`
- Modify: `lib/features/settings/domain/entities/app_settings.dart:45-59`
- Modify: `lib/features/settings/domain/repositories/settings_repository.dart`
- Modify: `lib/features/settings/data/repositories/settings_repository_impl.dart`
- Modify: `lib/core/backup/export_orchestrator.dart:39-50`
- Modify: `lib/core/backup/import_orchestrator.dart:162-190`
- Modify: `test/core/security/lock_screen_test.dart:17-28,127-173`
- Modify: `test/features/settings/presentation/screens/pin_settings_screen_test.dart:20-31,80-91,140-228`
- Test: `test/features/settings/data/repositories/settings_repository_impl_test.dart`

**Interfaces:**
- Produces: `AppSettings.soundEnabled` (`bool`) — consumed by Task 2's
  Settings toggle and Task 4's `medicine_home_screen.dart` wiring.
- Produces: `SettingsRepository.updateSoundEnabled({required bool
  enabled})` — consumed by Task 2.

- [ ] **Step 1: Write the failing repository test**

Add to `test/features/settings/data/repositories/settings_repository_impl_test.dart`,
inside the existing `test(...)` block, right after the existing
`expect(firstRead.screenPrivacyEnabled, isFalse);` line:

```dart
    expect(firstRead.soundEnabled, isFalse);
```

And right after the existing `expect(privacyResult, isA<Success<void>>());`
block (before `await db1.close();`), add:

```dart
    final soundResult = await repo1.updateSoundEnabled(enabled: true);
    expect(soundResult, isA<Success<void>>());
```

And right after the existing `expect(afterRestart.screenPrivacyEnabled, isTrue);`,
add:

```dart
    expect(afterRestart.soundEnabled, isTrue);
```

- [ ] **Step 2: Run it, confirm it fails to compile**

Run: `flutter test test/features/settings/data/repositories/settings_repository_impl_test.dart | tail -10`
Expected: compile error — `soundEnabled`/`updateSoundEnabled` don't
exist yet.

- [ ] **Step 3: Add the DB column**

In `lib/core/database/tables/app_settings_table.dart`, add after the
`screenPrivacyEnabled` column (before `quietHoursEnabled`):

```dart
  /// Whether the in-app dose-done completion chime is played
  /// (`docs/superpowers/specs/02-delightful/
  /// 10-optional-sound-design-pass-design.md`) — default `false`, opt-in.
  BoolColumn get soundEnabled =>
      boolean().withDefault(const Constant(false))();
```

- [ ] **Step 4: Schema version — coordinate with the other in-flight specs**

Read `lib/core/database/app_database.dart`'s current `schemaVersion`
value right now, before editing anything:

- **If it is still `7`:** change

```dart
  @override
  int get schemaVersion => 7;
```

  to

```dart
  @override
  int get schemaVersion => 8;
```

  and add a new block to the `onUpgrade` body, immediately after the
  existing `if (from < 7) { ... }` block:

```dart
      if (from < 8) {
        // Optional dose-done completion chime, off by default.
        await m.addColumn(appSettingsTable, appSettingsTable.soundEnabled);
      }
```

- **If it is already `8`** (because the "why this matters" hint-card
  spec, the personalized-greeting spec, or the seasonal-accents spec
  shipped first), do **not** bump to `9` — instead add your one
  `addColumn` call inside that already-existing `if (from < 8) { ... }`
  block, alongside whatever column(s) that other spec already added
  there.

Either way, the end state is: exactly one `if (from < 8)` block exists
in `onUpgrade`, and it contains an `addColumn` call for `soundEnabled`
plus every other field any of the other in-flight specs introduced at
schema version 8.

- [ ] **Step 5: Add the entity field**

In `lib/features/settings/domain/entities/app_settings.dart`, change the
`AppSettings` factory from:

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
    String? lastSeenAppVersion,
    required bool quietHoursEnabled,
    required LocalTime quietHoursStart,
    required LocalTime quietHoursEnd,
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
    required bool soundEnabled,
    DateTime? onboardingCompletedAt,
    String? lastSeenAppVersion,
    required bool quietHoursEnabled,
    required LocalTime quietHoursStart,
    required LocalTime quietHoursEnd,
  }) = _AppSettings;
```

(If Task 1 of the "why this matters" hint-card plan already landed,
this factory will also carry `DateTime? waterHydrationHintSeenAt` and
`DateTime? prayerQadhaHintSeenAt` at the end — leave those exactly
where they are and just add `required bool soundEnabled,` in the
position shown above.)

- [ ] **Step 6: Add the repository interface method**

In `lib/features/settings/domain/repositories/settings_repository.dart`,
add after `updateScreenPrivacyEnabled`:

```dart
  /// Enables or disables the in-app dose-done completion chime.
  Future<Result<void>> updateSoundEnabled({required bool enabled});
```

- [ ] **Step 7: Implement it and wire `_toDomain`/`restoreSettings`**

In `lib/features/settings/data/repositories/settings_repository_impl.dart`,
add after `updateScreenPrivacyEnabled`'s implementation:

```dart
  @override
  Future<Result<void>> updateSoundEnabled({required bool enabled}) =>
      _update(AppSettingsTableCompanion(soundEnabled: Value(enabled)));
```

In `_toDomain`, change:

```dart
    biometricEnabled: row.biometricEnabled,
    screenPrivacyEnabled: row.screenPrivacyEnabled,
    onboardingCompletedAt: row.onboardingCompletedAt == null
```

to:

```dart
    biometricEnabled: row.biometricEnabled,
    screenPrivacyEnabled: row.screenPrivacyEnabled,
    soundEnabled: row.soundEnabled,
    onboardingCompletedAt: row.onboardingCompletedAt == null
```

In `restoreSettings`'s `AppSettingsTableCompanion(...)` write, change:

```dart
          biometricEnabled: Value(settings.biometricEnabled),
          screenPrivacyEnabled: Value(settings.screenPrivacyEnabled),
          quietHoursEnabled: Value(settings.quietHoursEnabled),
```

to:

```dart
          biometricEnabled: Value(settings.biometricEnabled),
          screenPrivacyEnabled: Value(settings.screenPrivacyEnabled),
          soundEnabled: Value(settings.soundEnabled),
          quietHoursEnabled: Value(settings.quietHoursEnabled),
```

(Unlike the "why this matters" spec's two hint-seen flags,
`soundEnabled` **is** restored on import — it's an ordinary user
preference, same treatment as `biometricEnabled`.)

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
  'biometricEnabled': settings.biometricEnabled,
  'screenPrivacyEnabled': settings.screenPrivacyEnabled,
  'quietHoursEnabled': settings.quietHoursEnabled,
  'quietHoursStart': settings.quietHoursStart.format(),
  'quietHoursEnd': settings.quietHoursEnd.format(),
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
  'soundEnabled': settings.soundEnabled,
  'quietHoursEnabled': settings.quietHoursEnabled,
  'quietHoursStart': settings.quietHoursStart.format(),
  'quietHoursEnd': settings.quietHoursEnd.format(),
};
```

In `lib/core/backup/import_orchestrator.dart`, change the `AppSettings(`
construction inside `applyImport` from:

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
            quietHoursEnabled:
                appSettingsJson['quietHoursEnabled'] as bool? ?? false,
            quietHoursStart: LocalTime.parse(
              appSettingsJson['quietHoursStart'] as String? ?? '22:00',
            ),
            quietHoursEnd: LocalTime.parse(
              appSettingsJson['quietHoursEnd'] as String? ?? '07:00',
            ),
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
            // these fields existed must still import cleanly, at the
            // same defaults a fresh install gets.
            biometricEnabled:
                appSettingsJson['biometricEnabled'] as bool? ?? true,
            screenPrivacyEnabled:
                appSettingsJson['screenPrivacyEnabled'] as bool? ?? false,
            soundEnabled: appSettingsJson['soundEnabled'] as bool? ?? false,
            quietHoursEnabled:
                appSettingsJson['quietHoursEnabled'] as bool? ?? false,
            quietHoursStart: LocalTime.parse(
              appSettingsJson['quietHoursStart'] as String? ?? '22:00',
            ),
            quietHoursEnd: LocalTime.parse(
              appSettingsJson['quietHoursEnd'] as String? ?? '07:00',
            ),
          ),
```

- [ ] **Step 9: Fix the two test-only `SettingsRepository` fixtures**

`soundEnabled` is `required`, so every hand-written `AppSettings(...)`
and every hand-written `implements SettingsRepository` fake must be
updated or the whole suite fails to compile.

In `test/core/security/lock_screen_test.dart`, change `_testSettings`
from:

```dart
const _testSettings = AppSettings(
  locale: AppLocale.en,
  themeMode: AppThemeMode.system,
  waterUnit: WaterUnit.ml,
  pinEnabled: true,
  pinLockTimeoutSeconds: 0,
  biometricEnabled: false,
  screenPrivacyEnabled: false,
  quietHoursEnabled: false,
  quietHoursStart: LocalTime(22, 0),
  quietHoursEnd: LocalTime(7, 0),
);
```

to:

```dart
const _testSettings = AppSettings(
  locale: AppLocale.en,
  themeMode: AppThemeMode.system,
  waterUnit: WaterUnit.ml,
  pinEnabled: true,
  pinLockTimeoutSeconds: 0,
  biometricEnabled: false,
  screenPrivacyEnabled: false,
  soundEnabled: false,
  quietHoursEnabled: false,
  quietHoursStart: LocalTime(22, 0),
  quietHoursEnd: LocalTime(7, 0),
);
```

In the same file, add a new override to `_StubSettingsRepo` right after
`updateQuietHours`'s block (before `restoreSettings`):

```dart
  @override
  Future<Result<void>> updateSoundEnabled({required bool enabled}) =>
      Future.value(const Result.success(null));
```

In `test/features/settings/presentation/screens/pin_settings_screen_test.dart`,
add `soundEnabled: false,` to **both** of the file's `const AppSettings(`
constructions (the one inside the `'toggling biometric...'` test and the
one inside the `'toggling screen privacy...'` test), right after each
one's `screenPrivacyEnabled: false,` line. For example, the first
changes from:

```dart
      final repo = _ReactiveSettingsRepo(
        const AppSettings(
          locale: AppLocale.en,
          themeMode: AppThemeMode.system,
          waterUnit: WaterUnit.ml,
          pinEnabled: true,
          pinLockTimeoutSeconds: 0,
          biometricEnabled: true,
          screenPrivacyEnabled: false,
          quietHoursEnabled: false,
          quietHoursStart: LocalTime(22, 0),
          quietHoursEnd: LocalTime(7, 0),
        ),
      );
```

to:

```dart
      final repo = _ReactiveSettingsRepo(
        const AppSettings(
          locale: AppLocale.en,
          themeMode: AppThemeMode.system,
          waterUnit: WaterUnit.ml,
          pinEnabled: true,
          pinLockTimeoutSeconds: 0,
          biometricEnabled: true,
          screenPrivacyEnabled: false,
          soundEnabled: false,
          quietHoursEnabled: false,
          quietHoursStart: LocalTime(22, 0),
          quietHoursEnd: LocalTime(7, 0),
        ),
      );
```

(apply the same one-line addition to the second, `biometricEnabled:
false,` construction in the screen-privacy test). Then add a new
override to `_ReactiveSettingsRepo` right after `updateQuietHours`'s
block (before `restoreSettings`):

```dart
  @override
  Future<Result<void>> updateSoundEnabled({required bool enabled}) async {
    await _update((s) => s.copyWith(soundEnabled: enabled));
    return const Result.success(null);
  }
```

- [ ] **Step 10: Regenerate code**

Run: `dart run build_runner build --delete-conflicting-outputs | tail -10`
Expected: exits 0, regenerates `app_settings.freezed.dart` and
`app_database.g.dart` (both gitignored, not committed) with the new
field/column.

- [ ] **Step 11: Run the test, confirm it passes**

Run: `flutter test test/features/settings/data/repositories/settings_repository_impl_test.dart | tail -10`
Expected: `+1: All tests passed!`

- [ ] **Step 12: Full analyze + test sweep**

Run: `flutter analyze | tail -10`
Expected: `No issues found!` — confirms every `AppSettings(...)`
construction and every `implements SettingsRepository` fake compiles.

Run: `flutter test | tail -10`
Expected: no new failures beyond whatever pre-existing failures the repo
already had before this task.

- [ ] **Step 13: Commit**

```bash
git add lib/core/database/tables/app_settings_table.dart \
  lib/core/database/app_database.dart \
  lib/features/settings/domain/entities/app_settings.dart \
  lib/features/settings/domain/repositories/settings_repository.dart \
  lib/features/settings/data/repositories/settings_repository_impl.dart \
  lib/core/backup/export_orchestrator.dart \
  lib/core/backup/import_orchestrator.dart \
  test/core/security/lock_screen_test.dart \
  test/features/settings/presentation/screens/pin_settings_screen_test.dart \
  test/features/settings/data/repositories/settings_repository_impl_test.dart
git commit -m "feat(settings): add soundEnabled field, off by default"
```

---

### Task 2: Settings toggle UI

**Files:**
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Modify: `lib/features/settings/presentation/screens/settings_home_screen.dart:61-68`
- Test: `test/features/settings/presentation/screens/settings_home_screen_test.dart`

**Interfaces:**
- Consumes: `AppSettings.soundEnabled`,
  `SettingsRepository.updateSoundEnabled` (Task 1).
- Produces: nothing consumed by later tasks — Task 4's chime call site
  reads `AppSettings.soundEnabled` directly via `appSettingsProvider`,
  not through this screen.

- [ ] **Step 1: Add l10n keys to both arb files**

In `lib/core/l10n/app_en.arb`, insert at the very end of the file,
right after the existing `"quietHoursDescription"` block — find this
exact anchor text (the file's last 4 lines):

```json
  "quietHoursDescription": "Suppress non-critical notifications during sleep hours. Medicine dose and prayer reminders are never suppressed.",
  "@quietHoursDescription": {
    "description": "Description text explaining what quiet hours does."
  }
}
```

Replace it with:

```json
  "quietHoursDescription": "Suppress non-critical notifications during sleep hours. Medicine dose and prayer reminders are never suppressed.",
  "@quietHoursDescription": {
    "description": "Description text explaining what quiet hours does."
  },
  "settingsSound": "Sound",
  "@settingsSound": {
    "description": "Settings section header for the in-app chime toggle."
  },
  "settingsSoundToggle": "Play a chime when a dose is marked done",
  "@settingsSoundToggle": {
    "description": "Switch label enabling/disabling the dose-done completion chime."
  }
}
```

In `lib/core/l10n/app_bn.arb`, insert at the very end of the file, right
after the existing `"quietHoursDescription"` line — find this exact
anchor text (the file's last line):

```json
  "quietHoursDescription": "ঘুমের সময় গুরুত্বহীন বিজ্ঞপ্তি দমন করুন। ওষুধের ডোজ এবং নামাজের রিমাইন্ডার কখনই দমন করা হয় না।"
}
```

Replace it with:

```json
  "quietHoursDescription": "ঘুমের সময় গুরুত্বহীন বিজ্ঞপ্তি দমন করুন। ওষুধের ডোজ এবং নামাজের রিমাইন্ডার কখনই দমন করা হয় না।",
  "settingsSound": "শব্দ",
  "settingsSoundToggle": "ডোজ সম্পন্ন হিসেবে চিহ্নিত হলে একটি সুর বাজান"
}
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors; `AppLocalizations.settingsSound`/
`settingsSoundToggle` getters appear.

- [ ] **Step 3: Write the failing widget test**

Create `test/features/settings/presentation/screens/settings_home_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/settings/presentation/screens/settings_home_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    'the sound toggle defaults off and persists when switched on',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(
        SwitchListTile,
        l10n.settingsSoundToggle,
      );
      expect(tile, findsOneWidget);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(
        (await SettingsRepositoryImpl(db).watchSettings().first).soundEnabled,
        isTrue,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, l10n.settingsSoundToggle),
            )
            .value,
        isTrue,
      );

      await disposeTree(tester);
    },
  );
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/screens/settings_home_screen_test.dart | tail -10`
Expected: FAIL — no `SwitchListTile` with the sound-toggle label exists
yet.

- [ ] **Step 5: Add the Sound section to `SettingsHomeScreen`**

In `lib/features/settings/presentation/screens/settings_home_screen.dart`,
change:

```dart
          ListTile(
            leading: const Icon(Icons.nightlight_outlined),
            title: Text(l10n.settingsQuietHours),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/quiet-hours'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSecurity),
```

to:

```dart
          ListTile(
            leading: const Icon(Icons.nightlight_outlined),
            title: Text(l10n.settingsQuietHours),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/quiet-hours'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSound),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(l10n.settingsSoundToggle),
            value: ref.watch(appSettingsProvider).value?.soundEnabled ?? false,
            onChanged: (value) => ref
                .read(settingsRepositoryProvider)
                .updateSoundEnabled(enabled: value),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSecurity),
```

No new import is needed — `appSettingsProvider` and
`settingsRepositoryProvider` both already come from this file's
existing `app_settings_providers.dart` import (`pinEnabled` at the top
of `build` already uses `appSettingsProvider`).

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/screens/settings_home_screen_test.dart | tail -10`
Expected: `+1: All tests passed!`

- [ ] **Step 7: Analyze and format**

Run: `flutter analyze lib/features/settings/presentation/screens/settings_home_screen.dart | tail -10`
Run: `dart format lib/features/settings/presentation/screens/settings_home_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  lib/features/settings/presentation/screens/settings_home_screen.dart \
  test/features/settings/presentation/screens/settings_home_screen_test.dart
git commit -m "feat(settings): add the Sound section with the dose-done chime toggle"
```

---

### Task 3: `ChimePlayer` — the `audioplayers` wrapper

**Files:**
- Modify: `pubspec.yaml`
- Create: `assets/sounds/dose_done_chime.mp3`
- Create: `lib/core/audio/chime_player.dart`
- Test: `test/core/audio/chime_player_test.dart`

**Interfaces:**
- Produces: `class ChimePlayer` with `ChimePlayer({AudioPlayer? player})`
  and `static final ChimePlayer instance`, plus
  `Future<void> playDoseDoneChime()` — consumed by Task 4's
  `medicine_home_screen.dart` wiring.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add audioplayers | tail -10`
Expected: adds `audioplayers: ^<latest>` to `pubspec.yaml`'s
`dependencies` (inserted alphabetically by the tool itself, landing
between `adhan_dart` and `clock`), runs `flutter pub get`
automatically. No manual version number to guess — this always
resolves to whatever is current and compatible.

- [ ] **Step 2: Register the asset in `pubspec.yaml`**

In `pubspec.yaml`, change:

```yaml
flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/data/prayer_cities.json
```

to:

```yaml
flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/data/prayer_cities.json
    - assets/sounds/dose_done_chime.mp3
```

- [ ] **Step 3: Create the bundled chime asset**

Run:

```bash
mkdir -p assets/sounds
ffmpeg -y -f lavfi -i "sine=frequency=880:duration=0.3" \
  -af "afade=t=out:st=0.2:d=0.1" assets/sounds/dose_done_chime.mp3
```

Expected: creates `assets/sounds/dose_done_chime.mp3`, a real, valid,
~0.3-second 880Hz tone that fades out over its last 0.1s — short,
soft, non-jarring, matching the spec's ask. If `ffmpeg` isn't installed
locally, install it first (`brew install ffmpeg` on macOS) rather than
substituting a placeholder file — the asset must actually decode as
valid audio for `audioplayers` to play it.

- [ ] **Step 4: Write the failing unit test**

Create `test/core/audio/chime_player_test.dart`:

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/audio/chime_player.dart';
import 'package:mocktail/mocktail.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late _MockAudioPlayer player;

  setUpAll(() {
    registerFallbackValue(AssetSource('sounds/dose_done_chime.mp3'));
    registerFallbackValue(const AudioContext());
  });

  setUp(() {
    player = _MockAudioPlayer();
    when(() => player.setAudioContext(any())).thenAnswer((_) async {});
    when(() => player.play(any())).thenAnswer((_) async {});
  });

  test(
    'sets the silent-mode-respecting audio context, then plays the '
    'bundled asset',
    () async {
      final chime = ChimePlayer(player: player);

      await chime.playDoseDoneChime();

      verify(() => player.setAudioContext(any())).called(1);
      final played = verify(() => player.play(captureAny())).captured.single;
      expect(played, isA<AssetSource>());
      expect((played as AssetSource).path, 'sounds/dose_done_chime.mp3');
    },
  );

  test('swallows a playback failure without throwing', () async {
    when(() => player.setAudioContext(any())).thenThrow(Exception('boom'));
    final chime = ChimePlayer(player: player);

    await expectLater(chime.playDoseDoneChime(), completes);
  });
}
```

- [ ] **Step 5: Run test to verify it fails**

Run: `flutter test test/core/audio/chime_player_test.dart | tail -10`
Expected: FAIL to compile — `lib/core/audio/chime_player.dart` doesn't
exist yet.

- [ ] **Step 6: Write minimal implementation**

Create `lib/core/audio/chime_player.dart`:

```dart
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Plays the short, local dose-done completion chime
/// (`docs/superpowers/specs/02-delightful/
/// 10-optional-sound-design-pass-design.md`) — the one file in the app
/// that imports `package:audioplayers`, mirroring
/// `notification_service.dart`'s "one file owns the plugin" convention.
class ChimePlayer {
  /// Creates a chime player. [player] is a test seam — [instance], the
  /// one production call site should always use, never passes one and
  /// owns its own real [AudioPlayer].
  ChimePlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  /// The app's single real chime player.
  static final ChimePlayer instance = ChimePlayer();

  final AudioPlayer _player;

  /// `.ambient` (iOS) respects the ring/silent switch and Do Not
  /// Disturb, unlike `.playback`, which overrides both.
  /// `AndroidAudioFocus.none` + `sonification`/`notificationEvent`
  /// steers Android away from treating this like ordinary media
  /// playback (see the spec's "Out of scope" note on Android's
  /// `STREAM_MUSIC` ringer-mode quirk — not fully solved here, flagged
  /// as a follow-up once this is in testers' hands on real devices).
  static const _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notificationEvent,
    ),
  );

  /// Plays the bundled chime — fire-and-forget, no queueing. Swallows
  /// any playback failure (e.g. an unsupported codec on an emulator)
  /// without throwing: a missed chime is never worth surfacing as an
  /// error to the user or the logger's normal error channel.
  Future<void> playDoseDoneChime() async {
    try {
      await _player.setAudioContext(_context);
      unawaited(_player.play(AssetSource('sounds/dose_done_chime.mp3')));
    } on Object {
      // Deliberately silent — see the doc comment above.
    }
  }
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/core/audio/chime_player_test.dart | tail -10`
Expected: `+2: All tests passed!`

- [ ] **Step 8: Analyze and format**

Run: `flutter analyze lib/core/audio/chime_player.dart | tail -10`
Run: `dart format lib/core/audio/chime_player.dart`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock assets/sounds/dose_done_chime.mp3 \
  lib/core/audio/chime_player.dart test/core/audio/chime_player_test.dart
git commit -m "feat(core): add ChimePlayer, a silent-mode-respecting chime wrapper"
```

---

### Task 4: Wire the chime into `_markDoneAndCelebrate`

**Files:**
- Modify: `lib/features/medicine/presentation/screens/medicine_home_screen.dart:1-153`
- Test: `test/features/medicine/presentation/medicine_home_screen_test.dart`

**Interfaces:**
- Consumes: `ChimePlayer`/`ChimePlayer.instance` (Task 3),
  `AppSettings.soundEnabled` (Task 1).
- Produces: `MedicineHomeScreen(chimePlayer: ...)` test seam — consumed
  only by this task's own new tests.

- [ ] **Step 1: Write the failing widget tests**

Add to `test/features/medicine/presentation/medicine_home_screen_test.dart`,
new imports at the top:

```dart
import 'package:habit_tracker/core/audio/chime_player.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:mocktail/mocktail.dart';
```

and two new tests inside `main()`, after the existing `'overdue
(missed) dose is visually distinct'` test:

```dart
  testWidgets(
    'marking a dose done plays the chime when sound is enabled',
    (tester) async {
      await SettingsRepositoryImpl(db).updateSoundEnabled(enabled: true);

      final repo = MedicineRepositoryImpl(db);
      final medicine = await repo.createMedicine(
        name: 'Amoxicillin',
        stockEnabled: false,
      );
      await repo.createSchedule(
        medicineId: (medicine as Success<Medicine>).value.id,
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 6, 1),
      );
      final now = DateTime.utc(2026, 6, 1, 7);
      await withClock(Clock.fixed(now), () async {
        await repo.materializeDoses(clock.now());
      });

      final chime = _MockChimePlayer();
      when(() => chime.playDoseDoneChime()).thenAnswer((_) async {});

      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MedicineHomeScreen(chimePlayer: chime),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      verify(() => chime.playDoseDoneChime()).called(1);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'marking a dose done never plays a chime when sound is off (the '
    'default)',
    (tester) async {
      final repo = MedicineRepositoryImpl(db);
      final medicine = await repo.createMedicine(
        name: 'Amoxicillin',
        stockEnabled: false,
      );
      await repo.createSchedule(
        medicineId: (medicine as Success<Medicine>).value.id,
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 6, 1),
      );
      final now = DateTime.utc(2026, 6, 1, 7);
      await withClock(Clock.fixed(now), () async {
        await repo.materializeDoses(clock.now());
      });

      final chime = _MockChimePlayer();
      when(() => chime.playDoseDoneChime()).thenAnswer((_) async {});

      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MedicineHomeScreen(chimePlayer: chime),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      verifyNever(() => chime.playDoseDoneChime());

      await disposeTree(tester);
    },
  );
```

Add at the bottom of the file, after `main()`:

```dart
class _MockChimePlayer extends Mock implements ChimePlayer {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medicine/presentation/medicine_home_screen_test.dart | tail -10`
Expected: FAIL to compile — `MedicineHomeScreen` has no `chimePlayer`
parameter yet.

- [ ] **Step 3: Add the test seam and wire the call site**

In `lib/features/medicine/presentation/screens/medicine_home_screen.dart`,
add two new imports:

```dart
import 'package:habit_tracker/core/audio/chime_player.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
```

Change the class declaration from:

```dart
class MedicineHomeScreen extends ConsumerWidget {
  /// Creates the medicine home screen. [highlightDoseId], if set, came
  /// from a notification tap deep link (FR-C-09).
  const MedicineHomeScreen({super.key, this.highlightDoseId});

  /// Dose id to visually highlight, if opened via deep link.
  final String? highlightDoseId;
```

to:

```dart
class MedicineHomeScreen extends ConsumerWidget {
  /// Creates the medicine home screen. [highlightDoseId], if set, came
  /// from a notification tap deep link (FR-C-09). [chimePlayer] is a
  /// test-only seam — production code always falls back to
  /// [ChimePlayer.instance] (resolved in [build], not here, so this
  /// constructor stays `const` for the existing
  /// `const MedicineHomeScreen()` route call site in
  /// `medicine_module.dart`).
  const MedicineHomeScreen({
    super.key,
    this.highlightDoseId,
    this.chimePlayer,
  });

  /// Dose id to visually highlight, if opened via deep link.
  final String? highlightDoseId;

  /// Test seam for [ChimePlayer.instance].
  final ChimePlayer? chimePlayer;
```

Change the `onDone` call site from:

```dart
                      onDone: () =>
                          _markDoneAndCelebrate(context, ref, view.dose.id),
```

to:

```dart
                      onDone: () => _markDoneAndCelebrate(
                        context,
                        ref,
                        view.dose.id,
                        chimePlayer ?? ChimePlayer.instance,
                      ),
```

Change `_markDoneAndCelebrate`'s signature and body from:

```dart
Future<void> _markDoneAndCelebrate(
  BuildContext context,
  WidgetRef ref,
  String doseId,
) async {
  // Captured synchronously (not re-read inside the deferred `onUndo`
  // below, which can fire after this widget's element is disposed).
  final controller = ref.read(medicineControllerProvider.notifier);
  final repository = ref.read(achievementRepositoryProvider);
  final before = await repository.watchByModule('medicine').first;
  final unlockedBefore = before
      .where((r) => r.unlockedAt != null)
      .map((r) => r.key)
      .toSet();

  await controller.markDoseDone(doseId);

  var wasUndone = false;
```

to:

```dart
Future<void> _markDoneAndCelebrate(
  BuildContext context,
  WidgetRef ref,
  String doseId,
  ChimePlayer chimePlayer,
) async {
  // Captured synchronously (not re-read inside the deferred `onUndo`
  // below, which can fire after this widget's element is disposed).
  final controller = ref.read(medicineControllerProvider.notifier);
  final repository = ref.read(achievementRepositoryProvider);
  final before = await repository.watchByModule('medicine').first;
  final unlockedBefore = before
      .where((r) => r.unlockedAt != null)
      .map((r) => r.key)
      .toSet();

  await controller.markDoseDone(doseId);

  // The chime is wired here — the UI-only call site — and nowhere in
  // `MedicineController`/`MedicineRepository`/`MedicineModule`, because
  // `MedicineModule.onNotificationAction` (the Done/Snooze/Skip
  // background-isolate path) calls the repository directly and has no
  // audio session to play into (`docs/superpowers/specs/02-delightful/
  // 10-optional-sound-design-pass-design.md`).
  if (ref.read(appSettingsProvider).value?.soundEnabled ?? false) {
    unawaited(chimePlayer.playDoseDoneChime());
  }

  var wasUndone = false;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medicine/presentation/medicine_home_screen_test.dart | tail -10`
Expected: `+5: All tests passed!` (the 3 pre-existing tests plus these
2).

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/features/medicine/presentation/screens/medicine_home_screen.dart | tail -10`
Run: `dart format lib/features/medicine/presentation/screens/medicine_home_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/medicine/presentation/screens/medicine_home_screen.dart \
  test/features/medicine/presentation/medicine_home_screen_test.dart
git commit -m "feat(medicine): play the dose-done chime from the UI-only call site"
```

---

### Task 5: Lock in the background-isolate exclusion

**Files:**
- Modify: `test/features/medicine/medicine_module_test.dart:144-157`

**Interfaces:**
- Consumes: nothing new — this documents/locks in an existing structural
  fact (`MedicineModule.onNotificationAction` never references
  `ChimePlayer`) rather than adding new production code.

- [ ] **Step 1: Strengthen the existing regression guard**

`test/features/medicine/medicine_module_test.dart` already has a plain
`test()` (not `testWidgets()`) exercising
`module.onNotificationAction('d1', NotificationActionType.done)` — a
plain `test()` has no `TestWidgetsFlutterBinding`/mocked platform
channels registered at all, so if `onNotificationAction`'s path ever
grew a real call into `ChimePlayer.instance` (which calls into the real
`audioplayers` plugin), this test would start throwing
(`MissingPluginException` or similar) with no channel to answer it.
Staying green *is* the regression guard for Task 4's Problem-section
finding. Make that intent explicit by renaming the test.

Change:

```dart
  test('onNotificationAction(done) marks the dose done', () async {
    when(
      () => repo.markDoseDone(
        any(),
        fromOtherSource: any(named: 'fromOtherSource'),
      ),
    ).thenAnswer((_) async => const Result.success(null));

    await module.onNotificationAction('d1', NotificationActionType.done);

    verify(
      () => repo.markDoseDone('d1', fromOtherSource: false),
    ).called(1);
  });
```

to:

```dart
  test(
    'onNotificationAction(done) marks the dose done — and, being a '
    'plain test() with no Flutter test binding registered, doubles as '
    'the regression guard that this background-isolate path never '
    'grows a dependency on ChimePlayer/audioplayers '
    '(docs/superpowers/specs/02-delightful/'
    '10-optional-sound-design-pass-design.md): a real AudioPlayer '
    'platform-channel call here would throw without one registered',
    () async {
      when(
        () => repo.markDoseDone(
          any(),
          fromOtherSource: any(named: 'fromOtherSource'),
        ),
      ).thenAnswer((_) async => const Result.success(null));

      await module.onNotificationAction('d1', NotificationActionType.done);

      verify(
        () => repo.markDoseDone('d1', fromOtherSource: false),
      ).called(1);
    },
  );
```

- [ ] **Step 2: Run test to verify it still passes**

Run: `flutter test test/features/medicine/medicine_module_test.dart | tail -10`
Expected: all pre-existing tests in this file still pass (this step
renamed a test description only — no behavior changed).

- [ ] **Step 3: Analyze and format**

Run: `dart format test/features/medicine/medicine_module_test.dart`
Expected: no formatting diffs beyond the intended rename.

- [ ] **Step 4: Commit**

```bash
git add test/features/medicine/medicine_module_test.dart
git commit -m "test(medicine): document the background-isolate/ChimePlayer exclusion"
```

---

## After all tasks

Per this repo's CLAUDE.md spec-implementation workflow: once every task
above is committed, open a PR for the spec with the design summary in
the description, then run a code review against the finished PR
(comment → fix → commit cycle, up to 5 rounds), then stop and wait for
the user's own review and merge.

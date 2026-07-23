# Ramadan Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the app real Ramadan awareness — a Hijri-calendar-detected
(or manually forced) mode that shifts Water's reminder windows outside
fasting hours and relabels Fajr/Maghrib as Sehri/Iftar with a countdown —
per `docs/superpowers/specs/02-delightful/01-ramadan-mode-design.md`.

**Architecture:** A pure `isRamadan`/`resolveRamadanModeActive` utility
(new `hijri` dependency) backs two new nullable/defaulted `app_settings`
columns (schema v7→v8). `WaterModule` gains two optional, additive
constructor dependencies (`SettingsRepository`, `PrayerRepository`) so it
can read Ramadan state and Prayer's own location/calculation settings
without hard-depending on Prayer being registered — every existing
single-argument `WaterModule(repo)` call site keeps compiling and keeps
today's exact behavior. `PrayerModule` gains one optional
`SettingsRepository` dependency for the same reason, used only to relabel
notification/dashboard text — `calculatePrayerTimes()` itself is never
touched.

**Tech Stack:** Flutter/Riverpod (codegen), Drift (codegen), `gen_l10n`,
`flutter_test`, `mocktail`, `package:clock`.

## Global Constraints

- New dependency: `hijri: ^3.0.0` (pure Dart, Umm al-Qura-based, no
  transitive deps, no network — `import 'package:hijri/hijri_calendar.dart';`,
  `HijriCalendar.fromDate(DateTime)` then `.hMonth`/`.hDay`; Ramadan is
  Hijri month 9).
- **Migration:** `schemaVersion` 7 → 8 (current `AppDatabase.schemaVersion`
  is `7` as of this plan — if another schema-bumping plan merges first,
  adjust `7`/`8` to whatever is then current; the `if (from < N) {...}`
  migration seam itself doesn't otherwise change). Two new
  `AppSettingsTable` columns: `ramadanModeManualOverride` (nullable bool,
  no default — tri-state: `true`/`false` pins the mode, `null` follows
  auto-detection), `ramadanAutoDetectEnabled` (bool, `@Default(true)` on
  the entity / `withDefault(const Constant(true))` on the table).
- `ramadanAutoDetectEnabled` uses Freezed's `@Default(true)` (not
  `required`) and `ramadanModeManualOverride` is a plain nullable field —
  deliberately, so the four other existing `AppSettings(...)` call sites
  (`import_orchestrator.dart`, `settings_repository_impl.dart`'s
  `_toDomain`, `test/core/security/lock_screen_test.dart`,
  `test/features/settings/presentation/screens/pin_settings_screen_test
  .dart` ×2) don't all need a mechanical two-field edit the way the
  PIN-lock toggles plan's `required` fields did — only the two files
  that need the *real* values (`_toDomain`, `import_orchestrator.dart`)
  are touched, both in Task 2.
- `WaterModule`'s constructor gains `{SettingsRepository? settingsRepository,
  PrayerRepository? prayerRepository}` (both optional, named, additive).
  `PrayerModule`'s constructor gains `{SettingsRepository? settingsRepository}`
  (same). Every pre-existing single-positional-argument call site
  (`WaterModule(repo)` / `PrayerModule(repo)` in `water_module_test.dart`/
  `prayer_module_test.dart`) keeps compiling unchanged and keeps
  Ramadan mode permanently inactive (matches "Water must keep working
  with Prayer's module registry absent").
- No changes to `notification_planner.dart`'s window/cap/diff logic —
  Ramadan mode only changes what `WaterModule.pendingNotifications()`/
  `PrayerModule.pendingNotifications()` feed into that unchanged pipeline.
- No new prayer-calculation method — `calculatePrayerTimes()` is called
  exactly as Prayer's own module already calls it.
- New l10n keys go in **both** `lib/core/l10n/app_en.arb` and
  `lib/core/l10n/app_bn.arb`; run `flutter gen-l10n` after each ARB edit
  and before running any test that references the new getters.
- Per this repo's CLAUDE.md spec-implementation workflow: one commit per
  task, run only that task's own test file (never the full `flutter
  test` suite mid-task), pipe `build_runner`/`test`/`gen-l10n` output
  through `| tail -10`.

---

### Task 1: Hijri detection utility

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/utils/hijri_date.dart`
- Test: `test/core/utils/hijri_date_test.dart`

**Interfaces:**
- Produces: `bool isRamadan(LocalDate gregorianDate)`,
  `int? ramadanDayNumber(LocalDate gregorianDate)`,
  `bool resolveRamadanModeActive({required bool? manualOverride, required
  bool autoDetectEnabled, required LocalDate today})` — all three consumed
  by Task 2's settings screen logic (indirectly) and Tasks 4/5's module
  wiring.
- Note on interpretation: the design spec's snippet declares
  `resolveRamadanModeActive(AppSettings settings, LocalDate today)`
  (taking the whole entity). This plan instead takes the two relevant
  primitives directly (`manualOverride`/`autoDetectEnabled`) so
  `core/utils/` doesn't import a `features/settings/domain` entity —
  keeping the existing dependency direction (`core/` never imports
  `features/`) intact. Call sites in Tasks 4/5 pass
  `appSettings.ramadanModeManualOverride`/`appSettings.ramadanAutoDetectEnabled`
  instead of the whole object; behavior is identical.

- [ ] **Step 1: Write the failing test**

Create `test/core/utils/hijri_date_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/hijri_date.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  group('isRamadan / ramadanDayNumber', () {
    test('2025-03-05 (day 5 of Ramadan 1446 AH, Umm al-Qura) is Ramadan', () {
      const date = LocalDate(2025, 3, 5);
      expect(isRamadan(date), isTrue);
      expect(ramadanDayNumber(date), 5);
    });

    test('2025-04-01 (a few days after Eid al-Fitr 1446 AH) is not Ramadan', () {
      const date = LocalDate(2025, 4, 1);
      expect(isRamadan(date), isFalse);
      expect(ramadanDayNumber(date), isNull);
    });

    test('a date far from Ramadan (mid-year) is not Ramadan', () {
      const date = LocalDate(2025, 8, 15);
      expect(isRamadan(date), isFalse);
      expect(ramadanDayNumber(date), isNull);
    });
  });

  group('resolveRamadanModeActive', () {
    const ramadanDay = LocalDate(2025, 3, 5);
    const nonRamadanDay = LocalDate(2025, 8, 15);

    test('manual override true wins regardless of the calendar date', () {
      expect(
        resolveRamadanModeActive(
          manualOverride: true,
          autoDetectEnabled: true,
          today: nonRamadanDay,
        ),
        isTrue,
      );
    });

    test('manual override false wins even during real Ramadan', () {
      expect(
        resolveRamadanModeActive(
          manualOverride: false,
          autoDetectEnabled: true,
          today: ramadanDay,
        ),
        isFalse,
      );
    });

    test('no override + auto-detect on follows the Hijri calendar', () {
      expect(
        resolveRamadanModeActive(
          manualOverride: null,
          autoDetectEnabled: true,
          today: ramadanDay,
        ),
        isTrue,
      );
      expect(
        resolveRamadanModeActive(
          manualOverride: null,
          autoDetectEnabled: true,
          today: nonRamadanDay,
        ),
        isFalse,
      );
    });

    test('no override + auto-detect off is always inactive', () {
      expect(
        resolveRamadanModeActive(
          manualOverride: null,
          autoDetectEnabled: false,
          today: ramadanDay,
        ),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/hijri_date_test.dart | tail -10`
Expected: FAIL — `lib/core/utils/hijri_date.dart` doesn't exist yet (import
error).

- [ ] **Step 3: Add the dependency and write the implementation**

In `pubspec.yaml`, add to `dependencies:` (alphabetically, after
`go_router`):

```yaml
  hijri: ^3.0.0
```

Run: `flutter pub get | tail -10`

Create `lib/core/utils/hijri_date.dart`:

```dart
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:hijri/hijri_calendar.dart';

/// Ramadan is Hijri month 9.
const _ramadanHijriMonth = 9;

/// Whether [gregorianDate] falls within Ramadan (Hijri month 9), per the
/// Umm al-Qura calendar `package:hijri` implements
/// (`docs/superpowers/specs/02-delightful/01-ramadan-mode-design.md`).
/// Pure, deterministic, no I/O — safe to call from `pendingNotifications()`.
///
/// Umm al-Qura is a *calculated* calendar, not local moon-sighting — good
/// enough for reminder scheduling (off by at most a day around the
/// boundary, self-correcting the next day), not good enough to claim
/// liturgical authority; [resolveRamadanModeActive]'s manual-override
/// escape hatch exists precisely because of this.
bool isRamadan(LocalDate gregorianDate) =>
    HijriCalendar.fromDate(gregorianDate.toDateTimeUtc()).hMonth ==
    _ramadanHijriMonth;

/// The Hijri day-of-Ramadan (1-30) for [gregorianDate], or `null` if it
/// isn't in Ramadan.
int? ramadanDayNumber(LocalDate gregorianDate) {
  final hijri = HijriCalendar.fromDate(gregorianDate.toDateTimeUtc());
  return hijri.hMonth == _ramadanHijriMonth ? hijri.hDay : null;
}

/// The effective Ramadan-mode state for [today]: [manualOverride] wins if
/// set (`true`/`false`); otherwise falls back to [isRamadan] when
/// [autoDetectEnabled], else always `false`.
bool resolveRamadanModeActive({
  required bool? manualOverride,
  required bool autoDetectEnabled,
  required LocalDate today,
}) {
  if (manualOverride != null) return manualOverride;
  if (!autoDetectEnabled) return false;
  return isRamadan(today);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/hijri_date_test.dart | tail -10`
Expected: `+8: All tests passed!`

If the two date-fixture tests (`2025-03-05`/`2025-04-01`) fail because
`package:hijri`'s Umm al-Qura tables place the boundary a day differently
than assumed, adjust the fixture dates in the test to whatever that
package's own `HijriCalendar.fromDate` actually returns for a
well-known-Ramadan-day and a well-known-non-Ramadan-day (the *logic*
under test — override precedence, auto-detect toggle — doesn't depend on
which exact dates are Ramadan, so the fixtures may need a one-line date
tweak against the installed package version, not a design change).

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze lib/core/utils/hijri_date.dart | tail -10`
Expected: `No issues found!`

```bash
git add pubspec.yaml pubspec.lock lib/core/utils/hijri_date.dart \
  test/core/utils/hijri_date_test.dart
git commit -m "feat(core): add Hijri Ramadan detection utility"
```

---

### Task 2: Settings — schema, entity, repository, backup round-trip

**Files:**
- Modify: `lib/core/database/tables/app_settings_table.dart`
- Modify: `lib/core/database/app_database.dart:53-54,100-107`
- Modify: `lib/features/settings/domain/entities/app_settings.dart:45-59`
- Modify: `lib/features/settings/domain/repositories/settings_repository.dart`
- Modify: `lib/features/settings/data/repositories/settings_repository_impl.dart`
- Modify: `lib/core/backup/export_orchestrator.dart:39-50`
- Modify: `lib/core/backup/import_orchestrator.dart:162-191`
- Test: `test/features/settings/data/repositories/settings_repository_impl_test.dart`

**Interfaces:**
- Produces: `AppSettings.ramadanModeManualOverride` (`bool?`),
  `AppSettings.ramadanAutoDetectEnabled` (`bool`, `@Default(true)`) —
  consumed by Task 3's screen and Tasks 4/5's module wiring.
- Produces: `SettingsRepository.updateRamadanModeManualOverride(bool?
  override)`, `SettingsRepository.updateRamadanAutoDetectEnabled({required
  bool enabled})` — consumed by Task 3.

- [ ] **Step 1: Write the failing repository test**

In `test/features/settings/data/repositories/settings_repository_impl_test.dart`,
add right after the existing
`expect(firstRead.screenPrivacyEnabled, isFalse);` line:

```dart
    expect(firstRead.ramadanAutoDetectEnabled, isTrue);
    expect(firstRead.ramadanModeManualOverride, isNull);
```

Right after the existing
```dart
    final privacyResult = await repo1.updateScreenPrivacyEnabled(
      enabled: true,
    );
    expect(privacyResult, isA<Success<void>>());
```
add:

```dart
    final ramadanAutoDetectResult = await repo1.updateRamadanAutoDetectEnabled(
      enabled: false,
    );
    expect(ramadanAutoDetectResult, isA<Success<void>>());
    final ramadanOverrideResult = await repo1.updateRamadanModeManualOverride(
      true,
    );
    expect(ramadanOverrideResult, isA<Success<void>>());
```

Right after the existing `expect(afterRestart.screenPrivacyEnabled, isTrue);`,
add:

```dart
    expect(afterRestart.ramadanAutoDetectEnabled, isFalse);
    expect(afterRestart.ramadanModeManualOverride, isTrue);
```

- [ ] **Step 2: Run it, confirm it fails to compile**

Run: `flutter test test/features/settings/data/repositories/settings_repository_impl_test.dart | tail -10`
Expected: compile error — `ramadanAutoDetectEnabled`/
`ramadanModeManualOverride`/`updateRamadanAutoDetectEnabled`/
`updateRamadanModeManualOverride` don't exist yet.

- [ ] **Step 3: Add the DB columns**

In `lib/core/database/tables/app_settings_table.dart`, add after the
`screenPrivacyEnabled` column, before `quietHoursEnabled`:

```dart
  /// Manual override: `true`/`false` pins Ramadan mode; `null` (default)
  /// means "follow `isRamadan(today)` automatically"
  /// (`docs/superpowers/specs/02-delightful/01-ramadan-mode-design.md`).
  BoolColumn get ramadanModeManualOverride => boolean().nullable()();

  /// Whether Ramadan-mode auto-detection is enabled at all. Default
  /// `true`; a user who turns it off never sees the mode unless they
  /// also pin [ramadanModeManualOverride].
  BoolColumn get ramadanAutoDetectEnabled =>
      boolean().withDefault(const Constant(true))();
```

- [ ] **Step 4: Bump schema version and add the migration**

In `lib/core/database/app_database.dart`, change:

```dart
  @override
  int get schemaVersion => 7;
```

to:

```dart
  @override
  int get schemaVersion => 8;
```

And add a new block right before the `// Seam:` comment inside
`onUpgrade`:

```dart
      if (from < 8) {
        // Ramadan mode (`docs/superpowers/specs/02-delightful/
        // 01-ramadan-mode-design.md`).
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.ramadanModeManualOverride,
        );
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.ramadanAutoDetectEnabled,
        );
      }
      // Seam: when schemaVersion increments further, add
      // `if (from < N) ...` blocks here — no other file needs to
      // change for a schema migration.
```

- [ ] **Step 5: Add the entity fields**

In `lib/features/settings/domain/entities/app_settings.dart`, change the
factory from:

```dart
    required bool quietHoursEnabled,
    required LocalTime quietHoursStart,
    required LocalTime quietHoursEnd,
  }) = _AppSettings;
```

to:

```dart
    required bool quietHoursEnabled,
    required LocalTime quietHoursStart,
    required LocalTime quietHoursEnd,
    bool? ramadanModeManualOverride,
    @Default(true) bool ramadanAutoDetectEnabled,
  }) = _AppSettings;
```

- [ ] **Step 6: Add the repository interface methods**

In `lib/features/settings/domain/repositories/settings_repository.dart`,
add after `updateQuietHours`:

```dart
  /// Manual Ramadan-mode override: `true`/`false` pins it, `null` clears
  /// the override back to auto-detection.
  Future<Result<void>> updateRamadanModeManualOverride(bool? override);

  /// Enables or disables Hijri-calendar Ramadan auto-detection.
  Future<Result<void>> updateRamadanAutoDetectEnabled({required bool enabled});
```

- [ ] **Step 7: Implement them and wire `_toDomain`/`restoreSettings`**

In `lib/features/settings/data/repositories/settings_repository_impl.dart`,
add after `updateQuietHours`'s implementation:

```dart
  @override
  Future<Result<void>> updateRamadanModeManualOverride(bool? override) =>
      _update(
        AppSettingsTableCompanion(ramadanModeManualOverride: Value(override)),
      );

  @override
  Future<Result<void>> updateRamadanAutoDetectEnabled({
    required bool enabled,
  }) => _update(
    AppSettingsTableCompanion(ramadanAutoDetectEnabled: Value(enabled)),
  );
```

Change `_toDomain` from:

```dart
    quietHoursEnabled: row.quietHoursEnabled,
    quietHoursStart: LocalTime.parse(row.quietHoursStart),
    quietHoursEnd: LocalTime.parse(row.quietHoursEnd),
  );
```

to:

```dart
    quietHoursEnabled: row.quietHoursEnabled,
    quietHoursStart: LocalTime.parse(row.quietHoursStart),
    quietHoursEnd: LocalTime.parse(row.quietHoursEnd),
    ramadanModeManualOverride: row.ramadanModeManualOverride,
    ramadanAutoDetectEnabled: row.ramadanAutoDetectEnabled,
  );
```

In `restoreSettings`, change the written companion from:

```dart
          quietHoursEnabled: Value(settings.quietHoursEnabled),
          quietHoursStart: Value(settings.quietHoursStart.format()),
          quietHoursEnd: Value(settings.quietHoursEnd.format()),
          updatedAt: Value(now),
        ),
```

to:

```dart
          quietHoursEnabled: Value(settings.quietHoursEnabled),
          quietHoursStart: Value(settings.quietHoursStart.format()),
          quietHoursEnd: Value(settings.quietHoursEnd.format()),
          ramadanModeManualOverride: Value(settings.ramadanModeManualOverride),
          ramadanAutoDetectEnabled: Value(settings.ramadanAutoDetectEnabled),
          updatedAt: Value(now),
        ),
```

- [ ] **Step 8: Wire backup export/import**

In `lib/core/backup/export_orchestrator.dart`, change `_appSettingsToJson`
from:

```dart
  'quietHoursEnabled': settings.quietHoursEnabled,
  'quietHoursStart': settings.quietHoursStart.format(),
  'quietHoursEnd': settings.quietHoursEnd.format(),
};
```

to:

```dart
  'quietHoursEnabled': settings.quietHoursEnabled,
  'quietHoursStart': settings.quietHoursStart.format(),
  'quietHoursEnd': settings.quietHoursEnd.format(),
  'ramadanModeManualOverride': settings.ramadanModeManualOverride,
  'ramadanAutoDetectEnabled': settings.ramadanAutoDetectEnabled,
};
```

In `lib/core/backup/import_orchestrator.dart`, change the `AppSettings(`
construction from:

```dart
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
            quietHoursEnabled:
                appSettingsJson['quietHoursEnabled'] as bool? ?? false,
            quietHoursStart: LocalTime.parse(
              appSettingsJson['quietHoursStart'] as String? ?? '22:00',
            ),
            quietHoursEnd: LocalTime.parse(
              appSettingsJson['quietHoursEnd'] as String? ?? '07:00',
            ),
            // An older export made before these two fields existed must
            // still import cleanly, at the same defaults a fresh install
            // gets (`null`/`true`).
            ramadanModeManualOverride:
                appSettingsJson['ramadanModeManualOverride'] as bool?,
            ramadanAutoDetectEnabled:
                appSettingsJson['ramadanAutoDetectEnabled'] as bool? ?? true,
          ),
```

- [ ] **Step 9: Regenerate code**

Run: `dart run build_runner build --delete-conflicting-outputs | tail -10`
Expected: exits 0, regenerates `app_settings.freezed.dart` and
`app_database.g.dart` (both gitignored) with the new fields/columns.

- [ ] **Step 10: Run the test, confirm it passes**

Run: `flutter test test/features/settings/data/repositories/settings_repository_impl_test.dart | tail -10`
Expected: `+1: All tests passed!`

- [ ] **Step 11: Analyze**

Run: `flutter analyze | tail -10`
Expected: `No issues found!` — this also catches any other call site
constructing `AppSettings(...)` that might need attention (there should
be none besides `import_orchestrator.dart`/`_toDomain`, already fixed —
the other four call sites listed in Global Constraints compile unchanged
since both new fields are optional).

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
git commit -m "feat(settings): add Ramadan mode auto-detect/manual-override fields"
```

---

### Task 3: Ramadan mode settings screen

**Files:**
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Create: `lib/features/settings/presentation/screens/ramadan_settings_screen.dart`
- Modify: `lib/core/router/app_router.dart:17,67-68,156-159`
- Modify: `lib/features/settings/presentation/screens/settings_home_screen.dart`
- Test: `test/features/settings/presentation/screens/ramadan_settings_screen_test.dart`

**Interfaces:**
- Consumes: `AppSettings.ramadanModeManualOverride`/`ramadanAutoDetectEnabled`,
  `SettingsRepository.updateRamadanModeManualOverride`/
  `updateRamadanAutoDetectEnabled` from Task 2.
- Produces: nothing consumed by later tasks — self-contained UI.

- [ ] **Step 1: Add l10n keys to both arb files**

In `lib/core/l10n/app_en.arb`, insert right before the final closing `}`
(i.e. immediately after the existing last key,
`"@quietHoursDescription"`'s closing brace):

```json
  "quietHoursDescription": "Suppress non-critical notifications during sleep hours. Medicine dose and prayer reminders are never suppressed.",
  "@quietHoursDescription": {
    "description": "Description text explaining what quiet hours does."
  },
  "settingsRamadanMode": "Ramadan mode",
  "@settingsRamadanMode": {
    "description": "Settings-home nav entry linking to the Ramadan mode settings screen."
  },
  "ramadanModeSettingsTitle": "Ramadan mode",
  "@ramadanModeSettingsTitle": {
    "description": "AppBar title for the Ramadan mode settings screen."
  },
  "ramadanModeSettingsSubtitle": "Shift water reminders outside fasting hours and show Sehri/Iftar countdowns",
  "@ramadanModeSettingsSubtitle": {
    "description": "Explanatory subtitle on the Ramadan mode settings screen."
  },
  "ramadanModeAutoDetectToggle": "Detect Ramadan automatically",
  "@ramadanModeAutoDetectToggle": {
    "description": "Toggle enabling automatic Hijri-calendar Ramadan detection."
  },
  "ramadanModeManualToggle": "Ramadan mode",
  "@ramadanModeManualToggle": {
    "description": "Manual override toggle, shown only while auto-detect is off."
  }
}
```

(That is: keep the existing `quietHoursDescription` block exactly as-is,
just change the file's very last `}` into `},` and append the five new
keys followed by the closing `}`.)

In `lib/core/l10n/app_bn.arb`, apply the same "append before the final
`}`" edit — change the existing last line from:

```json
  "quietHoursDescription": "ঘুমের সময় গুরুত্বহীন বিজ্ঞপ্তি দমন করুন। ওষুধের ডোজ এবং নামাজের রিমাইন্ডার কখনই দমন করা হয় না।"
}
```

to:

```json
  "quietHoursDescription": "ঘুমের সময় গুরুত্বহীন বিজ্ঞপ্তি দমন করুন। ওষুধের ডোজ এবং নামাজের রিমাইন্ডার কখনই দমন করা হয় না।",
  "settingsRamadanMode": "রমজান মোড",
  "ramadanModeSettingsTitle": "রমজান মোড",
  "ramadanModeSettingsSubtitle": "রোজার সময় পানির রিমাইন্ডার সরিয়ে দিন এবং সেহরি/ইফতারের কাউন্টডাউন দেখুন",
  "ramadanModeAutoDetectToggle": "স্বয়ংক্রিয়ভাবে রমজান শনাক্ত করুন",
  "ramadanModeManualToggle": "রমজান মোড"
}
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors.

- [ ] **Step 3: Write the failing widget test**

Create `test/features/settings/presentation/screens/ramadan_settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/settings/presentation/screens/ramadan_settings_screen.dart';

import '../../../../support/test_database.dart';

void main() {
  testWidgets(
    'auto-detect is on and the manual toggle is hidden by default; turning '
    'auto-detect off reveals the manual toggle, which persists its value; '
    'turning auto-detect back on clears the manual override',
    (tester) async {
      final db = testDatabase();
      addTearDown(db.close);
      final settingsRepo = SettingsRepositoryImpl(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RamadanSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(
                SwitchListTile,
                l10n.ramadanModeAutoDetectToggle,
              ),
            )
            .value,
        isTrue,
      );
      expect(
        find.widgetWithText(SwitchListTile, l10n.ramadanModeManualToggle),
        findsNothing,
      );

      await tester.tap(
        find.widgetWithText(SwitchListTile, l10n.ramadanModeAutoDetectToggle),
      );
      await tester.pumpAndSettle();

      expect(
        (await settingsRepo.watchSettings().first).ramadanAutoDetectEnabled,
        isFalse,
      );
      expect(
        find.widgetWithText(SwitchListTile, l10n.ramadanModeManualToggle),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, l10n.ramadanModeManualToggle),
            )
            .value,
        isFalse,
      );

      await tester.tap(
        find.widgetWithText(SwitchListTile, l10n.ramadanModeManualToggle),
      );
      await tester.pumpAndSettle();
      expect(
        (await settingsRepo.watchSettings().first).ramadanModeManualOverride,
        isTrue,
      );

      await tester.tap(
        find.widgetWithText(SwitchListTile, l10n.ramadanModeAutoDetectToggle),
      );
      await tester.pumpAndSettle();
      final afterReEnable = await settingsRepo.watchSettings().first;
      expect(afterReEnable.ramadanAutoDetectEnabled, isTrue);
      expect(afterReEnable.ramadanModeManualOverride, isNull);
      expect(
        find.widgetWithText(SwitchListTile, l10n.ramadanModeManualToggle),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/screens/ramadan_settings_screen_test.dart | tail -10`
Expected: FAIL to compile — `RamadanSettingsScreen` doesn't exist yet.

- [ ] **Step 5: Create the screen**

Create `lib/features/settings/presentation/screens/ramadan_settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// Ramadan mode configuration: auto-detect toggle plus a manual override
/// shown only while auto-detect is off (`docs/superpowers/specs/
/// 02-delightful/01-ramadan-mode-design.md`).
class RamadanSettingsScreen extends ConsumerWidget {
  /// Creates the Ramadan mode settings screen.
  const RamadanSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider).value;
    if (settings == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.ramadanModeSettingsTitle)),
      );
    }
    final repo = ref.read(settingsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ramadanModeSettingsTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.ramadanModeSettingsSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.ramadanModeAutoDetectToggle),
            value: settings.ramadanAutoDetectEnabled,
            onChanged: (enabled) async {
              await repo.updateRamadanAutoDetectEnabled(enabled: enabled);
              // Turning auto-detect back on clears any pinned manual
              // override — the two controls never fight each other.
              if (enabled) {
                await repo.updateRamadanModeManualOverride(null);
              }
            },
          ),
          if (!settings.ramadanAutoDetectEnabled)
            SwitchListTile(
              title: Text(l10n.ramadanModeManualToggle),
              value: settings.ramadanModeManualOverride ?? false,
              onChanged: (enabled) =>
                  repo.updateRamadanModeManualOverride(enabled),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Wire the route**

In `lib/core/router/app_router.dart`, add the import (alongside the
existing `quiet_hours_screen.dart` import):

```dart
import 'package:habit_tracker/features/settings/presentation/screens/ramadan_settings_screen.dart';
```

Add a new route constant after `settingsQuietHours`:

```dart
  /// Ramadan mode settings screen.
  static const String settingsRamadan = '/settings/ramadan';
```

Add the route itself right after the `quiet-hours` `GoRoute` inside the
settings branch:

```dart
                  GoRoute(
                    path: 'quiet-hours',
                    builder: (context, state) => const QuietHoursScreen(),
                  ),
                  GoRoute(
                    path: 'ramadan',
                    builder: (context, state) => const RamadanSettingsScreen(),
                  ),
```

- [ ] **Step 7: Add the settings-home nav entry**

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
          ListTile(
            leading: const Icon(Icons.nightlight_round),
            title: Text(l10n.settingsRamadanMode),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/ramadan'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSecurity),
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/screens/ramadan_settings_screen_test.dart | tail -10`
Expected: `+1: All tests passed!`

- [ ] **Step 9: Analyze and format**

Run: `flutter analyze lib/features/settings/presentation/screens/ramadan_settings_screen.dart lib/core/router/app_router.dart lib/features/settings/presentation/screens/settings_home_screen.dart | tail -10`
Run: `dart format lib/features/settings/presentation/screens/ramadan_settings_screen.dart lib/core/router/app_router.dart lib/features/settings/presentation/screens/settings_home_screen.dart`
Expected: no analyzer issues.

- [ ] **Step 10: Commit**

```bash
git add lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  lib/features/settings/presentation/screens/ramadan_settings_screen.dart \
  lib/core/router/app_router.dart \
  lib/features/settings/presentation/screens/settings_home_screen.dart \
  test/features/settings/presentation/screens/ramadan_settings_screen_test.dart
git commit -m "feat(settings): add the Ramadan mode settings screen"
```

---

### Task 4: Water — fasting-aware reminder window

**Files:**
- Modify: `lib/features/water/water_module.dart:1-171`
- Modify: `lib/core/modules/module_registry.dart`
- Test: `test/features/water/water_module_test.dart`

**Interfaces:**
- Consumes: `resolveRamadanModeActive`/`isRamadan` (Task 1),
  `AppSettings.ramadanModeManualOverride`/`ramadanAutoDetectEnabled`
  (Task 2), `PrayerRepository.getSettings()`, `resolveLocation()`,
  `calculatePrayerTimes()` (all pre-existing Prayer code).
- Produces: `WaterModule(repository, {SettingsRepository?
  settingsRepository, PrayerRepository? prayerRepository})` — the two new
  named params are consumed only by `module_registry.dart` in this task;
  no later task in this plan depends on them further.

- [ ] **Step 1: Write the failing test**

In `test/features/water/water_module_test.dart`, add these imports
alongside the existing ones:

```dart
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_times.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
```

(`local_day.dart` is already imported in this file for `localDayKey` —
adjust rather than duplicate if your editor flags it; the rest are new.)

Add two fakes right after the existing `_FakeWaterRepository` class:

```dart
class _FakePrayerRepository extends Fake implements PrayerRepository {
  _FakePrayerRepository(this._settings);
  final PrayerSettings _settings;

  @override
  Future<PrayerSettings> getSettings() async => _settings;
}

class _FakeSettingsRepository extends Fake implements SettingsRepository {
  _FakeSettingsRepository(this._settings);
  final AppSettings _settings;

  @override
  Stream<AppSettings> watchSettings() => Stream.value(_settings);
}
```

Add a settings-fixture helper right after the existing `_settings(...)`
helper:

```dart
AppSettings _appSettings({
  bool? ramadanModeManualOverride,
  bool ramadanAutoDetectEnabled = true,
}) => AppSettings(
  locale: AppLocale.en,
  themeMode: AppThemeMode.system,
  waterUnit: WaterUnit.ml,
  pinEnabled: false,
  pinLockTimeoutSeconds: 0,
  biometricEnabled: true,
  screenPrivacyEnabled: false,
  quietHoursEnabled: false,
  quietHoursStart: const LocalTime(22, 0),
  quietHoursEnd: const LocalTime(7, 0),
  ramadanModeManualOverride: ramadanModeManualOverride,
  ramadanAutoDetectEnabled: ramadanAutoDetectEnabled,
);

const _dhakaPrayerSettings = PrayerSettings(
  id: 'singleton',
  calculationMethod: CalculationMethod.karachi,
  asrMethod: AsrMethod.hanafi,
  locationMode: LocationMode.manual,
  manualLatitude: 23.8103,
  manualLongitude: 90.4125,
  manualTimezone: 'Asia/Dhaka',
);
```

Add three new tests inside `main()`, after the existing
`'onQuickAction logs a quick entry...'` test:

```dart
  test(
    'pendingNotifications only produces slots outside that day\'s Fajr-to-'
    'Maghrib fasting window when Ramadan mode is manually forced on',
    () async {
      ensureTimeZonesInitialized();
      final waterSettings = _settings(reminderEnabled: true).copyWith(
        reminderWindowStart: const LocalTime(0, 0),
        reminderWindowEnd: const LocalTime(23, 59),
      );
      final module = WaterModule(
        _FakeWaterRepository(waterSettings),
        settingsRepository: _FakeSettingsRepository(
          _appSettings(ramadanModeManualOverride: true),
        ),
        prayerRepository: _FakePrayerRepository(_dhakaPrayerSettings),
      );

      final now = DateTime.utc(2026, 3, 15, 3);
      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(notifications, isNotEmpty);

        for (final n in notifications) {
          final day = localDayKey(n.scheduledAt);
          final times = calculatePrayerTimes(
            date: day,
            latitude: _dhakaPrayerSettings.manualLatitude!,
            longitude: _dhakaPrayerSettings.manualLongitude!,
            ianaTimezone: _dhakaPrayerSettings.manualTimezone!,
            method: _dhakaPrayerSettings.calculationMethod,
            asrMethod: _dhakaPrayerSettings.asrMethod,
          );
          final fajrLocal = times.fajr.toLocal();
          final maghribLocal = times.maghrib.toLocal();
          final fajrOnDay = DateTime(
            day.year,
            day.month,
            day.day,
            fajrLocal.hour,
            fajrLocal.minute,
          );
          final maghribOnDay = DateTime(
            day.year,
            day.month,
            day.day,
            maghribLocal.hour,
            maghribLocal.minute,
          );
          final beforeFajr = n.scheduledAt.isBefore(fajrOnDay);
          final afterMaghrib = !n.scheduledAt.isBefore(maghribOnDay);
          expect(
            beforeFajr || afterMaghrib,
            isTrue,
            reason: 'slot at ${n.scheduledAt} falls inside the fast on $day '
                '(Fajr $fajrOnDay, Maghrib $maghribOnDay)',
          );
        }
      });
    },
  );

  test(
    'pendingNotifications is unchanged when the optional deps are supplied '
    'but Ramadan mode resolves to off',
    () async {
      final waterSettings = _settings(reminderEnabled: true);
      final now = DateTime(2026, 6, 1, 9);

      final baseline = WaterModule(_FakeWaterRepository(waterSettings));
      final withDeps = WaterModule(
        _FakeWaterRepository(waterSettings),
        settingsRepository: _FakeSettingsRepository(
          _appSettings(
            ramadanModeManualOverride: null,
            ramadanAutoDetectEnabled: false,
          ),
        ),
        prayerRepository: _FakePrayerRepository(_dhakaPrayerSettings),
      );

      await withClock(Clock.fixed(now), () async {
        final a = await baseline.pendingNotifications();
        final b = await withDeps.pendingNotifications();
        expect(
          b.map((n) => n.scheduledAt),
          a.map((n) => n.scheduledAt),
        );
      });
    },
  );

  test(
    'pendingNotifications falls back to the plain window when Ramadan is '
    'active but location resolution fails',
    () async {
      final waterSettings = _settings(reminderEnabled: true);
      final now = DateTime(2026, 3, 15, 9);
      // `LocationMode.auto` in a `flutter test` environment has no
      // `geolocator` platform channel registered — `resolveLocation`'s
      // own try/catch turns that into a clean `Result.failure`, which is
      // exactly the "no behavior change" fallback this test exercises.
      const autoPrayerSettings = PrayerSettings(
        id: 'singleton',
        calculationMethod: CalculationMethod.karachi,
        asrMethod: AsrMethod.hanafi,
        locationMode: LocationMode.auto,
      );

      final baseline = WaterModule(_FakeWaterRepository(waterSettings));
      final withDeps = WaterModule(
        _FakeWaterRepository(waterSettings),
        settingsRepository: _FakeSettingsRepository(
          _appSettings(ramadanModeManualOverride: true),
        ),
        prayerRepository: _FakePrayerRepository(autoPrayerSettings),
      );

      await withClock(Clock.fixed(now), () async {
        final a = await baseline.pendingNotifications();
        final b = await withDeps.pendingNotifications();
        expect(b.map((n) => n.scheduledAt), a.map((n) => n.scheduledAt));
      });
    },
  );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/water/water_module_test.dart | tail -10`
Expected: FAIL to compile — `WaterModule`'s constructor doesn't accept
`settingsRepository`/`prayerRepository` yet.

- [ ] **Step 3: Write the implementation**

In `lib/features/water/water_module.dart`, add imports:

```dart
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/hijri_date.dart';
import 'package:habit_tracker/features/prayer/data/location_resolver.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_times.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
```

Change the constructor and fields from:

```dart
class WaterModule implements HabitModule {
  /// Creates the module backed by [_repository].
  const WaterModule(this._repository);

  final WaterRepository _repository;
```

to:

```dart
class WaterModule implements HabitModule {
  /// Creates the module backed by [_repository]. [settingsRepository] and
  /// [prayerRepository] are optional, additive dependencies powering
  /// Ramadan-mode fasting-aware reminder windows
  /// (`docs/superpowers/specs/02-delightful/01-ramadan-mode-design.md`) —
  /// omitted (as every pre-existing call site/test still does), Water
  /// behaves exactly as before and Ramadan mode never activates.
  const WaterModule(
    this._repository, {
    SettingsRepository? settingsRepository,
    PrayerRepository? prayerRepository,
  }) : _settingsRepository = settingsRepository,
       _prayerRepository = prayerRepository;

  final WaterRepository _repository;
  final SettingsRepository? _settingsRepository;
  final PrayerRepository? _prayerRepository;
```

Replace the entire `pendingNotifications` method body (from `@override`
through its closing `}`, right before `@override\n  Future<void>
onNotificationAction`) with:

```dart
  @override
  Future<List<PendingNotification>> pendingNotifications() async {
    final settings = await _repository.watchSettings().first;
    if (!settings.reminderEnabled) return [];

    final appSettings = _settingsRepository == null
        ? null
        : await _settingsRepository.watchSettings().first;

    final now = clock.now();
    final notifications = <PendingNotification>[];
    for (var dayOffset = 0; dayOffset <= _lookaheadDays; dayOffset++) {
      final day = localDayKey(now).addDays(dayOffset);
      final ramadanActive = appSettings != null &&
          _prayerRepository != null &&
          resolveRamadanModeActive(
            manualOverride: appSettings.ramadanModeManualOverride,
            autoDetectEnabled: appSettings.ramadanAutoDetectEnabled,
            today: day,
          );
      final windows = ramadanActive
          ? await _fastingAwareWindows(day, settings)
          : [_weekdayWindow(day, settings)];
      for (final window in windows) {
        var slot = day.toDateTimeUtc().toLocal().add(
          Duration(hours: window.start.hour, minutes: window.start.minute),
        );
        final windowEnd = day.toDateTimeUtc().toLocal().add(
          Duration(hours: window.end.hour, minutes: window.end.minute),
        );
        while (slot.isBefore(windowEnd) || slot.isAtSameMomentAs(windowEnd)) {
          if (slot.isAfter(now)) {
            notifications.add(
              PendingNotification(
                id:
                    'water_reminder_'
                    '${day.year}${day.month.toString().padLeft(2, '0')}'
                    '${day.day.toString().padLeft(2, '0')}_'
                    '${slot.hour}_${slot.minute}',
                scheduledAt: slot,
                title: 'Time to drink water',
                body: 'Keep your water goal on track.',
                sourceType: 'water_reminder',
                deepLinkRoute: '/water',
                quietHoursSuppressible: true,
              ),
            );
          }
          slot = slot.add(Duration(minutes: settings.reminderIntervalMinutes));
        }
      }
    }
    return notifications;
  }

  ({LocalTime start, LocalTime end}) _weekdayWindow(
    LocalDate day,
    WaterSettings settings,
  ) {
    final weekday = day.toDateTimeUtc().weekday;
    final override = settings.reminderWindowOverrides[weekday];
    return (
      start: override?.start ?? settings.reminderWindowStart,
      end: override?.end ?? settings.reminderWindowEnd,
    );
  }

  /// The non-fasting sub-windows within [day]: before that day's Fajr
  /// (the tail of the previous night's eating hours) and after that
  /// day's Maghrib (that night's Iftar onward), each clipped to the
  /// user's own configured window (`01-ramadan-mode-design.md`'s Design
  /// §3: "clips the window to whichever is narrower ... so a user who
  /// only wants morning reminders anyway isn't suddenly nudged at 9pm
  /// right after Iftar"). Falls back to the single plain weekday window,
  /// unclipped, if location resolution fails — Ramadan mode degrades to
  /// "no behavior change" rather than throwing.
  Future<List<({LocalTime start, LocalTime end})>> _fastingAwareWindows(
    LocalDate day,
    WaterSettings settings,
  ) async {
    final userWindow = _weekdayWindow(day, settings);
    final prayerSettings = await _prayerRepository!.getSettings();
    final locationResult = await resolveLocation(prayerSettings);
    if (locationResult case Failure()) return [userWindow];
    final location = (locationResult as Success<ResolvedLocation>).value;
    final times = calculatePrayerTimes(
      date: day,
      latitude: location.latitude,
      longitude: location.longitude,
      ianaTimezone: location.ianaTimezone,
      method: prayerSettings.calculationMethod,
      asrMethod: prayerSettings.asrMethod,
    );
    final fajrLocal = _asLocalTime(times.fajr);
    final maghribLocal = _asLocalTime(times.maghrib);
    final windows = <({LocalTime start, LocalTime end})>[];
    final morning = _clip(
      (start: const LocalTime(0, 0), end: fajrLocal),
      userWindow,
    );
    if (morning != null) windows.add(morning);
    final evening = _clip(
      (start: maghribLocal, end: const LocalTime(23, 59)),
      userWindow,
    );
    if (evening != null) windows.add(evening);
    return windows;
  }

  LocalTime _asLocalTime(DateTime utcInstant) {
    final local = utcInstant.toLocal();
    return LocalTime(local.hour, local.minute);
  }

  /// Intersects [candidate] with [userWindow], or `null` if the
  /// intersection is empty (e.g. the user's own configured window sits
  /// entirely inside daylight/fasting hours — correctly zero reminders
  /// that day, not a bug).
  ({LocalTime start, LocalTime end})? _clip(
    ({LocalTime start, LocalTime end}) candidate,
    ({LocalTime start, LocalTime end}) userWindow,
  ) {
    final start = candidate.start.compareTo(userWindow.start) >= 0
        ? candidate.start
        : userWindow.start;
    final end = candidate.end.compareTo(userWindow.end) <= 0
        ? candidate.end
        : userWindow.end;
    if (start.compareTo(end) >= 0) return null;
    return (start: start, end: end);
  }
```

- [ ] **Step 4: Wire `module_registry.dart`**

In `lib/core/modules/module_registry.dart`, add the import:

```dart
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
```

Change `buildHabitModules` from:

```dart
List<HabitModule> buildHabitModules(AppDatabase db) {
  return [
    MedicineModule(MedicineRepositoryImpl(db)),
    WaterModule(WaterRepositoryImpl(db)),
    PrayerModule(PrayerRepositoryImpl(db)),
  ];
}
```

to:

```dart
List<HabitModule> buildHabitModules(AppDatabase db) {
  final settingsRepository = SettingsRepositoryImpl(db);
  return [
    MedicineModule(MedicineRepositoryImpl(db)),
    WaterModule(
      WaterRepositoryImpl(db),
      settingsRepository: settingsRepository,
      prayerRepository: PrayerRepositoryImpl(db),
    ),
    PrayerModule(PrayerRepositoryImpl(db)),
  ];
}
```

(`PrayerModule`'s own line is deliberately left unchanged in this task —
it doesn't yet accept a `settingsRepository:` argument. Task 5 both adds
that constructor parameter to `PrayerModule` and updates this exact line
to pass `settingsRepository: settingsRepository`, in its own step, so
the module list still compiles at every task boundary. The local
variable `settingsRepository` declared above is unused by `PrayerModule`
until then, which is fine — it's already used by `WaterModule` on the
line above.)

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/water/water_module_test.dart | tail -10`
Expected: `+N: All tests passed!` (every pre-existing test plus the 3 new
ones).

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/water/water_module.dart lib/core/modules/module_registry.dart | tail -10`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/water/water_module.dart \
  lib/core/modules/module_registry.dart \
  test/features/water/water_module_test.dart
git commit -m "feat(water): shift reminder windows outside Ramadan fasting hours"
```

---

### Task 5: Sehri/Iftar countdown and Fajr/Maghrib framing

**Files:**
- Create: `lib/core/utils/countdown_format.dart`
- Test: `test/core/utils/countdown_format_test.dart`
- Create: `lib/features/prayer/presentation/ramadan_prayer_framing.dart`
- Test: `test/features/prayer/presentation/ramadan_prayer_framing_test.dart`
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Modify: `lib/features/prayer/prayer_module.dart`
- Modify: `lib/core/modules/module_registry.dart`
- Test: `test/features/prayer/prayer_module_test.dart`

**Interfaces:**
- Produces: `String formatCountdown(Duration remaining)`,
  `enum RamadanPrayerFraming { sehri, iftar }`,
  `RamadanPrayerFraming? ramadanFramingFor(PrayerName prayerName)` —
  consumed by `PrayerModule.pendingNotifications()`/`nextUpcoming` in this
  same task.
- Consumes: `resolveRamadanModeActive` (Task 1),
  `AppSettings.ramadanModeManualOverride`/`ramadanAutoDetectEnabled`
  (Task 2).

- [ ] **Step 1: Write the failing `formatCountdown` test**

Create `test/core/utils/countdown_format_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/countdown_format.dart';

void main() {
  test('under an hour formats as "N min"', () {
    expect(formatCountdown(const Duration(minutes: 42)), '42 min');
    expect(formatCountdown(const Duration(minutes: 1)), '1 min');
  });

  test('an hour or more formats as "Hh Mm"', () {
    expect(formatCountdown(const Duration(hours: 2, minutes: 15)), '2h 15m');
    expect(formatCountdown(const Duration(hours: 1)), '1h 0m');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/countdown_format_test.dart | tail -10`
Expected: FAIL — `lib/core/utils/countdown_format.dart` doesn't exist yet.

- [ ] **Step 3: Implement `formatCountdown`**

Create `lib/core/utils/countdown_format.dart`:

```dart
/// Formats [remaining] as a short countdown string ("42 min" / "2h 15m"),
/// for the Sehri/Iftar countdown chip (`docs/superpowers/specs/
/// 02-delightful/01-ramadan-mode-design.md`). Callers must only pass a
/// positive [remaining] — this doesn't special-case zero/negative
/// durations, since every call site already guards on
/// `!remaining.isNegative` before calling.
String formatCountdown(Duration remaining) {
  final totalMinutes = remaining.inMinutes;
  if (totalMinutes < 60) return '$totalMinutes min';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '${hours}h ${minutes}m';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/countdown_format_test.dart | tail -10`
Expected: `+2: All tests passed!`

- [ ] **Step 5: Write the failing `ramadanFramingFor` test**

Create `test/features/prayer/presentation/ramadan_prayer_framing_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/ramadan_prayer_framing.dart';

void main() {
  test('Fajr maps to sehri framing', () {
    expect(ramadanFramingFor(PrayerName.fajr), RamadanPrayerFraming.sehri);
  });

  test('Maghrib maps to iftar framing', () {
    expect(ramadanFramingFor(PrayerName.maghrib), RamadanPrayerFraming.iftar);
  });

  test('every other prayer has no Ramadan framing', () {
    expect(ramadanFramingFor(PrayerName.dhuhr), isNull);
    expect(ramadanFramingFor(PrayerName.asr), isNull);
    expect(ramadanFramingFor(PrayerName.isha), isNull);
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/features/prayer/presentation/ramadan_prayer_framing_test.dart | tail -10`
Expected: FAIL to compile — the file doesn't exist yet.

- [ ] **Step 7: Implement `ramadanFramingFor`**

Create `lib/features/prayer/presentation/ramadan_prayer_framing.dart`:

```dart
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';

/// Ramadan-specific display framing for a prayer name (`docs/superpowers/
/// specs/02-delightful/01-ramadan-mode-design.md`'s Design §5) — pure, so
/// `PrayerModule.nextUpcoming`/`pendingNotifications` can both call it
/// without needing a `BuildContext`.
enum RamadanPrayerFraming {
  /// Fajr — "Sehri ends" framing.
  sehri,

  /// Maghrib — "Iftar" framing.
  iftar,
}

/// The Ramadan framing for [prayerName], or `null` for every prayer
/// besides Fajr/Maghrib (no framing change).
RamadanPrayerFraming? ramadanFramingFor(PrayerName prayerName) =>
    switch (prayerName) {
      PrayerName.fajr => RamadanPrayerFraming.sehri,
      PrayerName.maghrib => RamadanPrayerFraming.iftar,
      PrayerName.dhuhr || PrayerName.asr || PrayerName.isha => null,
    };
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/features/prayer/presentation/ramadan_prayer_framing_test.dart | tail -10`
Expected: `+3: All tests passed!`

- [ ] **Step 9: Add the countdown/label l10n keys**

In `lib/core/l10n/app_en.arb`, insert right before the final closing `}`
(after Task 3's `"ramadanModeManualToggle"` block, which is now the last
key):

```json
  "ramadanModeManualToggle": "Ramadan mode",
  "@ramadanModeManualToggle": {
    "description": "Manual override toggle, shown only while auto-detect is off."
  },
  "sehriEndsCountdown": "Sehri ends in {duration}",
  "@sehriEndsCountdown": {
    "description": "Dashboard/Prayer countdown label shown before Fajr during Ramadan.",
    "placeholders": {
      "duration": {"type": "String"}
    }
  },
  "iftarCountdown": "Iftar in {duration}",
  "@iftarCountdown": {
    "description": "Dashboard/Prayer countdown label shown before Maghrib during Ramadan.",
    "placeholders": {
      "duration": {"type": "String"}
    }
  },
  "sehriEndsLabel": "Sehri ends",
  "@sehriEndsLabel": {
    "description": "Fallback label once Fajr has just passed and a countdown is no longer meaningful."
  },
  "iftarLabel": "Iftar",
  "@iftarLabel": {
    "description": "Fallback label once Maghrib has just passed and a countdown is no longer meaningful."
  }
}
```

In `lib/core/l10n/app_bn.arb`, change the last line from:

```json
  "ramadanModeManualToggle": "রমজান মোড"
}
```

to:

```json
  "ramadanModeManualToggle": "রমজান মোড",
  "sehriEndsCountdown": "সেহরি শেষ হবে {duration} পরে",
  "iftarCountdown": "ইফতার {duration} পরে",
  "sehriEndsLabel": "সেহরি শেষ",
  "iftarLabel": "ইফতার"
}
```

Run: `flutter gen-l10n | tail -10`
Expected: no errors.

- [ ] **Step 10: Write the failing `pendingNotifications` framing test**

In `test/features/prayer/prayer_module_test.dart`, add these imports
alongside the existing ones:

```dart
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
```

Add a `_MockSettingsRepository` class after `_MockPrayerRepository`:

```dart
class _MockSettingsRepository extends Mock implements SettingsRepository {}
```

Add a new test inside `main()`, after the existing
`'pendingNotifications includes a pre-reminder when preReminderEnabled'`
test:

```dart
  test(
    'pendingNotifications frames Fajr as "Sehri ends" and Maghrib as '
    '"Iftar" when Ramadan mode is manually forced on via the optional '
    'settings dependency',
    () async {
      final now = DateTime.utc(2026, 3, 15, 3);
      final fajr = PrayerRecord(
        id: 'r-fajr',
        prayerDate: const LocalDate(2026, 3, 15),
        prayerName: PrayerName.fajr,
        scheduledFor: DateTime.utc(2026, 3, 15, 5),
        storedStatus: PrayerStatus.upcoming,
      );
      final maghrib = PrayerRecord(
        id: 'r-maghrib',
        prayerDate: const LocalDate(2026, 3, 15),
        prayerName: PrayerName.maghrib,
        scheduledFor: DateTime.utc(2026, 3, 15, 12),
        storedStatus: PrayerStatus.upcoming,
      );

      final settingsRepo = _MockSettingsRepository();
      when(() => settingsRepo.watchSettings()).thenAnswer(
        (_) => Stream.value(
          const AppSettings(
            locale: AppLocale.en,
            themeMode: AppThemeMode.system,
            waterUnit: WaterUnit.ml,
            pinEnabled: false,
            pinLockTimeoutSeconds: 0,
            biometricEnabled: true,
            screenPrivacyEnabled: false,
            quietHoursEnabled: false,
            quietHoursStart: LocalTime(22, 0),
            quietHoursEnd: LocalTime(7, 0),
            ramadanModeManualOverride: true,
          ),
        ),
      );
      final ramadanModule = PrayerModule(repo, settingsRepository: settingsRepo);

      when(() => repo.watchSettings()).thenAnswer((_) => Stream.value(settings));
      when(() => repo.sweepMissedPrayers(any(), any())).thenAnswer((_) async {});
      when(() => repo.materializeRecords(any(), any())).thenAnswer((_) async {});
      when(
        () => repo.recordsInRange(any(), any()),
      ).thenAnswer((_) async => [fajr, maghrib]);

      await withClock(Clock.fixed(now), () async {
        final notifications = await ramadanModule.pendingNotifications();
        final fajrNotification = notifications.firstWhere(
          (n) => n.id == 'r-fajr',
        );
        final maghribNotification = notifications.firstWhere(
          (n) => n.id == 'r-maghrib',
        );
        expect(fajrNotification.title, 'Sehri ends');
        expect(maghribNotification.title, 'Iftar');
      });
    },
  );
```

- [ ] **Step 11: Run test to verify it fails**

Run: `flutter test test/features/prayer/prayer_module_test.dart | tail -10`
Expected: FAIL to compile — `PrayerModule`'s constructor doesn't accept
`settingsRepository` yet.

- [ ] **Step 12: Wire `PrayerModule`**

In `lib/features/prayer/prayer_module.dart`, add imports:

```dart
import 'package:habit_tracker/core/utils/countdown_format.dart';
import 'package:habit_tracker/core/utils/hijri_date.dart';
import 'package:habit_tracker/features/prayer/presentation/ramadan_prayer_framing.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
```

Change the constructor and fields from:

```dart
class PrayerModule implements HabitModule {
  /// Creates the module backed by [_repository].
  const PrayerModule(this._repository);

  final PrayerRepository _repository;
```

to:

```dart
class PrayerModule implements HabitModule {
  /// Creates the module backed by [_repository]. [settingsRepository] is
  /// an optional, additive dependency used only to relabel Fajr/Maghrib
  /// as Sehri/Iftar during Ramadan (`docs/superpowers/specs/
  /// 02-delightful/01-ramadan-mode-design.md`) — omitted (as every
  /// pre-existing call site/test still does), that relabeling never
  /// happens and everything else is unchanged.
  const PrayerModule(this._repository, {SettingsRepository? settingsRepository})
    : _settingsRepository = settingsRepository;

  final PrayerRepository _repository;
  final SettingsRepository? _settingsRepository;
```

Replace the body of `pendingNotifications` (from `final windowEnd =` down
to the closing of the `for (final record in records) { ... }` loop's
label-computation, right before `notifications.add(`) — change:

```dart
    final windowEnd = localDayKey(now).addDays(_lookaheadDays);
    final records = await _repository.recordsInRange(
      localDayKey(now),
      windowEnd,
    );
    final notifications = <PendingNotification>[];
    for (final record in records) {
      if (record.storedStatus != PrayerStatus.upcoming) continue;
      if (!record.scheduledFor.isAfter(now)) continue;
      final label =
          isJumuahDisplay(
            prayerName: record.prayerName,
            date: record.prayerDate,
            observesJumuah: settings.observesJumuah,
          )
          ? "Jumu'ah"
          : _titleCase(record.prayerName.name);
      notifications.add(
        PendingNotification(
          id: record.id,
          scheduledAt: record.scheduledFor,
          title: label,
          body: "It's time for $label prayer",
          sourceType: 'prayer_record',
          deepLinkRoute: '/prayer/record/${record.id}',
          quietHoursSuppressible: false,
        ),
      );
```

to:

```dart
    final windowEnd = localDayKey(now).addDays(_lookaheadDays);
    final records = await _repository.recordsInRange(
      localDayKey(now),
      windowEnd,
    );
    final appSettings = _settingsRepository == null
        ? null
        : await _settingsRepository.watchSettings().first;
    final notifications = <PendingNotification>[];
    for (final record in records) {
      if (record.storedStatus != PrayerStatus.upcoming) continue;
      if (!record.scheduledFor.isAfter(now)) continue;
      final isJumuah = isJumuahDisplay(
        prayerName: record.prayerName,
        date: record.prayerDate,
        observesJumuah: settings.observesJumuah,
      );
      final ramadanActive = !isJumuah &&
          appSettings != null &&
          resolveRamadanModeActive(
            manualOverride: appSettings.ramadanModeManualOverride,
            autoDetectEnabled: appSettings.ramadanAutoDetectEnabled,
            today: record.prayerDate,
          );
      final framing = ramadanActive
          ? ramadanFramingFor(record.prayerName)
          : null;
      final label = isJumuah
          ? "Jumu'ah"
          : switch (framing) {
              RamadanPrayerFraming.sehri => 'Sehri ends',
              RamadanPrayerFraming.iftar => 'Iftar',
              null => _titleCase(record.prayerName.name),
            };
      final body = switch (framing) {
        RamadanPrayerFraming.sehri =>
          'Sehri ends now — finish eating and drinking',
        RamadanPrayerFraming.iftar => 'Time to break your fast',
        null => "It's time for $label prayer",
      };
      notifications.add(
        PendingNotification(
          id: record.id,
          scheduledAt: record.scheduledFor,
          title: label,
          body: body,
          sourceType: 'prayer_record',
          deepLinkRoute: '/prayer/record/${record.id}',
          quietHoursSuppressible: false,
        ),
      );
```

Change `nextUpcoming` from:

```dart
  @override
  Widget? nextUpcoming(WidgetRef ref) {
    final views = ref.watch(todaysPrayerViewsProvider);
    if (views == null) return null;
    PrayerRecordView? next;
    for (final view in views) {
      if (view.effectiveStatus == PrayerStatus.due ||
          view.effectiveStatus == PrayerStatus.upcoming) {
        next = view;
        break;
      }
    }
    if (next == null) return null;
    final label = next.showAsJumuah
        ? "Jumu'ah"
        : _titleCase(next.record.prayerName.name);
    return Builder(
      builder: (context) => Chip(
        avatar: const Icon(Icons.mosque, size: 16),
        label: Text(label),
      ),
    );
  }
```

to:

```dart
  @override
  Widget? nextUpcoming(WidgetRef ref) {
    final views = ref.watch(todaysPrayerViewsProvider);
    if (views == null) return null;
    PrayerRecordView? next;
    for (final view in views) {
      if (view.effectiveStatus == PrayerStatus.due ||
          view.effectiveStatus == PrayerStatus.upcoming) {
        next = view;
        break;
      }
    }
    if (next == null) return null;
    final appSettings = ref.watch(appSettingsProvider).value;
    final ramadanActive = !next.showAsJumuah &&
        appSettings != null &&
        resolveRamadanModeActive(
          manualOverride: appSettings.ramadanModeManualOverride,
          autoDetectEnabled: appSettings.ramadanAutoDetectEnabled,
          today: next.record.prayerDate,
        );
    final framing = ramadanActive
        ? ramadanFramingFor(next.record.prayerName)
        : null;
    final remaining = next.record.scheduledFor.difference(clock.now());
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final label = switch (framing) {
          null => next.showAsJumuah
              ? "Jumu'ah"
              : _titleCase(next.record.prayerName.name),
          RamadanPrayerFraming.sehri => remaining.isNegative
              ? l10n.sehriEndsLabel
              : l10n.sehriEndsCountdown(formatCountdown(remaining)),
          RamadanPrayerFraming.iftar => remaining.isNegative
              ? l10n.iftarLabel
              : l10n.iftarCountdown(formatCountdown(remaining)),
        };
        return Chip(
          avatar: const Icon(Icons.mosque, size: 16),
          label: Text(label),
        );
      },
    );
  }
```

In `lib/core/modules/module_registry.dart`, change the still-unwired line
(Task 4 deliberately left this one alone):

```dart
    PrayerModule(PrayerRepositoryImpl(db)),
```

to:

```dart
    PrayerModule(PrayerRepositoryImpl(db), settingsRepository: settingsRepository),
```

- [ ] **Step 13: Run test to verify it passes**

Run: `flutter test test/features/prayer/prayer_module_test.dart | tail -10`
Expected: `+N: All tests passed!` (every pre-existing test plus the new
one).

- [ ] **Step 14: Full sweep**

Run: `flutter analyze | tail -10`
Expected: `No issues found!`

Run: `flutter test | tail -10`
Expected: no failures beyond any pre-existing, already-documented ones.

- [ ] **Step 15: Commit**

```bash
git add lib/core/utils/countdown_format.dart \
  test/core/utils/countdown_format_test.dart \
  lib/features/prayer/presentation/ramadan_prayer_framing.dart \
  test/features/prayer/presentation/ramadan_prayer_framing_test.dart \
  lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  lib/features/prayer/prayer_module.dart \
  lib/core/modules/module_registry.dart \
  test/features/prayer/prayer_module_test.dart
git commit -m "feat(prayer): add the Sehri/Iftar countdown and Fajr/Maghrib framing"
```

---

## After all tasks

Per this repo's CLAUDE.md spec-implementation workflow: once every task
above is committed, open a PR for the spec with the design summary in the
description, then run a code review against the finished PR (comment →
fix → commit cycle, up to 5 rounds), then stop and wait for the user's
own review and merge.

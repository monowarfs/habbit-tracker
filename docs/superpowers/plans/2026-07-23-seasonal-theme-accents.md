# Seasonal Theme Accents (Pohela Boishakh) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Subtly swap the app's Material 3 `ColorScheme` seed color for a
curated red-and-white Pohela Boishakh accent on and around 14 April,
opt-out-able from Settings, per `docs/superpowers/specs/02-delightful/
12-seasonal-theme-accents-design.md`. **Eid detection does not ship in
this plan** — it's blocked on a Hijri-date source this app doesn't have
(shared, unsolved prerequisite with the separate Ramadan-mode item); the
`SeasonalOccasion.eid` code path is written but stays permanently
unreachable, documented as such, not faked with a guessed date range.

**Architecture:** `AppTheme.light`/`.dark` gain an optional `Color?
seasonalSeed` parameter (default `null`, so every existing call site's
behavior is unchanged) that overrides `_seedColor` inside `_build`. A new
pure `activeSeasonalOccasion(LocalDate)` returns `SeasonalOccasion
.poholaBoishakh` inside a fixed Gregorian window, or `null` otherwise —
never `.eid`. A new `seasonalAccentSeedProvider` combines that pure
function with `clock.now()` and one new opt-out `AppSettings.
seasonalAccentsEnabled` boolean (default `true`, schema v8), and
`main.dart` passes its value through to `AppTheme.light`/`.dark`.
`ModuleAccents`/`AppSemanticColors` are structurally untouched — neither
derives from `_seedColor`, so the seed swap can't affect them.

**Tech Stack:** Flutter/Riverpod (codegen), Drift (codegen), `clock`,
`gen_l10n`, `flutter_test`.

## Global Constraints

- **No new dependency for Pohela Boishakh** (pure Gregorian month/day
  check, no calendar-conversion library). **Eid detection is out of
  scope** — `pubspec.yaml` has no Hijri/lunar-calendar package
  (`adhan_dart` only computes prayer times, not Gregorian↔Hijri
  conversion); `SeasonalOccasion.eid` stays a documented, tested,
  permanently-unreachable no-op until that prerequisite lands elsewhere.
- **Schema-version coordination (read this before touching
  `app_database.dart`).** Two other specs in this same batch
  (`06-why-this-matters`, planned separately, and
  `11-personalized-dashboard-greeting-design.md`) also want to bump
  `schemaVersion` from 7 to 8. Task 1's own step below has you check the
  file's current state first — do not skip that check even if you
  "know" it's still 7.
- One boolean, all-or-nothing opt-out — no per-occasion granular toggle.
- `ModuleAccents`/`AppSemanticColors` (`lib/core/theme/app_theme.dart`)
  are not modified in any way that changes their values — a test in
  Task 3 asserts this directly.
- No new illustration/decorative assets — accent color only; doesn't
  interact with the separate adaptive-empty-state-illustrations item.
- New files: `lib/core/theme/seasonal_occasion.dart`
  (`SeasonalOccasion` + `activeSeasonalOccasion`), `lib/core/theme/
  seasonal_accent_provider.dart` (`seasonalAccentSeedProvider`); a
  `SeasonalAccent` class added directly to `app_theme.dart`, colocated
  with `ModuleAccents`.
- Modified files: `lib/core/theme/app_theme.dart` (`AppTheme.light`/
  `.dark`/`_build` gain the optional seed override),
  `lib/features/settings/domain/entities/app_settings.dart`,
  `lib/core/database/tables/app_settings_table.dart`,
  `lib/core/database/app_database.dart` (migration),
  `lib/features/settings/domain/repositories/settings_repository.dart`/
  `lib/features/settings/data/repositories/settings_repository_impl.dart`
  (`updateSeasonalAccentsEnabled`),
  `lib/features/settings/presentation/screens/theme_settings_screen.dart`
  (new toggle), `lib/main.dart` (watch the new provider, pass
  `seasonalSeed` through).
- Per this repo's CLAUDE.md spec-implementation workflow: one commit per
  task, run only that task's own test file (never the full `flutter
  test` suite mid-task), pipe `build_runner`/`test`/`gen-l10n` output
  through `| tail -10`.

---

### Task 1: Data layer — `seasonalAccentsEnabled` opt-out

**Files:**
- Modify: `lib/core/database/tables/app_settings_table.dart`
- Modify: `lib/core/database/app_database.dart:53-110`
- Modify: `lib/features/settings/domain/entities/app_settings.dart:45-58`
- Modify: `lib/features/settings/domain/repositories/settings_repository.dart`
- Modify: `lib/features/settings/data/repositories/settings_repository_impl.dart`
- Test: `test/features/settings/data/repositories/settings_repository_impl_test.dart`

**Interfaces:**
- Produces: `AppSettings.seasonalAccentsEnabled` (`bool`, default
  `true`), `SettingsRepository.updateSeasonalAccentsEnabled({required
  bool enabled})` — consumed by Task 4's provider and Task 5's toggle UI.

- [ ] **Step 1: Write the failing repository test**

Add to `test/features/settings/data/repositories/
settings_repository_impl_test.dart`, right after the existing
`expect(firstRead.screenPrivacyEnabled, isFalse);` line (or right after
Task 1 of `2026-07-23-personalized-dashboard-greeting.md`'s own
`expect(firstRead.displayName, isNull);` line, if that plan landed
first — either way, add this as one more assertion in the same
`firstRead` block):

```dart
    expect(firstRead.seasonalAccentsEnabled, isTrue);
```

Right after the existing `final privacyResult = await
repo1.updateScreenPrivacyEnabled(enabled: true);` block (before `await
db1.close();`), add:

```dart
    final seasonalResult = await repo1.updateSeasonalAccentsEnabled(
      enabled: false,
    );
    expect(seasonalResult, isA<Success<void>>());
```

Right after the existing `expect(afterRestart.screenPrivacyEnabled,
isTrue);`, add:

```dart
    expect(afterRestart.seasonalAccentsEnabled, isFalse);
```

- [ ] **Step 2: Run it, confirm it fails to compile**

Run: `flutter test test/features/settings/data/repositories/settings_repository_impl_test.dart | tail -10`
Expected: compile error — `seasonalAccentsEnabled`/
`updateSeasonalAccentsEnabled` don't exist yet.

- [ ] **Step 3: Add the DB column**

In `lib/core/database/tables/app_settings_table.dart`, add after the
`lastSeenAppVersion` column (before `createdAt`):

```dart
  /// Opt-out for the seasonal palette shift (Pohela Boishakh; Eid is not
  /// yet detectable, `core/theme/seasonal_occasion.dart`) — default
  /// `true` (opt-in by default, matching the feature's own "festive but
  /// tasteful" framing), flip off for users who never want the app's
  /// look to change (`docs/superpowers/specs/02-delightful/
  /// 12-seasonal-theme-accents-design.md`).
  BoolColumn get seasonalAccentsEnabled =>
      boolean().withDefault(const Constant(true))();
```

- [ ] **Step 4: Check the current `schemaVersion` and apply the migration**

Two other specs in this batch (`06-why-this-matters`,
`11-personalized-dashboard-greeting-design.md`) also target schema v8.
Check which state the file is actually in before editing:

Run: `grep -n "int get schemaVersion" lib/core/database/app_database.dart`

- **If it prints `int get schemaVersion => 7;`** (nothing else has
  landed yet): bump it to 8 and add a new `if (from < 8) { ... }` block
  containing this column's `addColumn` call. Change:

  ```dart
    @override
    int get schemaVersion => 7;
  ```

  to:

  ```dart
    @override
    int get schemaVersion => 8;
  ```

  And change the `onUpgrade` body's trailing seam:

  ```dart
        if (from < 7) {
          // Per-weekday water reminder window overrides.
          await m.addColumn(
            waterSettingsTable,
            waterSettingsTable.reminderWindowOverrides,
          );
        }
        // Seam: when schemaVersion increments further, add
        // `if (from < N) ...` blocks here — no other file needs to
        // change for a schema migration.
      },
    );
  ```

  to:

  ```dart
        if (from < 7) {
          // Per-weekday water reminder window overrides.
          await m.addColumn(
            waterSettingsTable,
            waterSettingsTable.reminderWindowOverrides,
          );
        }
        if (from < 8) {
          // Seasonal theme accent opt-out.
          await m.addColumn(
            appSettingsTable,
            appSettingsTable.seasonalAccentsEnabled,
          );
        }
        // Seam: when schemaVersion increments further, add
        // `if (from < N) ...` blocks here — no other file needs to
        // change for a schema migration.
      },
    );
  ```

- **If it prints `int get schemaVersion => 8;`** (one of the other two
  specs landed first): do **not** bump the version again. Instead, open
  the `onUpgrade` body's existing `if (from < 8) { ... }` block and add
  this column's `addColumn` call as an additional line inside it, e.g.
  if `11-personalized-dashboard-greeting-design.md` landed first, the
  block currently reads:

  ```dart
        if (from < 8) {
          // Dashboard greeting's optional display name.
          await m.addColumn(appSettingsTable, appSettingsTable.displayName);
        }
  ```

  change it to:

  ```dart
        if (from < 8) {
          // Dashboard greeting's optional display name.
          await m.addColumn(appSettingsTable, appSettingsTable.displayName);
          // Seasonal theme accent opt-out.
          await m.addColumn(
            appSettingsTable,
            appSettingsTable.seasonalAccentsEnabled,
          );
        }
  ```

  (If `06-why-this-matters` landed first instead, the block will contain
  whatever column that spec added — the principle is the same: add your
  `addColumn` call as one more line inside the existing `if (from < 8)`
  block, do not open a second one and do not bump to 9.)

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

to (this appends after `quietHoursEnd`; if
`11-personalized-dashboard-greeting-design.md` landed first, its
`String? displayName,` field will already be there — add
`seasonalAccentsEnabled` as one more field after it instead, same
principle):

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
    required bool seasonalAccentsEnabled,
  }) = _AppSettings;
```

- [ ] **Step 6: Add the repository interface method**

In `lib/features/settings/domain/repositories/settings_repository.dart`,
add after `updateQuietHours`:

```dart
  /// Enables or disables the seasonal accent-color shift (Pohela
  /// Boishakh today; Eid once a Hijri date source exists).
  Future<Result<void>> updateSeasonalAccentsEnabled({required bool enabled});
```

- [ ] **Step 7: Implement it and wire `_toDomain`**

In `lib/features/settings/data/repositories/settings_repository_impl.dart`,
add after `updateQuietHours`'s implementation:

```dart
  @override
  Future<Result<void>> updateSeasonalAccentsEnabled({
    required bool enabled,
  }) => _update(
    AppSettingsTableCompanion(seasonalAccentsEnabled: Value(enabled)),
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
    biometricEnabled: row.biometricEnabled,
    screenPrivacyEnabled: row.screenPrivacyEnabled,
    onboardingCompletedAt: row.onboardingCompletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.onboardingCompletedAt!,
            isUtc: true,
          ),
    lastSeenAppVersion: row.lastSeenAppVersion,
    quietHoursEnabled: row.quietHoursEnabled,
    quietHoursStart: LocalTime.parse(row.quietHoursStart),
    quietHoursEnd: LocalTime.parse(row.quietHoursEnd),
  );
```

to (append `seasonalAccentsEnabled: row.seasonalAccentsEnabled,` — if
the greeting plan's `displayName: row.displayName,` line landed first,
keep it and add this as one more line, same principle as Step 5):

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
    lastSeenAppVersion: row.lastSeenAppVersion,
    quietHoursEnabled: row.quietHoursEnabled,
    quietHoursStart: LocalTime.parse(row.quietHoursStart),
    quietHoursEnd: LocalTime.parse(row.quietHoursEnd),
    seasonalAccentsEnabled: row.seasonalAccentsEnabled,
  );
```

`seasonalAccentsEnabled` is **not** required in `_ensureSeeded`'s insert
— the column's `withDefault(const Constant(true))` covers a fresh row,
same as `pinEnabled`/`biometricEnabled` already do.

- [ ] **Step 8: Regenerate code**

Run: `dart run build_runner build --delete-conflicting-outputs | tail -10`
Expected: exits 0, regenerates `app_settings.freezed.dart` and
`app_database.g.dart` (both gitignored) with the new field/column.

- [ ] **Step 9: Run the test, confirm it passes**

Run: `flutter test test/features/settings/data/repositories/settings_repository_impl_test.dart | tail -10`
Expected: `+1: All tests passed!`

- [ ] **Step 10: Analyze**

Run: `flutter analyze | tail -10`
Expected: `No issues found!` — since the new field is `required` on
`AppSettings`, this also catches any call site constructing
`AppSettings(...)` directly without it (there should be none besides
`settings_repository_impl.dart`, already fixed above).

- [ ] **Step 11: Commit**

```bash
git add lib/core/database/tables/app_settings_table.dart \
  lib/core/database/app_database.dart \
  lib/features/settings/domain/entities/app_settings.dart \
  lib/features/settings/domain/repositories/settings_repository.dart \
  lib/features/settings/data/repositories/settings_repository_impl.dart \
  test/features/settings/data/repositories/settings_repository_impl_test.dart
git commit -m "feat(settings): add seasonalAccentsEnabled opt-out"
```

---

### Task 2: `activeSeasonalOccasion` pure util

**Files:**
- Create: `lib/core/theme/seasonal_occasion.dart`
- Test: `test/core/theme/seasonal_occasion_test.dart`

**Interfaces:**
- Produces: `enum SeasonalOccasion { poholaBoishakh, eid }`,
  `SeasonalOccasion? activeSeasonalOccasion(LocalDate today)` — consumed
  by Task 3's `SeasonalAccent` and Task 4's provider.

- [ ] **Step 1: Write the failing test**

`test/core/theme/` doesn't exist yet — create the directory, then
create the test file:

```bash
mkdir -p test/core/theme
```

Create `test/core/theme/seasonal_occasion_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/theme/seasonal_occasion.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  group('activeSeasonalOccasion', () {
    test('13 April is inside the Pohela Boishakh window', () {
      expect(
        activeSeasonalOccasion(const LocalDate(2026, 4, 13)),
        SeasonalOccasion.poholaBoishakh,
      );
    });

    test('14 April (the day itself) is inside the window', () {
      expect(
        activeSeasonalOccasion(const LocalDate(2026, 4, 14)),
        SeasonalOccasion.poholaBoishakh,
      );
    });

    test('15 April is inside the window', () {
      expect(
        activeSeasonalOccasion(const LocalDate(2026, 4, 15)),
        SeasonalOccasion.poholaBoishakh,
      );
    });

    test('12 April is outside the window', () {
      expect(activeSeasonalOccasion(const LocalDate(2026, 4, 12)), isNull);
    });

    test('16 April is outside the window', () {
      expect(activeSeasonalOccasion(const LocalDate(2026, 4, 16)), isNull);
    });

    test('a date in an unrelated month returns null', () {
      expect(activeSeasonalOccasion(const LocalDate(2026, 7, 23)), isNull);
    });

    test(
      'Eid is never detected — permanently a documented no-op until a '
      'Hijri date source exists (shared prerequisite with Ramadan mode)',
      () {
        // Sweep every day of a full year: activeSeasonalOccasion must
        // never return SeasonalOccasion.eid, regardless of date.
        var day = const LocalDate(2026, 1, 1);
        for (var i = 0; i < 365; i++) {
          expect(activeSeasonalOccasion(day), isNot(SeasonalOccasion.eid));
          day = day.addDays(1);
        }
      },
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/seasonal_occasion_test.dart | tail -10`
Expected: FAIL to compile — `lib/core/theme/seasonal_occasion.dart`
doesn't exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/theme/seasonal_occasion.dart`:

```dart
import 'package:habit_tracker/core/utils/local_date.dart';

/// A curated seasonal occasion this app acknowledges cosmetically
/// (`docs/superpowers/specs/02-delightful/
/// 12-seasonal-theme-accents-design.md`).
enum SeasonalOccasion {
  /// Pohela Boishakh (Bengali New Year), 14 April Gregorian.
  poholaBoishakh,

  /// Eid-ul-Fitr/Eid-ul-Adha — detection blocked on a Hijri date source
  /// this app doesn't have yet (see [activeSeasonalOccasion]'s doc
  /// comment); [activeSeasonalOccasion] never actually returns this.
  eid,
}

/// Pure — returns the active seasonal occasion for [today], or `null` if
/// none is active. Takes an explicit [LocalDate] rather than calling
/// `clock.now()` itself, so it's unit-testable and reusable from a
/// `Consumer` that reads the clock once per build (same convention as
/// `core/utils/greeting.dart`'s `greetingPeriodFor`).
///
/// Pohela Boishakh (14 April, Gregorian — fixed, no calendar-conversion
/// dependency needed) gets a same-day-plus-one-either-side window
/// (13-15 April inclusive).
///
/// Eid-ul-Fitr/Eid-ul-Adha need a Hijri date source this app doesn't have
/// yet — `pubspec.yaml` has no Hijri/lunar-calendar package (`adhan_dart`
/// only computes prayer times, not Gregorian↔Hijri conversion). Until
/// that prerequisite lands (shared with the separate Ramadan-mode item),
/// [SeasonalOccasion.eid] detection is dead code: this function
/// unconditionally never returns it.
SeasonalOccasion? activeSeasonalOccasion(LocalDate today) {
  if (today.month == 4 && (today.day - 14).abs() <= 1) {
    return SeasonalOccasion.poholaBoishakh;
  }
  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/seasonal_occasion_test.dart | tail -10`
Expected: `+7: All tests passed!`

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/core/theme/seasonal_occasion.dart | tail -10`
Run: `dart format lib/core/theme/seasonal_occasion.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/seasonal_occasion.dart \
  test/core/theme/seasonal_occasion_test.dart
git commit -m "feat(theme): add the pure activeSeasonalOccasion date-window util"
```

---

### Task 3: `AppTheme` seed override + `SeasonalAccent`

**Files:**
- Modify: `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: `SeasonalOccasion` (Task 2, for `SeasonalAccent`'s field
  type only — this task does not call `activeSeasonalOccasion`).
- Produces: `AppTheme.light({required bool isBangla, Color?
  seasonalSeed})` / `.dark(...)` (both now take the extra optional
  param), `class SeasonalAccent { occasion, seedColor }` with
  `SeasonalAccent.poholaBoishakh`/`.eid` static consts — consumed by
  Task 4's provider and Task 6's `main.dart` wiring.

- [ ] **Step 1: Write the failing test**

Create `test/core/theme/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';

void main() {
  group('AppTheme seasonal seed override', () {
    test(
      "light() with no seasonalSeed keeps today's seed-color behavior "
      'unchanged (regression guard for the seasonal-accent override)',
      () {
        final theme = AppTheme.light(isBangla: false);
        // Matches `_seedColor` in app_theme.dart — this test exists to
        // catch an accidental default-seed change or a broken
        // "seasonalSeed: null falls back to _seedColor" path.
        final expected = ColorScheme.fromSeed(
          seedColor: const Color(0xFF006874),
          brightness: Brightness.light,
        );
        expect(theme.colorScheme.primary, expected.primary);
        expect(theme.colorScheme.surface, expected.surface);
      },
    );

    test(
      "dark() with no seasonalSeed keeps today's seed-color behavior "
      'unchanged',
      () {
        final theme = AppTheme.dark(isBangla: false);
        final expected = ColorScheme.fromSeed(
          seedColor: const Color(0xFF006874),
          brightness: Brightness.dark,
        );
        expect(theme.colorScheme.primary, expected.primary);
        expect(theme.colorScheme.surface, expected.surface);
      },
    );

    test(
      'light() with a seasonalSeed produces a measurably different '
      'primary color than the non-seasonal default',
      () {
        final defaultTheme = AppTheme.light(isBangla: false);
        final seasonalTheme = AppTheme.light(
          isBangla: false,
          seasonalSeed: SeasonalAccent.poholaBoishakh.seedColor,
        );
        expect(
          seasonalTheme.colorScheme.primary,
          isNot(equals(defaultTheme.colorScheme.primary)),
        );
      },
    );

    test(
      "a seasonalSeed does not change AppSemanticColors' success color "
      '— seasonal accents only substitute the ColorScheme seed',
      () {
        final defaultTheme = AppTheme.light(isBangla: false);
        final seasonalTheme = AppTheme.light(
          isBangla: false,
          seasonalSeed: SeasonalAccent.poholaBoishakh.seedColor,
        );
        final defaultSuccess = defaultTheme
            .extension<AppSemanticColors>()!
            .success;
        final seasonalSuccess = seasonalTheme
            .extension<AppSemanticColors>()!
            .success;
        expect(seasonalSuccess, defaultSuccess);
        expect(seasonalSuccess, AppSemanticColors.light.success);
      },
    );

    test(
      'ModuleAccents are plain static constants, unaffected by any '
      'seasonalSeed argument',
      () {
        // ModuleAccents has no constructor/argument surface at all — this
        // test documents that invariant rather than exercising behavior:
        // there is no seasonalSeed-shaped input that could reach it.
        expect(ModuleAccents.water, const Color(0xFF1565C0));
        expect(ModuleAccents.medicine, const Color(0xFF5E35B1));
        expect(ModuleAccents.prayer, const Color(0xFFB8860B));
      },
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_theme_test.dart | tail -10`
Expected: FAIL to compile — `AppTheme.light`/`.dark` don't accept a
`seasonalSeed` parameter yet, and `SeasonalAccent` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

In `lib/core/theme/app_theme.dart`, add the new import at the top:

```dart
import 'package:habit_tracker/core/theme/seasonal_occasion.dart';
```

Add the `SeasonalAccent` class right after `ModuleAccents` (before
`AppSemanticColors`):

```dart
/// A curated seasonal occasion this app acknowledges cosmetically
/// (`core/theme/seasonal_occasion.dart`) — a substitute `ColorScheme`
/// seed, applied only when Settings' opt-out isn't set and today falls
/// in the active window.
class SeasonalAccent {
  /// Creates a seasonal accent pairing an [occasion] with its
  /// [seedColor].
  const SeasonalAccent({required this.occasion, required this.seedColor});

  /// The occasion this accent represents.
  final SeasonalOccasion occasion;

  /// The substitute `ColorScheme.fromSeed` seed color for this occasion.
  final Color seedColor;

  /// Pohela Boishakh — traditional red-and-white motif.
  static const poholaBoishakh = SeasonalAccent(
    occasion: SeasonalOccasion.poholaBoishakh,
    seedColor: Color(0xFFC62828),
  );

  /// Both Eid occasions share one accent (traditional Eid green) — a
  /// curated design decision, not a per-Eid distinction. Unreachable
  /// today: `activeSeasonalOccasion` never returns
  /// [SeasonalOccasion.eid] until a Hijri date source exists
  /// (`core/theme/seasonal_occasion.dart`).
  static const eid = SeasonalAccent(
    occasion: SeasonalOccasion.eid,
    seedColor: Color(0xFF2E7D32),
  );
}
```

Change:

```dart
  /// Light theme, seeded from [_seedColor].
  static ThemeData light({required bool isBangla}) => _build(
    brightness: Brightness.light,
    semanticColors: AppSemanticColors.light,
    isBangla: isBangla,
  );

  /// Dark theme, seeded from [_seedColor].
  static ThemeData dark({required bool isBangla}) => _build(
    brightness: Brightness.dark,
    semanticColors: AppSemanticColors.dark,
    isBangla: isBangla,
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppSemanticColors semanticColors,
    required bool isBangla,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
```

to:

```dart
  /// Light theme, seeded from [_seedColor] unless [seasonalSeed]
  /// overrides it (a curated seasonal accent, `core/theme/
  /// seasonal_accent_provider.dart` — `null` when no occasion is active
  /// or the user opted out).
  static ThemeData light({required bool isBangla, Color? seasonalSeed}) =>
      _build(
        brightness: Brightness.light,
        semanticColors: AppSemanticColors.light,
        isBangla: isBangla,
        seedColor: seasonalSeed ?? _seedColor,
      );

  /// Dark theme, seeded from [_seedColor] unless [seasonalSeed] overrides
  /// it.
  static ThemeData dark({required bool isBangla, Color? seasonalSeed}) =>
      _build(
        brightness: Brightness.dark,
        semanticColors: AppSemanticColors.dark,
        isBangla: isBangla,
        seedColor: seasonalSeed ?? _seedColor,
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppSemanticColors semanticColors,
    required bool isBangla,
    required Color seedColor,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_theme_test.dart | tail -10`
Expected: `+5: All tests passed!`

- [ ] **Step 5: Analyze, format, and full sweep**

Run: `flutter analyze lib/core/theme/app_theme.dart | tail -10`
Run: `dart format lib/core/theme/app_theme.dart`
Expected: `No issues found!`

Run: `flutter test test/widget_test.dart | tail -10`
Expected: PASS — `AppTheme.light`/`.dark`'s two call sites in
`main.dart` still compile with the old two-argument-less call shape
(the new parameter is optional), so the app still boots.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/app_theme.dart test/core/theme/app_theme_test.dart
git commit -m "feat(theme): let AppTheme.light/dark accept a seasonal seed override"
```

---

### Task 4: `seasonalAccentSeedProvider`

**Files:**
- Create: `lib/core/theme/seasonal_accent_provider.dart`
- Test: `test/core/theme/seasonal_accent_provider_test.dart`

**Interfaces:**
- Consumes: `activeSeasonalOccasion` (Task 2), `SeasonalAccent` (Task
  3), `AppSettings.seasonalAccentsEnabled` (Task 1),
  `appSettingsProvider`/`settingsRepositoryProvider` (pre-existing).
- Produces: `@riverpod Color? seasonalAccentSeed(Ref ref)` — consumed by
  Task 6's `main.dart` wiring.

- [ ] **Step 1: Write the failing test**

Create `test/core/theme/seasonal_accent_provider_test.dart`:

```dart
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/theme/seasonal_accent_provider.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

import '../../support/test_database.dart';

void main() {
  test(
    'returns the Pohela Boishakh seed when enabled and the date is '
    'inside its window',
    () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(testDatabase())],
      );
      addTearDown(container.dispose);

      await withClock(Clock.fixed(DateTime.utc(2026, 4, 14, 8)), () async {
        await container.read(appSettingsProvider.future);
        expect(
          container.read(seasonalAccentSeedProvider),
          SeasonalAccent.poholaBoishakh.seedColor,
        );
      });
    },
  );

  test('returns null on a date with no active occasion', () async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(testDatabase())],
    );
    addTearDown(container.dispose);

    await withClock(Clock.fixed(DateTime.utc(2026, 7, 23, 8)), () async {
      await container.read(appSettingsProvider.future);
      expect(container.read(seasonalAccentSeedProvider), isNull);
    });
  });

  test(
    'returns null when the user has opted out, even inside the window',
    () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(testDatabase())],
      );
      addTearDown(container.dispose);

      await withClock(Clock.fixed(DateTime.utc(2026, 4, 14, 8)), () async {
        await container.read(appSettingsProvider.future);

        final optedOut = Completer<void>();
        container.listen(appSettingsProvider, (previous, next) {
          if (next.value?.seasonalAccentsEnabled == false) {
            optedOut.complete();
          }
        });
        await container
            .read(settingsRepositoryProvider)
            .updateSeasonalAccentsEnabled(enabled: false);
        await optedOut.future.timeout(const Duration(seconds: 2));

        expect(container.read(seasonalAccentSeedProvider), isNull);
      });
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/seasonal_accent_provider_test.dart | tail -10`
Expected: FAIL to compile — `lib/core/theme/
seasonal_accent_provider.dart` doesn't exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/theme/seasonal_accent_provider.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/theme/seasonal_occasion.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'seasonal_accent_provider.g.dart';

/// The active seasonal seed color, or `null` if none applies today
/// (opted out, or no occasion active) — `HabitTrackerApp.build` reads
/// this alongside `themeControllerProvider`/`localeControllerProvider`.
/// No lingering state to revert: this is a pure computed read of
/// `clock.now()` + settings each rebuild, so once the date window
/// passes, the next rebuild (app resume, at minimum) simply recomputes
/// `null` and the theme reverts to `_seedColor` on its own.
@riverpod
Color? seasonalAccentSeed(Ref ref) {
  final settings = ref.watch(appSettingsProvider).value;
  if (settings == null || !settings.seasonalAccentsEnabled) return null;
  final occasion = activeSeasonalOccasion(localDayKey(clock.now()));
  return switch (occasion) {
    null => null,
    SeasonalOccasion.poholaBoishakh => SeasonalAccent.poholaBoishakh.seedColor,
    SeasonalOccasion.eid => SeasonalAccent.eid.seedColor,
  };
}
```

- [ ] **Step 4: Regenerate code**

Run: `dart run build_runner build --delete-conflicting-outputs | tail -10`
Expected: exits 0, generates `seasonal_accent_provider.g.dart`
(gitignored).

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/theme/seasonal_accent_provider_test.dart | tail -10`
Expected: `+3: All tests passed!`

- [ ] **Step 6: Analyze and format**

Run: `flutter analyze lib/core/theme/seasonal_accent_provider.dart | tail -10`
Run: `dart format lib/core/theme/seasonal_accent_provider.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/seasonal_accent_provider.dart \
  test/core/theme/seasonal_accent_provider_test.dart
git commit -m "feat(theme): add seasonalAccentSeedProvider"
```

---

### Task 5: Settings toggle UI

**Files:**
- Modify: `lib/features/settings/presentation/screens/theme_settings_screen.dart`
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Test: `test/features/settings/presentation/screens/theme_settings_screen_test.dart` (new)

**Interfaces:**
- Consumes: `AppSettings.seasonalAccentsEnabled`,
  `SettingsRepository.updateSeasonalAccentsEnabled` (Task 1).

- [ ] **Step 1: Add l10n keys to both arb files**

In `lib/core/l10n/app_en.arb`, insert after the `"themeModeDark"` block
(immediately before `"emptyDashboardMessage"`) — find this exact anchor
text:

```json
  "themeModeDark": "Dark",
  "@themeModeDark": {
    "description": "Option label: always use the dark theme."
  },
  "emptyDashboardMessage": "Enable a module in Settings to get started",
```

Replace it with:

```json
  "themeModeDark": "Dark",
  "@themeModeDark": {
    "description": "Option label: always use the dark theme."
  },
  "settingsSeasonalAccentsToggle": "Seasonal color accents",
  "@settingsSeasonalAccentsToggle": {
    "description": "Toggle label for the seasonal theme-accent opt-out."
  },
  "settingsSeasonalAccentsDescription": "Subtly shift the app's color around Pohela Boishakh",
  "@settingsSeasonalAccentsDescription": {
    "description": "Subtitle explaining the seasonal theme-accent toggle."
  },
  "emptyDashboardMessage": "Enable a module in Settings to get started",
```

(Note: this key text is careful to say "Pohela Boishakh," not "Eid and
Pohela Boishakh" — Eid detection does not ship in this plan, so the
copy should not promise it.)

In `lib/core/l10n/app_bn.arb`, insert after the `"themeModeDark"` line
(immediately before `"emptyDashboardMessage"`) — find this exact anchor
text:

```json
  "themeModeDark": "ডার্ক",
  "emptyDashboardMessage": "শুরু করতে সেটিংসে একটি মডিউল চালু করুন",
```

Replace it with:

```json
  "themeModeDark": "ডার্ক",
  "settingsSeasonalAccentsToggle": "ঋতুভিত্তিক রঙের ছোঁয়া",
  "settingsSeasonalAccentsDescription": "পহেলা বৈশাখের আশেপাশে অ্যাপের রঙে সামান্য পরিবর্তন",
  "emptyDashboardMessage": "শুরু করতে সেটিংসে একটি মডিউল চালু করুন",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors.

- [ ] **Step 3: Write the failing test**

Create `test/features/settings/presentation/screens/
theme_settings_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/settings/presentation/screens/theme_settings_screen.dart';

Future<void> _pumpThemeSettings(
  WidgetTester tester,
  AppDatabase db,
  SettingsRepository repo,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepositoryImpl(db);
  });
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('defaults to on for a fresh install', (tester) async {
    await _pumpThemeSettings(tester, db, repo);

    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Seasonal color accents'),
    );
    expect(tile.value, isTrue);

    await disposeTree(tester);
  });

  testWidgets('toggling off persists the opt-out', (tester) async {
    await _pumpThemeSettings(tester, db, repo);

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Seasonal color accents'),
    );
    await tester.pumpAndSettle();

    expect(
      (await repo.watchSettings().first).seasonalAccentsEnabled,
      isFalse,
    );
    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Seasonal color accents'),
    );
    expect(tile.value, isFalse);

    await disposeTree(tester);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/screens/theme_settings_screen_test.dart | tail -10`
Expected: FAIL — no `SwitchListTile` titled "Seasonal color accents"
exists on `ThemeSettingsScreen` yet.

- [ ] **Step 5: Write minimal implementation**

In `lib/features/settings/presentation/screens/
theme_settings_screen.dart`, add the import:

```dart
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
```

Change:

```dart
class ThemeSettingsScreen extends ConsumerWidget {
  /// Creates the theme settings screen.
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTheme)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text(l10n.themeModeSystem),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              label: Text(l10n.themeModeLight),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text(l10n.themeModeDark),
            ),
          ],
          selected: {themeMode},
          onSelectionChanged: (selection) => ref
              .read(themeControllerProvider.notifier)
              .updateThemeMode(selection.first),
        ),
      ),
    );
  }
}
```

to:

```dart
class ThemeSettingsScreen extends ConsumerWidget {
  /// Creates the theme settings screen.
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeControllerProvider);
    final settings = ref.watch(appSettingsProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTheme)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeModeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeModeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeModeDark),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) => ref
                  .read(themeControllerProvider.notifier)
                  .updateThemeMode(selection.first),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.settingsSeasonalAccentsToggle),
            subtitle: Text(l10n.settingsSeasonalAccentsDescription),
            value: settings?.seasonalAccentsEnabled ?? true,
            onChanged: (value) => ref
                .read(settingsRepositoryProvider)
                .updateSeasonalAccentsEnabled(enabled: value),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/screens/theme_settings_screen_test.dart | tail -10`
Expected: `+2: All tests passed!`

- [ ] **Step 7: Analyze and format**

Run: `flutter analyze lib/features/settings/presentation/screens/theme_settings_screen.dart | tail -10`
Run: `dart format lib/features/settings/presentation/screens/theme_settings_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/settings/presentation/screens/theme_settings_screen.dart \
  lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  test/features/settings/presentation/screens/theme_settings_screen_test.dart
git commit -m "feat(settings): add the seasonal-accents opt-out toggle"
```

---

### Task 6: Wire `main.dart`

**Files:**
- Modify: `lib/main.dart:196-228`

**Interfaces:**
- Consumes: `seasonalAccentSeedProvider` (Task 4), `AppTheme.light`/
  `.dark`'s new `seasonalSeed` parameter (Task 3).

- [ ] **Step 1: Add the import**

In `lib/main.dart`, add (alongside the other `habit_tracker/core/...`
imports):

```dart
import 'package:habit_tracker/core/theme/seasonal_accent_provider.dart';
```

- [ ] **Step 2: Watch the provider and pass it through**

Change:

```dart
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final isBangla = locale.languageCode == 'bn';
```

to:

```dart
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final isBangla = locale.languageCode == 'bn';
    final seasonalSeed = ref.watch(seasonalAccentSeedProvider);
```

Change:

```dart
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light(isBangla: isBangla),
      darkTheme: AppTheme.dark(isBangla: isBangla),
      themeMode: themeMode,
```

to:

```dart
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light(isBangla: isBangla, seasonalSeed: seasonalSeed),
      darkTheme: AppTheme.dark(isBangla: isBangla, seasonalSeed: seasonalSeed),
      themeMode: themeMode,
```

- [ ] **Step 3: Analyze and run the app-boot smoke test**

Run: `flutter analyze lib/main.dart | tail -10`
Expected: `No issues found!`

Run: `flutter test test/widget_test.dart | tail -10`
Expected: PASS — the app still boots to the dashboard with the new
provider wired in (on today's real date this test runs, no seasonal
window is active, so `seasonalSeed` resolves to `null` and the theme
falls back to `_seedColor`, same as before this task).

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat(theme): apply the seasonal accent seed in main.dart"
```

---

## After all tasks

Per this repo's CLAUDE.md spec-implementation workflow: once every task
above is committed, open a PR for the spec with the design summary in the
description (including the explicit note that Eid detection is
out-of-scope/blocked, not silently dropped), then run a code review
against the finished PR (comment → fix → commit cycle, up to 5 rounds),
then stop and wait for the user's own review and merge.

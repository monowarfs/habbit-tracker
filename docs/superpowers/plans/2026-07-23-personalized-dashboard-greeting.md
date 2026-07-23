# Personalized Dashboard Greeting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a time-of-day-aware greeting line ("Good morning" /
"Good morning, {name}") at the top of the dashboard, backed by one new
optional `displayName` field the user can set from Settings, per
`docs/superpowers/specs/02-delightful/
11-personalized-dashboard-greeting-design.md`.

**Architecture:** One new nullable `app_settings.display_name` column
(schema v8), flowing through the existing `AppSettings`/
`SettingsRepository`/`SettingsRepositoryImpl` pattern. A pure
`greetingPeriodFor(DateTime)` util buckets the clock into
morning/afternoon/evening/night. A small bottom-sheet editor (shaped
like `core/widgets/note_editor_sheet.dart`) lives behind a new "Profile"
section on `SettingsHomeScreen`. `DashboardScreen` gains a
`_DashboardGreeting` widget, inserted immediately before
`_DayCompletionIndicator`, that reads the display name and `clock.now()`
(not `DateTime.now()` — this item does not replicate
`DashboardScreen`'s two pre-existing `DateTime.now()` calls).

**Tech Stack:** Flutter/Riverpod (codegen), Drift (codegen), `clock`,
`gen_l10n`, `flutter_test`, `mocktail`.

## Global Constraints

- **Schema-version coordination (read this before touching
  `app_database.dart`).** Two other specs in this same batch
  (`06-why-this-matters`, planned separately, and
  `12-seasonal-theme-accents-design.md`) also want to bump
  `schemaVersion` from 7 to 8. Task 1's own step below has you check the
  file's current state first — do not skip that check even if you
  "know" it's still 7.
- `displayName` max length: 40 characters, UI-enforced
  (`TextField.maxLength`), no DB `CHECK` constraint — same "UI caps
  input" precedent as `core/widgets/note_editor_sheet.dart`'s
  `noteMaxLength`.
- `displayName` is **not** part of backup export/import — same
  not-backed-up precedent `onboardingCompletedAt`/`lastSeenAppVersion`
  already follow (`export_orchestrator.dart`/`import_orchestrator.dart`
  are not touched by this plan).
- The greeting is strictly time-of-day — no day-completion-aware
  variants ("all done for today!"), no per-module/per-achievement
  variation.
- New/changed dashboard and greeting code uses `clock.now()`
  (`package:clock`), never raw `DateTime.now()` — `DashboardScreen`'s
  two pre-existing `DateTime.now()` calls (`_DayCompletionIndicator`,
  `_GlobalCalendarSheetState`) are a known, separate issue; this plan
  does not touch them.
- New files: `lib/core/utils/greeting.dart`, `lib/features/settings/
  presentation/widgets/display_name_editor_sheet.dart`.
- Modified files: `lib/features/settings/domain/entities/
  app_settings.dart`, `lib/core/database/tables/app_settings_table.dart`,
  `lib/core/database/app_database.dart`, `lib/features/settings/domain/
  repositories/settings_repository.dart`, `lib/features/settings/data/
  repositories/settings_repository_impl.dart`, `lib/features/settings/
  presentation/screens/settings_home_screen.dart`,
  `lib/features/dashboard/presentation/screens/dashboard_screen.dart`,
  `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`.
- Per this repo's CLAUDE.md spec-implementation workflow: one commit per
  task, run only that task's own test file (never the full `flutter
  test` suite mid-task), pipe `build_runner`/`test`/`gen-l10n` output
  through `| tail -10`.

---

### Task 1: Data layer — `displayName` field

**Files:**
- Modify: `lib/core/database/tables/app_settings_table.dart`
- Modify: `lib/core/database/app_database.dart:53-110`
- Modify: `lib/features/settings/domain/entities/app_settings.dart:45-58`
- Modify: `lib/features/settings/domain/repositories/settings_repository.dart`
- Modify: `lib/features/settings/data/repositories/settings_repository_impl.dart`
- Test: `test/features/settings/data/repositories/settings_repository_impl_test.dart`

**Interfaces:**
- Produces: `AppSettings.displayName` (`String?`),
  `SettingsRepository.updateDisplayName(String? name)` — consumed by
  Task 3's Settings UI and Task 4's dashboard greeting.

- [ ] **Step 1: Write the failing repository test**

Add to `test/features/settings/data/repositories/
settings_repository_impl_test.dart`, right after the existing
`expect(firstRead.screenPrivacyEnabled, isFalse);` line:

```dart
    expect(firstRead.displayName, isNull);
```

Right after the existing
`final privacyResult = await repo1.updateScreenPrivacyEnabled(enabled: true);`
block (before `await db1.close();`), add:

```dart
    final displayNameResult = await repo1.updateDisplayName('Nadia');
    expect(displayNameResult, isA<Success<void>>());
```

Right after the existing `expect(afterRestart.screenPrivacyEnabled, isTrue);`,
add:

```dart
    expect(afterRestart.displayName, 'Nadia');
```

- [ ] **Step 2: Run it, confirm it fails to compile**

Run: `flutter test test/features/settings/data/repositories/settings_repository_impl_test.dart | tail -10`
Expected: compile error — `displayName`/`updateDisplayName` don't exist
yet.

- [ ] **Step 3: Add the DB column**

In `lib/core/database/tables/app_settings_table.dart`, add after the
`lastSeenAppVersion` column (before `createdAt`):

```dart
  /// Optional user-set display name for the dashboard greeting; null =
  /// no name set, greeting degrades to a name-less form
  /// (`docs/superpowers/specs/02-delightful/
  /// 11-personalized-dashboard-greeting-design.md`).
  TextColumn get displayName => text().nullable()();
```

- [ ] **Step 4: Check the current `schemaVersion` and apply the migration**

Two other specs in this batch (`06-why-this-matters`,
`12-seasonal-theme-accents-design.md`) also target schema v8. Check
which state the file is actually in before editing:

Run: `grep -n "int get schemaVersion" lib/core/database/app_database.dart`

- **If it prints `int get schemaVersion => 7;`** (nothing else has landed
  yet): bump it to 8 and add a new `if (from < 8) { ... }` block
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
          // Dashboard greeting's optional display name.
          await m.addColumn(appSettingsTable, appSettingsTable.displayName);
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
  if `12-seasonal-theme-accents-design.md` landed first, the block
  currently reads:

  ```dart
        if (from < 8) {
          // Seasonal theme accent opt-out.
          await m.addColumn(
            appSettingsTable,
            appSettingsTable.seasonalAccentsEnabled,
          );
        }
  ```

  change it to:

  ```dart
        if (from < 8) {
          // Seasonal theme accent opt-out.
          await m.addColumn(
            appSettingsTable,
            appSettingsTable.seasonalAccentsEnabled,
          );
          // Dashboard greeting's optional display name.
          await m.addColumn(appSettingsTable, appSettingsTable.displayName);
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
    String? lastSeenAppVersion,
    required bool quietHoursEnabled,
    required LocalTime quietHoursStart,
    required LocalTime quietHoursEnd,
    String? displayName,
  }) = _AppSettings;
```

- [ ] **Step 6: Add the repository interface method**

In `lib/features/settings/domain/repositories/settings_repository.dart`,
add after `updateQuietHours`:

```dart
  /// Updates the display name shown in the dashboard greeting. `null`/
  /// empty clears it back to the name-less greeting.
  Future<Result<void>> updateDisplayName(String? name);
```

- [ ] **Step 7: Implement it and wire `_toDomain`**

In `lib/features/settings/data/repositories/settings_repository_impl.dart`,
add after `updateQuietHours`'s implementation:

```dart
  @override
  Future<Result<void>> updateDisplayName(String? name) =>
      _update(AppSettingsTableCompanion(displayName: Value(name)));
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
    lastSeenAppVersion: row.lastSeenAppVersion,
    quietHoursEnabled: row.quietHoursEnabled,
    quietHoursStart: LocalTime.parse(row.quietHoursStart),
    quietHoursEnd: LocalTime.parse(row.quietHoursEnd),
    displayName: row.displayName,
  );
```

`restoreSettings`'s companion is deliberately **not** touched —
`displayName` is not part of backup/restore (Global Constraints).

- [ ] **Step 8: Regenerate code**

Run: `dart run build_runner build --delete-conflicting-outputs | tail -10`
Expected: exits 0, regenerates `app_settings.freezed.dart` and
`app_database.g.dart` (both gitignored) with the new field/column.

- [ ] **Step 9: Run the test, confirm it passes**

Run: `flutter test test/features/settings/data/repositories/settings_repository_impl_test.dart | tail -10`
Expected: `+1: All tests passed!`

- [ ] **Step 10: Analyze**

Run: `flutter analyze | tail -10`
Expected: `No issues found!` — confirms no other call site constructs
`AppSettings(...)` without the new optional field breaking (it's
optional/non-`required`, so no call site needs an update).

- [ ] **Step 11: Commit**

```bash
git add lib/core/database/tables/app_settings_table.dart \
  lib/core/database/app_database.dart \
  lib/features/settings/domain/entities/app_settings.dart \
  lib/features/settings/domain/repositories/settings_repository.dart \
  lib/features/settings/data/repositories/settings_repository_impl.dart \
  test/features/settings/data/repositories/settings_repository_impl_test.dart
git commit -m "feat(settings): add displayName field for the dashboard greeting"
```

---

### Task 2: `greetingPeriodFor` pure util

**Files:**
- Create: `lib/core/utils/greeting.dart`
- Test: `test/core/utils/greeting_test.dart`

**Interfaces:**
- Produces: `enum GreetingPeriod { morning, afternoon, evening, night }`,
  `GreetingPeriod greetingPeriodFor(DateTime now)` — consumed by Task 4's
  `_DashboardGreeting`.

- [ ] **Step 1: Write the failing test**

Create `test/core/utils/greeting_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/greeting.dart';

void main() {
  group('greetingPeriodFor', () {
    test('04:59 is night (just before the morning boundary)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 4, 59)),
        GreetingPeriod.night,
      );
    });

    test('05:00 is morning (the morning boundary itself)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 5)),
        GreetingPeriod.morning,
      );
    });

    test('11:59 is still morning (just before the afternoon boundary)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 11, 59)),
        GreetingPeriod.morning,
      );
    });

    test('12:00 is afternoon (the afternoon boundary itself)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 12)),
        GreetingPeriod.afternoon,
      );
    });

    test('16:59 is still afternoon (just before the evening boundary)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 16, 59)),
        GreetingPeriod.afternoon,
      );
    });

    test('17:00 is evening (the evening boundary itself)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 17)),
        GreetingPeriod.evening,
      );
    });

    test('20:59 is still evening (just before the night boundary)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 20, 59)),
        GreetingPeriod.evening,
      );
    });

    test('21:00 is night (the night boundary itself)', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1, 21)),
        GreetingPeriod.night,
      );
    });

    test('00:00 (midnight) is night', () {
      expect(
        greetingPeriodFor(DateTime.utc(2026, 6, 1)),
        GreetingPeriod.night,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/greeting_test.dart | tail -10`
Expected: FAIL to compile — `lib/core/utils/greeting.dart` doesn't exist
yet.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/utils/greeting.dart`:

```dart
/// Time-of-day bucket for the dashboard greeting
/// (`docs/superpowers/specs/02-delightful/
/// 11-personalized-dashboard-greeting-design.md`). Boundaries: morning
/// 05:00-11:59, afternoon 12:00-16:59, evening 17:00-20:59, night
/// 21:00-04:59.
enum GreetingPeriod {
  /// 05:00-11:59.
  morning,

  /// 12:00-16:59.
  afternoon,

  /// 17:00-20:59.
  evening,

  /// 21:00-04:59.
  night,
}

/// Pure — takes [now] explicitly rather than calling `clock.now()`
/// itself, so it's unit-testable without `withClock` and reusable from a
/// `Consumer` build method that reads the clock once per build.
GreetingPeriod greetingPeriodFor(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) return GreetingPeriod.morning;
  if (hour >= 12 && hour < 17) return GreetingPeriod.afternoon;
  if (hour >= 17 && hour < 21) return GreetingPeriod.evening;
  return GreetingPeriod.night;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/greeting_test.dart | tail -10`
Expected: `+9: All tests passed!`

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/core/utils/greeting.dart | tail -10`
Run: `dart format lib/core/utils/greeting.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/utils/greeting.dart test/core/utils/greeting_test.dart
git commit -m "feat(dashboard): add the pure greetingPeriodFor time bucketing util"
```

---

### Task 3: Display-name editor and Settings "Profile" section

**Files:**
- Create: `lib/features/settings/presentation/widgets/display_name_editor_sheet.dart`
- Modify: `lib/features/settings/presentation/screens/settings_home_screen.dart`
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Test: `test/features/settings/presentation/widgets/display_name_editor_sheet_test.dart`
- Test: `test/features/settings/presentation/screens/settings_home_screen_test.dart`

**Interfaces:**
- Consumes: `AppSettings.displayName`,
  `SettingsRepository.updateDisplayName` (Task 1).
- Produces: `Future<String?> showDisplayNameEditorSheet(BuildContext
  context, {required String? initialName})` — consumed only by
  `SettingsHomeScreen` in this same task.

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
  "settingsProfile": "Profile",
  "@settingsProfile": {
    "description": "Settings section header for the display-name row."
  },
  "settingsDisplayName": "Your name",
  "@settingsDisplayName": {
    "description": "Label for the display-name row and its editor sheet title."
  },
  "settingsDisplayNameNotSet": "Not set",
  "@settingsDisplayNameNotSet": {
    "description": "Subtitle shown on the display-name row when no name has been set yet."
  },
  "emptyDashboardMessage": "Enable a module in Settings to get started",
```

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
  "settingsProfile": "প্রোফাইল",
  "settingsDisplayName": "আপনার নাম",
  "settingsDisplayNameNotSet": "সেট করা হয়নি",
  "emptyDashboardMessage": "শুরু করতে সেটিংসে একটি মডিউল চালু করুন",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors; the three new getters appear on `AppLocalizations`.

- [ ] **Step 3: Write the failing editor-sheet test**

Create `test/features/settings/presentation/widgets/
display_name_editor_sheet_test.dart` (same shape as `test/core/widgets/
note_editor_sheet_test.dart`'s two tests — each self-contained, no shared
pump helper):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/presentation/widgets/display_name_editor_sheet.dart';

void main() {
  testWidgets('typing a name and saving returns the trimmed text', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDisplayNameEditorSheet(
                  context,
                  initialName: null,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Nadia  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'Nadia');
  });

  testWidgets('prefills the existing name and clearing it returns null', (
    tester,
  ) async {
    String? result = 'not yet set';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDisplayNameEditorSheet(
                  context,
                  initialName: 'Nadia',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Nadia'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/widgets/display_name_editor_sheet_test.dart | tail -10`
Expected: FAIL to compile — `display_name_editor_sheet.dart` doesn't
exist yet.

- [ ] **Step 5: Write minimal implementation**

Create `lib/features/settings/presentation/widgets/
display_name_editor_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// UI-enforced max length for the display name — same "cap in the UI, no
/// DB `CHECK` constraint" precedent as `core/widgets/note_editor_sheet
/// .dart`'s `noteMaxLength`.
const displayNameMaxLength = 40;

/// Shows a bottom sheet with one text field (prefilled with
/// [initialName]) and a Save button. Returns the trimmed name, or `null`
/// if cleared — same shape as `showNoteEditorSheet`
/// (`core/widgets/note_editor_sheet.dart`), this item's own copy/length
/// cap.
Future<String?> showDisplayNameEditorSheet(
  BuildContext context, {
  required String? initialName,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _DisplayNameEditorSheet(initialName: initialName),
  );
}

class _DisplayNameEditorSheet extends StatefulWidget {
  const _DisplayNameEditorSheet({required this.initialName});

  final String? initialName;

  @override
  State<_DisplayNameEditorSheet> createState() =>
      _DisplayNameEditorSheetState();
}

class _DisplayNameEditorSheetState extends State<_DisplayNameEditorSheet> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsDisplayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controller,
            maxLength: displayNameMaxLength,
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                final trimmed = _controller.text.trim();
                Navigator.of(context).pop(trimmed.isEmpty ? null : trimmed);
              },
              child: Text(l10n.commonSave),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/widgets/display_name_editor_sheet_test.dart | tail -10`
Expected: `+2: All tests passed!`

- [ ] **Step 7: Write the failing Settings-screen wiring test**

Create `test/features/settings/presentation/screens/
settings_home_screen_test.dart`:

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
import 'package:habit_tracker/features/settings/presentation/screens/settings_home_screen.dart';

Future<void> _pumpSettingsHome(
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
        home: SettingsHomeScreen(),
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

  testWidgets('shows "Not set" for a fresh install with no display name '
      'set yet', (tester) async {
    await _pumpSettingsHome(tester, db, repo);

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('setting a display name persists it and updates the '
      'subtitle', (tester) async {
    await _pumpSettingsHome(tester, db, repo);

    await tester.tap(find.text('Your name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Nadia');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((await repo.watchSettings().first).displayName, 'Nadia');
    expect(find.text('Nadia'), findsOneWidget);
    expect(find.text('Not set'), findsNothing);

    await disposeTree(tester);
  });
}
```

- [ ] **Step 8: Run it, confirm it fails**

Run: `flutter test test/features/settings/presentation/screens/settings_home_screen_test.dart | tail -10`
Expected: FAIL — no "Profile" section/row exists on `SettingsHomeScreen`
yet.

- [ ] **Step 9: Add the Profile section to `SettingsHomeScreen`**

In `lib/features/settings/presentation/screens/settings_home_screen.dart`,
add the import (alongside the existing `app_settings_providers.dart`
import):

```dart
import 'package:habit_tracker/features/settings/presentation/widgets/display_name_editor_sheet.dart';
```

Change:

```dart
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pinEnabled =
        ref.watch(appSettingsProvider).value?.pinEnabled ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsAppearance),
```

to:

```dart
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider).value;
    final pinEnabled = settings?.pinEnabled ?? false;
    final displayName = settings?.displayName;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsProfile),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(l10n.settingsDisplayName),
            subtitle: Text(displayName ?? l10n.settingsDisplayNameNotSet),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final name = await showDisplayNameEditorSheet(
                context,
                initialName: displayName,
              );
              if (!context.mounted) return;
              await ref
                  .read(settingsRepositoryProvider)
                  .updateDisplayName(name);
            },
          ),
          const Divider(),
          _SectionHeader(l10n.settingsAppearance),
```

- [ ] **Step 10: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/screens/settings_home_screen_test.dart | tail -10`
Expected: `+2: All tests passed!`

- [ ] **Step 11: Analyze and format**

Run: `flutter analyze lib/features/settings/ | tail -10`
Run: `dart format lib/features/settings/`
Expected: `No issues found!`

- [ ] **Step 12: Commit**

```bash
git add lib/features/settings/presentation/widgets/display_name_editor_sheet.dart \
  lib/features/settings/presentation/screens/settings_home_screen.dart \
  lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  test/features/settings/presentation/widgets/display_name_editor_sheet_test.dart \
  test/features/settings/presentation/screens/settings_home_screen_test.dart
git commit -m "feat(settings): add the Profile section and display-name editor"
```

---

### Task 4: The dashboard greeting

**Files:**
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart:1-79`
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Test: `test/features/dashboard/dashboard_screen_test.dart`

**Interfaces:**
- Consumes: `greetingPeriodFor` (Task 2), `AppSettings.displayName`
  (Task 1).

- [ ] **Step 1: Add l10n keys to both arb files**

In `lib/core/l10n/app_en.arb`, insert after the `"emptyDashboardMessage"`
block (immediately before `"commonSave"`) — find this exact anchor text:

```json
  "emptyDashboardMessage": "Enable a module in Settings to get started",
  "@emptyDashboardMessage": {
    "description": "Shown on the dashboard when no module is enabled yet."
  },
  "commonSave": "Save",
```

Replace it with:

```json
  "emptyDashboardMessage": "Enable a module in Settings to get started",
  "@emptyDashboardMessage": {
    "description": "Shown on the dashboard when no module is enabled yet."
  },
  "dashboardGreetingMorning": "Good morning",
  "@dashboardGreetingMorning": {
    "description": "Dashboard greeting, time-of-day bucket: morning (05:00-11:59), no display name set."
  },
  "dashboardGreetingMorningNamed": "Good morning, {name}",
  "@dashboardGreetingMorningNamed": {
    "description": "Dashboard greeting, time-of-day bucket: morning, display name set.",
    "placeholders": {"name": {"type": "String"}}
  },
  "dashboardGreetingAfternoon": "Good afternoon",
  "@dashboardGreetingAfternoon": {
    "description": "Dashboard greeting, time-of-day bucket: afternoon (12:00-16:59), no display name set."
  },
  "dashboardGreetingAfternoonNamed": "Good afternoon, {name}",
  "@dashboardGreetingAfternoonNamed": {
    "description": "Dashboard greeting, time-of-day bucket: afternoon, display name set.",
    "placeholders": {"name": {"type": "String"}}
  },
  "dashboardGreetingEvening": "Good evening",
  "@dashboardGreetingEvening": {
    "description": "Dashboard greeting, time-of-day bucket: evening (17:00-20:59), no display name set."
  },
  "dashboardGreetingEveningNamed": "Good evening, {name}",
  "@dashboardGreetingEveningNamed": {
    "description": "Dashboard greeting, time-of-day bucket: evening, display name set.",
    "placeholders": {"name": {"type": "String"}}
  },
  "dashboardGreetingNight": "Hello",
  "@dashboardGreetingNight": {
    "description": "Dashboard greeting, time-of-day bucket: night (21:00-04:59), no display name set."
  },
  "dashboardGreetingNightNamed": "Hello, {name}",
  "@dashboardGreetingNightNamed": {
    "description": "Dashboard greeting, time-of-day bucket: night, display name set.",
    "placeholders": {"name": {"type": "String"}}
  },
  "commonSave": "Save",
```

In `lib/core/l10n/app_bn.arb`, insert after the
`"emptyDashboardMessage"` line (immediately before `"commonSave"`) —
find this exact anchor text:

```json
  "emptyDashboardMessage": "শুরু করতে সেটিংসে একটি মডিউল চালু করুন",
  "commonSave": "সংরক্ষণ করুন",
```

Replace it with (the night bucket deliberately reads as "Hello," not a
literal "Good night" — Bangla conventionally uses "শুভ রাত্রি" as a
farewell, not a greeting):

```json
  "emptyDashboardMessage": "শুরু করতে সেটিংসে একটি মডিউল চালু করুন",
  "dashboardGreetingMorning": "শুভ সকাল",
  "dashboardGreetingMorningNamed": "শুভ সকাল, {name}",
  "dashboardGreetingAfternoon": "শুভ দুপুর",
  "dashboardGreetingAfternoonNamed": "শুভ দুপুর, {name}",
  "dashboardGreetingEvening": "শুভ সন্ধ্যা",
  "dashboardGreetingEveningNamed": "শুভ সন্ধ্যা, {name}",
  "dashboardGreetingNight": "হ্যালো",
  "dashboardGreetingNightNamed": "হ্যালো, {name}",
  "commonSave": "সংরক্ষণ করুন",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors.

- [ ] **Step 3: Write the failing dashboard test**

`test/features/dashboard/dashboard_screen_test.dart` currently pumps
`DashboardScreen` with only `habitModulesProvider` overridden — the new
greeting widget also watches `appSettingsProvider`, which (unless
overridden) would try to open a real on-disk `AppDatabase` via
`path_provider` and hang/fail under `flutter test`. Update the shared
`_pump` helper to override `databaseProvider` too, for every existing
test in the file, not just the new one.

Change:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
```

to:

```dart
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
```

Change:

```dart
Future<void> _pump(WidgetTester tester, List<HabitModule> modules) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [habitModulesProvider.overrideWith((ref) => modules)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('0 modules: shows the empty state, no summary cards', (
    tester,
  ) async {
    await _pump(tester, []);
    expect(find.textContaining('summary'), findsNothing);
  });

  testWidgets("1 module: shows exactly that module's summary card", (
    tester,
  ) async {
    await _pump(tester, [_FakeModule('water')]);
    expect(find.text('water summary'), findsOneWidget);
  });

  testWidgets('3 modules: shows all three summary cards', (tester) async {
    await _pump(tester, [
      _FakeModule('water'),
      _FakeModule('medicine'),
      _FakeModule('prayer'),
    ]);
    expect(find.text('water summary'), findsOneWidget);
    expect(find.text('medicine summary'), findsOneWidget);
    expect(find.text('prayer summary'), findsOneWidget);
  });
}
```

to:

```dart
Future<void> _pump(
  WidgetTester tester,
  List<HabitModule> modules,
  AppDatabase db,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitModulesProvider.overrideWith((ref) => modules),
        databaseProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('0 modules: shows the empty state, no summary cards', (
    tester,
  ) async {
    await _pump(tester, [], db);
    expect(find.textContaining('summary'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets("1 module: shows exactly that module's summary card", (
    tester,
  ) async {
    await _pump(tester, [_FakeModule('water')], db);
    expect(find.text('water summary'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('3 modules: shows all three summary cards', (tester) async {
    await _pump(
      tester,
      [_FakeModule('water'), _FakeModule('medicine'), _FakeModule('prayer')],
      db,
    );
    expect(find.text('water summary'), findsOneWidget);
    expect(find.text('medicine summary'), findsOneWidget);
    expect(find.text('prayer summary'), findsOneWidget);
    await disposeTree(tester);
  });

  group('dashboard greeting', () {
    testWidgets('morning, no display name set: shows the name-less '
        'morning greeting', (tester) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 8)), () async {
        await _pump(tester, [_FakeModule('water')], db);
        expect(find.text('Good morning'), findsOneWidget);
      });
      await disposeTree(tester);
    });

    testWidgets('evening, display name set: shows the named evening '
        'greeting', (tester) async {
      final repo = SettingsRepositoryImpl(db);
      await repo.updateDisplayName('Nadia');

      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 18)), () async {
        await _pump(tester, [_FakeModule('water')], db);
        expect(find.text('Good evening, Nadia'), findsOneWidget);
      });
      await disposeTree(tester);
    });

    testWidgets('night bucket: shows the name-less night greeting', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 23)), () async {
        await _pump(tester, [_FakeModule('water')], db);
        expect(find.text('Hello'), findsOneWidget);
      });
      await disposeTree(tester);
    });
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/dashboard/dashboard_screen_test.dart | tail -10`
Expected: FAIL — the 3 greeting tests can't find their expected text (no
`_DashboardGreeting` widget exists yet); the 3 pre-existing tests should
still compile and pass since the helper change is additive.

- [ ] **Step 5: Write minimal implementation**

In `lib/features/dashboard/presentation/screens/dashboard_screen.dart`,
add the imports (alongside the existing ones):

```dart
import 'package:clock/clock.dart';
import 'package:habit_tracker/core/utils/greeting.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
```

Change:

```dart
      body: modules.isEmpty
          ? Center(child: Text(l10n.emptyDashboardMessage))
          : MaxContentWidth(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _DayCompletionIndicator(modules: modules),
                  const SizedBox(height: 16),
```

to:

```dart
      body: modules.isEmpty
          ? Center(child: Text(l10n.emptyDashboardMessage))
          : MaxContentWidth(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _DashboardGreeting(),
                  const SizedBox(height: 8),
                  _DayCompletionIndicator(modules: modules),
                  const SizedBox(height: 16),
```

Add the new `_DashboardGreeting` widget right after the
`DashboardScreen` class, before `_DayCompletionIndicator`:

```dart
class _DashboardGreeting extends ConsumerWidget {
  const _DashboardGreeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final name = ref.watch(appSettingsProvider).value?.displayName;
    final period = greetingPeriodFor(clock.now());
    final text = switch ((period, name)) {
      (GreetingPeriod.morning, final String n?) =>
        l10n.dashboardGreetingMorningNamed(n),
      (GreetingPeriod.morning, null) => l10n.dashboardGreetingMorning,
      (GreetingPeriod.afternoon, final String n?) =>
        l10n.dashboardGreetingAfternoonNamed(n),
      (GreetingPeriod.afternoon, null) => l10n.dashboardGreetingAfternoon,
      (GreetingPeriod.evening, final String n?) =>
        l10n.dashboardGreetingEveningNamed(n),
      (GreetingPeriod.evening, null) => l10n.dashboardGreetingEvening,
      (GreetingPeriod.night, final String n?) =>
        l10n.dashboardGreetingNightNamed(n),
      (GreetingPeriod.night, null) => l10n.dashboardGreetingNight,
    };
    return Text(text, style: Theme.of(context).textTheme.headlineSmall);
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/dashboard/dashboard_screen_test.dart | tail -10`
Expected: `+6: All tests passed!`

- [ ] **Step 7: Analyze, format, and full sweep**

Run: `flutter analyze lib/features/dashboard/ | tail -10`
Run: `dart format lib/features/dashboard/`
Expected: `No issues found!`

Run: `flutter test test/widget_test.dart | tail -10`
Expected: PASS — confirms `HabitTrackerApp`'s real boot path (which
renders the real `DashboardScreen`) still works with the greeting wired
in.

- [ ] **Step 8: Commit**

```bash
git add lib/features/dashboard/presentation/screens/dashboard_screen.dart \
  lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  test/features/dashboard/dashboard_screen_test.dart
git commit -m "feat(dashboard): show a time-of-day-aware personalized greeting"
```

---

## After all tasks

Per this repo's CLAUDE.md spec-implementation workflow: once every task
above is committed, open a PR for the spec with the design summary in the
description, then run a code review against the finished PR (comment →
fix → commit cycle, up to 5 rounds), then stop and wait for the user's
own review and merge.

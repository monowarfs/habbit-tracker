# "Why This Matters" Micro-Education Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two small, dismissible, non-modal "why this matters" cards
(Water hydration science, Prayer Qadha context) that each show at most
once, per `docs/superpowers/specs/02-delightful/
06-why-this-matters-micro-education-cards-design.md`.

**Architecture:** Two new nullable epoch-millis `IntColumn`s on
`AppSettingsTable` (`waterHydrationHintSeenAt`/`prayerQadhaHintSeenAt`),
following the exact `onboardingCompletedAt` convention — not a new
table, not `shared_preferences`. One new reusable widget
(`DismissibleHintCard`, plain `Card`/`ListTile`, no `MaterialBanner`).
Both call sites (`WaterSettingsScreen`, `PrayerQadhaScreen`) are already
`ConsumerWidget`s reading the already-streamed `AppSettings` — visibility
is `if (appSettings?.xHintSeenAt == null)`, no new state class needed.

**Tech Stack:** Flutter/Riverpod (codegen), Drift (codegen), `gen_l10n`,
`flutter_test`.

## Global Constraints

- No new dependency — `Card`/`ListTile`/`IconButton` are already-used
  Flutter SDK widgets; no `shared_preferences`.
- **Schema migration coordination (read this before touching
  `schemaVersion`):** Read `lib/core/database/app_database.dart`'s
  current `schemaVersion` value. As of this plan being written it is
  `7`. If it is still `7` when you implement this task, bump it to `8`
  and add a new `if (from < 8) { ... }` migration block containing your
  two `addColumn` calls. If it is already `8` (because
  `11-personalized-dashboard-greeting-design.md`'s `displayName` or
  `12-seasonal-theme-accents-design.md`'s `seasonalAccentsEnabled` was
  implemented first), add your two `addColumn` calls inside that
  existing `if (from < 8)` block instead of bumping to `9`.
- New nullable `IntColumn`s: `waterHydrationHintSeenAt`,
  `prayerQadhaHintSeenAt` (UTC epoch millis, no default — matches
  `onboardingCompletedAt`'s existing nullable-no-default shape).
- `SettingsRepository.restoreSettings` (the import/replace path)
  intentionally does **not** restore these two new fields — same
  treatment as `onboardingCompletedAt`. Since both new `AppSettings`
  fields are nullable and not `required`, no call site that constructs
  `AppSettings(...)` (including `import_orchestrator.dart`'s
  `applyImport`) needs to change — verified by `flutter analyze` in
  Task 1.
- New l10n keys (both `app_en.arb`/`app_bn.arb`): `waterHydrationHintCard`,
  `prayerQadhaHintCard`. No new key for the dismiss button's tooltip —
  reuses `MaterialLocalizations.of(context).closeButtonTooltip`, an
  existing Flutter SDK localization.
- Per this repo's CLAUDE.md spec-implementation workflow: one commit per
  task, run only that task's own test file (never the full `flutter
  test` suite mid-task), pipe `build_runner`/`test`/`gen-l10n` output
  through `| tail -10`.

---

### Task 1: Data layer — schema, entity, repository

**Files:**
- Modify: `lib/core/database/tables/app_settings_table.dart`
- Modify: `lib/core/database/app_database.dart:54,100-106`
- Modify: `lib/features/settings/domain/entities/app_settings.dart:45-59`
- Modify: `lib/features/settings/domain/repositories/settings_repository.dart`
- Modify: `lib/features/settings/data/repositories/settings_repository_impl.dart`
- Test: `test/features/settings/data/repositories/settings_repository_impl_test.dart`

**Interfaces:**
- Produces: `AppSettings.waterHydrationHintSeenAt` (`DateTime?`),
  `AppSettings.prayerQadhaHintSeenAt` (`DateTime?`) — consumed by
  Task 3/4's screen wiring.
- Produces: `SettingsRepository.markWaterHydrationHintSeen()`,
  `SettingsRepository.markPrayerQadhaHintSeen()` (both
  `Future<Result<void>>`, no params) — consumed by Task 3/4.

- [ ] **Step 1: Write the failing repository test**

Add to `test/features/settings/data/repositories/settings_repository_impl_test.dart`,
inside the existing `test(...)` block, right after the existing
`expect(firstRead.screenPrivacyEnabled, isFalse);` line:

```dart
    expect(firstRead.waterHydrationHintSeenAt, isNull);
    expect(firstRead.prayerQadhaHintSeenAt, isNull);
```

And right after the existing `expect(privacyResult, isA<Success<void>>());`
block (before `await db1.close();`), add:

```dart
    final waterHintResult = await repo1.markWaterHydrationHintSeen();
    expect(waterHintResult, isA<Success<void>>());
    final prayerHintResult = await repo1.markPrayerQadhaHintSeen();
    expect(prayerHintResult, isA<Success<void>>());
```

And right after the existing `expect(afterRestart.screenPrivacyEnabled, isTrue);`,
add:

```dart
    expect(afterRestart.waterHydrationHintSeenAt, isNotNull);
    expect(afterRestart.prayerQadhaHintSeenAt, isNotNull);
```

- [ ] **Step 2: Run it, confirm it fails to compile**

Run: `flutter test test/features/settings/data/repositories/settings_repository_impl_test.dart | tail -10`
Expected: compile error — `waterHydrationHintSeenAt`/
`prayerQadhaHintSeenAt`/`markWaterHydrationHintSeen`/
`markPrayerQadhaHintSeen` don't exist yet.

- [ ] **Step 3: Add the DB columns**

In `lib/core/database/tables/app_settings_table.dart`, add after the
`lastSeenAppVersion` column (before `createdAt`):

```dart
  /// UTC epoch millis; null = the Water hydration-science "why this
  /// matters" card hasn't been shown yet (`docs/superpowers/specs/
  /// 02-delightful/06-why-this-matters-micro-education-cards-design.md`).
  IntColumn get waterHydrationHintSeenAt => integer().nullable()();

  /// UTC epoch millis; null = the Prayer Qadha-context "why this
  /// matters" card hasn't been shown yet.
  IntColumn get prayerQadhaHintSeenAt => integer().nullable()();
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
        // "Why this matters" micro-education card dismissal flags.
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.waterHydrationHintSeenAt,
        );
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.prayerQadhaHintSeenAt,
        );
      }
```

- **If it is already `8`** (because `11-personalized-dashboard-greeting
  -design.md`'s `displayName` or `12-seasonal-theme-accents-design.md`'s
  `seasonalAccentsEnabled` shipped first), do **not** bump to `9` —
  instead add your two `addColumn` calls inside that already-existing
  `if (from < 8) { ... }` block, alongside whatever column(s) that
  other spec already added there.

Either way, the end state is: exactly one `if (from < 8)` block exists
in `onUpgrade`, and it contains `addColumn` calls for every field any of
the three specs (this one, 11, 12) introduced at schema version 8.

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
    DateTime? waterHydrationHintSeenAt,
    DateTime? prayerQadhaHintSeenAt,
  }) = _AppSettings;
```

Both new fields are nullable and not `required` (same shape as
`onboardingCompletedAt`) — no existing `AppSettings(...)` call site
(including `import_orchestrator.dart`'s `applyImport`, which doesn't
pass `onboardingCompletedAt` either) needs to change for this to
compile.

- [ ] **Step 6: Add the repository interface methods**

In `lib/features/settings/domain/repositories/settings_repository.dart`,
add after `updateQuietHours`:

```dart
  /// Marks the Water hydration-science "why this matters" card as shown
  /// — it never renders again after this.
  Future<Result<void>> markWaterHydrationHintSeen();

  /// Marks the Prayer Qadha-context "why this matters" card as shown —
  /// it never renders again after this.
  Future<Result<void>> markPrayerQadhaHintSeen();
```

- [ ] **Step 7: Implement them and wire `_toDomain`**

In `lib/features/settings/data/repositories/settings_repository_impl.dart`,
add after `updateQuietHours`'s implementation:

```dart
  @override
  Future<Result<void>> markWaterHydrationHintSeen() => _update(
    AppSettingsTableCompanion(
      waterHydrationHintSeenAt: Value(
        clock.now().toUtc().millisecondsSinceEpoch,
      ),
    ),
  );

  @override
  Future<Result<void>> markPrayerQadhaHintSeen() => _update(
    AppSettingsTableCompanion(
      prayerQadhaHintSeenAt: Value(
        clock.now().toUtc().millisecondsSinceEpoch,
      ),
    ),
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
    waterHydrationHintSeenAt: row.waterHydrationHintSeenAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.waterHydrationHintSeenAt!,
            isUtc: true,
          ),
    prayerQadhaHintSeenAt: row.prayerQadhaHintSeenAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.prayerQadhaHintSeenAt!,
            isUtc: true,
          ),
  );
```

`restoreSettings`'s `AppSettingsTableCompanion(...)` write is deliberately
**not** touched — per the Global Constraints, a fresh import shouldn't
silently suppress a card the new installation hasn't actually shown yet
(same reasoning `onboardingCompletedAt` already gets, and that field is
likewise absent from `restoreSettings`'s companion).

- [ ] **Step 8: Regenerate code**

Run: `dart run build_runner build --delete-conflicting-outputs | tail -10`
Expected: exits 0, regenerates `app_settings.freezed.dart` and
`app_database.g.dart` (both gitignored, not committed) with the new
fields/columns.

- [ ] **Step 9: Run the test, confirm it passes**

Run: `flutter test test/features/settings/data/repositories/settings_repository_impl_test.dart | tail -10`
Expected: `+1: All tests passed!`

- [ ] **Step 10: Analyze**

Run: `flutter analyze | tail -10`
Expected: `No issues found!` — this confirms no call site that
constructs `AppSettings(...)` (in particular
`import_orchestrator.dart`'s `applyImport`) broke, since both new
fields are optional.

- [ ] **Step 11: Commit**

```bash
git add lib/core/database/tables/app_settings_table.dart \
  lib/core/database/app_database.dart \
  lib/features/settings/domain/entities/app_settings.dart \
  lib/features/settings/domain/repositories/settings_repository.dart \
  lib/features/settings/data/repositories/settings_repository_impl.dart \
  test/features/settings/data/repositories/settings_repository_impl_test.dart
git commit -m "feat(settings): add waterHydrationHintSeenAt/prayerQadhaHintSeenAt flags"
```

---

### Task 2: `DismissibleHintCard` widget

**Files:**
- Create: `lib/core/widgets/dismissible_hint_card.dart`
- Test: `test/core/widgets/dismissible_hint_card_test.dart`

**Interfaces:**
- Produces: `class DismissibleHintCard extends StatelessWidget` with
  `const DismissibleHintCard({required String message, required
  VoidCallback onDismiss, Key? key})` — consumed by Task 3/4's screen
  wiring.

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/dismissible_hint_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/dismissible_hint_card.dart';

void main() {
  testWidgets(
    'shows the message and calls onDismiss when the close button is tapped',
    (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DismissibleHintCard(
              message: 'Water helps regulate temperature.',
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('Water helps regulate temperature.'), findsOneWidget);
      expect(dismissed, isFalse);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(dismissed, isTrue);
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/dismissible_hint_card_test.dart | tail -10`
Expected: FAIL to compile — `lib/core/widgets/dismissible_hint_card.dart`
doesn't exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/widgets/dismissible_hint_card.dart`:

```dart
import 'package:flutter/material.dart';

/// A one-line, dismissible, non-modal educational card
/// (`docs/superpowers/specs/02-delightful/
/// 06-why-this-matters-micro-education-cards-design.md`). The caller
/// owns whether to render it at all (checked against the relevant
/// `*HintSeenAt` `AppSettings` field being null) and wires [onDismiss]
/// to the matching `mark*HintSeen()` repository call, so a dismissal
/// persists and this never shows again.
class DismissibleHintCard extends StatelessWidget {
  /// Creates a dismissible hint card showing [message].
  const DismissibleHintCard({
    required this.message,
    required this.onDismiss,
    super.key,
  });

  /// The one-line educational copy to show.
  final String message;

  /// Called when the user taps the close button.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.lightbulb_outline),
      title: Text(message),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onDismiss,
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      ),
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/dismissible_hint_card_test.dart | tail -10`
Expected: `+1: All tests passed!`

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/core/widgets/dismissible_hint_card.dart | tail -10`
Run: `dart format lib/core/widgets/dismissible_hint_card.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/dismissible_hint_card.dart \
  test/core/widgets/dismissible_hint_card_test.dart
git commit -m "feat(core): add DismissibleHintCard, a one-shot inline hint widget"
```

---

### Task 3: Wire the hydration hint into `WaterSettingsScreen`

**Files:**
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Modify: `lib/features/water/presentation/screens/water_settings_screen.dart:1-59`
- Test: `test/features/water/presentation/water_settings_screen_test.dart`

**Interfaces:**
- Consumes: `AppSettings.waterHydrationHintSeenAt`,
  `SettingsRepository.markWaterHydrationHintSeen()` (Task 1),
  `DismissibleHintCard` (Task 2).

- [ ] **Step 1: Add the l10n key to both arb files**

In `lib/core/l10n/app_en.arb`, insert after the `"waterPresetActive"`
block (immediately before `"medicineHomeEmpty"`) — find this exact
anchor text:

```json
  "waterPresetActive": "Active · 3L",
  "@waterPresetActive": {
    "description": "Water goal preset chip: 3000ml/day."
  },
  "medicineHomeEmpty": "No doses scheduled for today",
```

Replace it with:

```json
  "waterPresetActive": "Active · 3L",
  "@waterPresetActive": {
    "description": "Water goal preset chip: 3000ml/day."
  },
  "waterHydrationHintCard": "Water helps regulate temperature, joints, and energy — most adults need roughly 2-3 liters a day, more if it's hot or you're active.",
  "@waterHydrationHintCard": {
    "description": "One-time \"why this matters\" hint card on the Water settings screen, explaining the health rationale for a daily water goal."
  },
  "medicineHomeEmpty": "No doses scheduled for today",
```

In `lib/core/l10n/app_bn.arb`, insert after the `"waterPresetActive"`
line (immediately before `"medicineHomeEmpty"`) — find this exact anchor
text:

```json
  "waterPresetActive": "সক্রিয় · ৩ লি",
  "medicineHomeEmpty": "আজকের জন্য কোনো ডোজ নির্ধারিত নেই",
```

Replace it with:

```json
  "waterPresetActive": "সক্রিয় · ৩ লি",
  "waterHydrationHintCard": "পানি শরীরের তাপমাত্রা, জয়েন্ট এবং শক্তি নিয়ন্ত্রণে সাহায্য করে — বেশিরভাগ প্রাপ্তবয়স্কদের দিনে প্রায় ২-৩ লিটার পানি প্রয়োজন, গরমে বা সক্রিয় থাকলে আরও বেশি।",
  "medicineHomeEmpty": "আজকের জন্য কোনো ডোজ নির্ধারিত নেই",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors; `AppLocalizations.waterHydrationHintCard` getter
appears.

- [ ] **Step 3: Write the failing widget test**

Add to `test/features/water/presentation/water_settings_screen_test.dart`,
new import at the top:

```dart
import 'package:habit_tracker/core/widgets/dismissible_hint_card.dart';
```

and a new test inside `main()`, after the existing two `testWidgets`:

```dart
  testWidgets(
    'shows the hydration hint card until dismissed, then never again',
    (tester) async {
      await _pumpWaterSettings(tester, db);

      expect(
        find.text(
          "Water helps regulate temperature, joints, and energy — most "
          "adults need roughly 2-3 liters a day, more if it's hot or "
          "you're active.",
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(DismissibleHintCard), findsNothing);

      // Rebuilding the screen from scratch (simulating navigating back to
      // it later) must not show it again — the dismissal persisted to
      // the DB, not just local widget state.
      await disposeTree(tester);
      await _pumpWaterSettings(tester, db);
      expect(find.byType(DismissibleHintCard), findsNothing);

      await disposeTree(tester);
    },
  );
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/water/presentation/water_settings_screen_test.dart | tail -10`
Expected: FAIL — the hint text isn't found (the card doesn't exist yet
on this screen).

- [ ] **Step 5: Wire the card into `WaterSettingsScreen`**

In `lib/features/water/presentation/screens/water_settings_screen.dart`,
change the import block from:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/notifications/notification_permission_explainer_screen.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/domain/water_goal_presets.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';
```

to:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/notifications/notification_permission_explainer_screen.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/dismissible_hint_card.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/water/domain/water_goal_presets.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';
```

Change:

```dart
    final goal = ref.watch(currentWaterGoalProvider).value;
    final settings = ref.watch(waterSettingsProvider).value;
    final controller = ref.read(waterControllerProvider.notifier);

    if (goal == null || settings == null) {
```

to:

```dart
    final goal = ref.watch(currentWaterGoalProvider).value;
    final settings = ref.watch(waterSettingsProvider).value;
    final controller = ref.read(waterControllerProvider.notifier);
    final appSettings = ref.watch(appSettingsProvider).value;

    if (goal == null || settings == null) {
```

Change:

```dart
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final preset in waterGoalPresets)
```

to:

```dart
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (appSettings?.waterHydrationHintSeenAt == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DismissibleHintCard(
                message: l10n.waterHydrationHintCard,
                onDismiss: () => ref
                    .read(settingsRepositoryProvider)
                    .markWaterHydrationHintSeen(),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              for (final preset in waterGoalPresets)
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/water/presentation/water_settings_screen_test.dart | tail -10`
Expected: `+3: All tests passed!` (the 2 pre-existing preset tests plus
this one).

- [ ] **Step 7: Analyze and format**

Run: `flutter analyze lib/features/water/presentation/screens/water_settings_screen.dart | tail -10`
Run: `dart format lib/features/water/presentation/screens/water_settings_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  lib/features/water/presentation/screens/water_settings_screen.dart \
  test/features/water/presentation/water_settings_screen_test.dart
git commit -m "feat(water): show the hydration \"why this matters\" hint card once"
```

---

### Task 4: Wire the Qadha hint into `PrayerQadhaScreen`

**Files:**
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Modify: `lib/features/prayer/presentation/screens/prayer_qadha_screen.dart:1-54`
- Test: `test/features/prayer/presentation/prayer_qadha_screen_test.dart`

**Interfaces:**
- Consumes: `AppSettings.prayerQadhaHintSeenAt`,
  `SettingsRepository.markPrayerQadhaHintSeen()` (Task 1),
  `DismissibleHintCard` (Task 2).

- [ ] **Step 1: Add the l10n key to both arb files**

In `lib/core/l10n/app_en.arb`, insert after the
`"prayerQadhaEditButton"` block (immediately before `"prayerStatsTitle"`)
— find this exact anchor text:

```json
  "prayerQadhaEditButton": "Set balance",
  "@prayerQadhaEditButton": {"description": "Tooltip/title for the manual Qadha balance entry dialog."},
  "prayerStatsTitle": "Prayer stats",
```

Replace it with:

```json
  "prayerQadhaEditButton": "Set balance",
  "@prayerQadhaEditButton": {"description": "Tooltip/title for the manual Qadha balance entry dialog."},
  "prayerQadhaHintCard": "Qadha lets you make up a missed prayer later — it's a normal part of practice, not a separate obligation on top of your regular five.",
  "@prayerQadhaHintCard": {"description": "One-time \"why this matters\" hint card on the Qadha screen, explaining what Qadha is for."},
  "prayerStatsTitle": "Prayer stats",
```

In `lib/core/l10n/app_bn.arb`, insert after the `"prayerQadhaEditButton"`
line (immediately before `"prayerStatsTitle"`) — find this exact anchor
text:

```json
  "prayerQadhaEditButton": "ব্যালেন্স নির্ধারণ করুন",
  "prayerStatsTitle": "নামাজের পরিসংখ্যান",
```

Replace it with:

```json
  "prayerQadhaEditButton": "ব্যালেন্স নির্ধারণ করুন",
  "prayerQadhaHintCard": "কাজা আপনাকে পরে একটি ছুটে যাওয়া নামাজ আদায় করার সুযোগ দেয় — এটি অনুশীলনের একটি স্বাভাবিক অংশ, আপনার নিয়মিত পাঁচ ওয়াক্তের বাইরে আলাদা কোনো দায়িত্ব নয়।",
  "prayerStatsTitle": "নামাজের পরিসংখ্যান",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors; `AppLocalizations.prayerQadhaHintCard` getter
appears.

- [ ] **Step 3: Write the failing widget test**

Create `test/features/prayer/presentation/prayer_qadha_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/dismissible_hint_card.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_qadha_screen.dart';

Future<void> _pumpPrayerQadha(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PrayerQadhaScreen(),
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

  testWidgets(
    'shows the Qadha hint card until dismissed, then never again',
    (tester) async {
      // Seeds the 5 Qadha counters (mirrors prayer_repository_impl_test
      // .dart's own seeding precedent — the singleton settings row's
      // first read seeds them) so the screen has real rows below the
      // hint card, not just an empty list.
      await PrayerRepositoryImpl(db).watchSettings().first;

      await _pumpPrayerQadha(tester, db);

      expect(
        find.text(
          "Qadha lets you make up a missed prayer later — it's a normal "
          'part of practice, not a separate obligation on top of your '
          'regular five.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(DismissibleHintCard), findsNothing);

      await disposeTree(tester);
      await _pumpPrayerQadha(tester, db);
      expect(find.byType(DismissibleHintCard), findsNothing);

      await disposeTree(tester);
    },
  );
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/prayer/presentation/prayer_qadha_screen_test.dart | tail -10`
Expected: FAIL — the hint text isn't found (the card doesn't exist yet
on this screen).

- [ ] **Step 5: Wire the card into `PrayerQadhaScreen`**

In `lib/features/prayer/presentation/screens/prayer_qadha_screen.dart`,
change the import block from:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_controller.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/dismissible_hint_card.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_qadha_counter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_controller.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
```

Change:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final counters = ref.watch(prayerQadhaCountersProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.prayerQadhaTitle)),
      body: ListView(
        children: [
          for (final counter in counters)
```

to:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final counters = ref.watch(prayerQadhaCountersProvider).value ?? const [];
    final appSettings = ref.watch(appSettingsProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.prayerQadhaTitle)),
      body: ListView(
        children: [
          if (appSettings?.prayerQadhaHintSeenAt == null)
            DismissibleHintCard(
              message: l10n.prayerQadhaHintCard,
              onDismiss: () => ref
                  .read(settingsRepositoryProvider)
                  .markPrayerQadhaHintSeen(),
            ),
          for (final counter in counters)
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/prayer/presentation/prayer_qadha_screen_test.dart | tail -10`
Expected: `+1: All tests passed!`

- [ ] **Step 7: Analyze and format**

Run: `flutter analyze lib/features/prayer/presentation/screens/prayer_qadha_screen.dart | tail -10`
Run: `dart format lib/features/prayer/presentation/screens/prayer_qadha_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  lib/features/prayer/presentation/screens/prayer_qadha_screen.dart \
  test/features/prayer/presentation/prayer_qadha_screen_test.dart
git commit -m "feat(prayer): show the Qadha \"why this matters\" hint card once"
```

---

## After all tasks

Per this repo's CLAUDE.md spec-implementation workflow: once every task
above is committed, open a PR for the spec with the design summary in
the description, then run a code review against the finished PR
(comment → fix → commit cycle, up to 5 rounds), then stop and wait for
the user's own review and merge.

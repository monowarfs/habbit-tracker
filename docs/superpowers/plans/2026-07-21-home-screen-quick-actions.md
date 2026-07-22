# Home Screen Quick Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Android app shortcuts / iOS Home Screen Quick Actions — a
fixed, static set of 3 (Water/Medicine/Prayer), each performing one headless
action and then opening that module, per
`docs/superpowers/specs/2026-07-21-06-home-screen-quick-actions-design.md`.

**Architecture:** New `HabitModule.onQuickAction()` method (sibling to the
existing `onNotificationAction`), implemented headlessly by all three
modules exactly the way `onNotificationAction` already bypasses controllers.
A new `core/shortcuts/quick_action_handler.dart` dispatcher mirrors
`core/notifications/notification_action_handler.dart`'s `_dispatch`. The
`quick_actions` plugin's single `initialize(handler)` callback (wired in
`main()`) covers both cold and warm launches; `setShortcutItems(...)` is
(re-)registered from `HabitTrackerApp.build()`, keyed off
`localeControllerProvider` so labels stay in the user's language — the same
`ref.listen`-in-`build()` precedent `screenPrivacyEnabled` already uses.

**Tech Stack:** Flutter, Riverpod (codegen), `quick_actions: ^1.1.0`,
existing `gen_l10n` localization.

## Global Constraints

- New dependency: `quick_actions` (pubspec.yaml), version `^1.1.0`.
- New `HabitModule` method: `Future<void> onQuickAction();` — implemented by
  Water/Medicine/Prayer, headless (no `Ref`), same constraint
  `onNotificationAction` already documents on the interface.
- New file: `lib/core/shortcuts/quick_action_handler.dart` (dispatcher,
  mirrors `notification_action_handler.dart`'s `_dispatch`).
- Shortcut `type` strings are exactly the existing `HabitModule.id` values
  (`'water'`, `'medicine'`, `'prayer'`) — no separate id scheme.
- Exactly 3 static shortcuts registered, one per module, no dynamic content.
- `QuickActions.initialize(...)` wired in `main()` next to
  `NotificationBootstrap.init(...)`; `setShortcutItems(...)` (re-)called
  from `HabitTrackerApp.build()`'s existing `ref.listen` block area,
  keyed off `localeControllerProvider`.
- Actual native icon assets (Android drawable / iOS asset-catalog) are out
  of scope per the spec — `ShortcutItem.icon` is `null` for all 3 items in
  v1. This is a real, deliberate decision (not a placeholder): the spec's
  "Out of scope" section explicitly defers icon-asset creation to a
  separate design/asset task.

---

### Task 1: `HabitModule.onQuickAction()` + Water/Medicine/Prayer implementations

**Files:**
- Modify: `lib/core/modules/habit_module.dart` (add abstract method)
- Modify: `lib/features/water/water_module.dart`
- Modify: `lib/features/medicine/medicine_module.dart`
- Modify: `lib/features/prayer/prayer_module.dart` (new import needed)
- Test: `test/features/water/water_module_test.dart` (append)
- Test: `test/features/medicine/medicine_module_test.dart` (append)
- Test: `test/features/prayer/prayer_module_test.dart` (append)

**Interfaces:**
- Consumes: `WaterRepository.watchSettings()`/`addEntry(...)` (existing);
  `MedicineRepository.dosesInRange(LocalDate, LocalDate)`/`markDoseDone(String
  doseId, {required bool fromOtherSource})` (existing);
  `effectiveDoseStatus({required storedStatus, required scheduledFor,
  required now, required graceWindowMinutes})` from
  `lib/features/medicine/domain/usecases/dose_status.dart` (existing);
  `PrayerRepository.watchSettings()`/`recordsInRange(LocalDate,
  LocalDate)`/`markPrayed(String recordId)` (existing);
  `effectivePrayerStatus({required storedStatus, required scheduledFor,
  required cutoff, required now})` and `cutoffForPrayer({required record,
  required sameDayRecordsSorted, required ishaDayRolloverTime,
  ianaTimezone})` from
  `lib/features/prayer/domain/usecases/effective_prayer_status.dart`
  (existing); `resolveLocation(PrayerSettings)` from
  `lib/features/prayer/data/location_resolver.dart` (existing, already
  imported in `prayer_module.dart`).
- Produces: `Future<void> onQuickAction()` on `HabitModule` and all three
  concrete modules — consumed by Task 2's dispatcher.

- [ ] **Step 1: Add the abstract method to `HabitModule`**

In `lib/core/modules/habit_module.dart`, add directly below
`onNotificationAction`'s declaration (after its closing `);` around line
217):

```dart
  /// Performs this module's one fixed, unconditional quick action — the
  /// headless equivalent of what [quickActions]'s single chip does when
  /// visible, triggered by an OS home-screen/app shortcut tap
  /// (`core/shortcuts/quick_action_handler.dart`). Runs with no `Ref` and no
  /// `BuildContext`, same constraint as [onNotificationAction]. Modules with
  /// nothing due no-op rather than throwing.
  Future<void> onQuickAction();
```

- [ ] **Step 2: Implement `WaterModule.onQuickAction`**

In `lib/features/water/water_module.dart`, add directly below
`onNotificationAction` (after its closing `}` around line 184):

```dart
  @override
  Future<void> onQuickAction() async {
    final settings = await _repository.watchSettings().first;
    final amountMl = settings.quickAddAmountsMl.isEmpty
        ? 250
        : settings.quickAddAmountsMl.first;
    await _repository.addEntry(
      amountMl: amountMl,
      loggedAt: clock.now(),
      source: WaterEntrySource.quick,
    );
  }
```

- [ ] **Step 3: Write the failing test for `WaterModule.onQuickAction`**

In `test/features/water/water_module_test.dart`, add after the
`'onNotificationAction(snooze/skip) never logs an entry'` test:

```dart
  test(
    'onQuickAction logs a quick entry of the first quick-add amount',
    () async {
      final repo = _FakeWaterRepository(_settings(reminderEnabled: true));
      final module = WaterModule(repo);

      await module.onQuickAction();

      expect(repo.capturedAmountMl, 250);
      expect(repo.capturedSource, WaterEntrySource.quick);
    },
  );
```

- [ ] **Step 4: Run the Water module test**

Run: `flutter test test/features/water/water_module_test.dart | tail -10`
Expected: all tests PASS (this is additive to an already-passing file, so
there's no separate "verify it fails first" step — `onQuickAction` doesn't
exist yet on `HabitModule` until Step 1, so compiling this file before Step
1/2 land would fail with "The method 'onQuickAction' isn't defined"; run
this only after Steps 1-2 are also in place).

- [ ] **Step 5: Implement `MedicineModule.onQuickAction`**

In `lib/features/medicine/medicine_module.dart`, add directly below
`onNotificationAction` (after its closing `}` around line 209):

```dart
  @override
  Future<void> onQuickAction() async {
    final now = clock.now();
    final today = localDayKey(now);
    final doses = await _repository.dosesInRange(today, today);
    final sorted = [...doses]
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    for (final dose in sorted) {
      final status = effectiveDoseStatus(
        storedStatus: dose.storedStatus,
        scheduledFor: dose.scheduledFor,
        now: now,
        graceWindowMinutes: dose.graceWindowMinutes,
      );
      if (status == MedicineDoseStatus.due) {
        await _repository.markDoseDone(dose.id, fromOtherSource: false);
        return;
      }
    }
  }
```

- [ ] **Step 6: Write the failing tests for `MedicineModule.onQuickAction`**

In `test/features/medicine/medicine_module_test.dart`, add after the
`'onNotificationAction(snooze) never mutates dose data'` test:

```dart
  test(
    'onQuickAction marks the earliest due dose done and ignores others',
    () async {
      final now = DateTime.utc(2026, 6, 1, 9);
      final dueDose = MedicineDose(
        id: 'd-due',
        medicineId: 'm1',
        scheduleId: 's1',
        scheduledFor: DateTime.utc(2026, 6, 1, 8),
        storedStatus: MedicineDoseStatus.upcoming,
        graceWindowMinutes: 30,
      );
      final upcomingDose = MedicineDose(
        id: 'd-upcoming',
        medicineId: 'm1',
        scheduleId: 's1',
        scheduledFor: DateTime.utc(2026, 6, 1, 20),
        storedStatus: MedicineDoseStatus.upcoming,
        graceWindowMinutes: 30,
      );
      when(
        () => repo.dosesInRange(any(), any()),
      ).thenAnswer((_) async => [upcomingDose, dueDose]);
      when(
        () => repo.markDoseDone(
          any(),
          fromOtherSource: any(named: 'fromOtherSource'),
        ),
      ).thenAnswer((_) async => const Result.success(null));

      await withClock(Clock.fixed(now), () async {
        await module.onQuickAction();
      });

      verify(
        () => repo.markDoseDone('d-due', fromOtherSource: false),
      ).called(1);
      verifyNever(
        () => repo.markDoseDone(
          'd-upcoming',
          fromOtherSource: any(named: 'fromOtherSource'),
        ),
      );
    },
  );

  test('onQuickAction no-ops when nothing is due', () async {
    when(() => repo.dosesInRange(any(), any())).thenAnswer((_) async => []);

    await module.onQuickAction();

    verifyNever(
      () => repo.markDoseDone(
        any(),
        fromOtherSource: any(named: 'fromOtherSource'),
      ),
    );
  });
```

- [ ] **Step 7: Run the Medicine module test**

Run: `flutter test test/features/medicine/medicine_module_test.dart | tail -10`
Expected: PASS

- [ ] **Step 8: Implement `PrayerModule.onQuickAction`**

In `lib/features/prayer/prayer_module.dart`, first add the import (insert
alphabetically between the existing `domain/usecases/calculate_prayer_streak
.dart` and `domain/usecases/jumuah_label.dart` imports):

```dart
import 'package:habit_tracker/features/prayer/domain/usecases/effective_prayer_status.dart';
```

Then add directly below `onNotificationAction` (after its closing `}`
around line 205):

```dart
  @override
  Future<void> onQuickAction() async {
    final settings = await _repository.watchSettings().first;
    final locationResult = await resolveLocation(settings);
    if (locationResult case Failure()) return;
    final location = (locationResult as Success<ResolvedLocation>).value;

    final now = clock.now();
    final today = localDayKey(now);
    final records = await _repository.recordsInRange(today, today);
    final sorted = [...records]
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    for (final record in sorted) {
      final cutoff = cutoffForPrayer(
        record: record,
        sameDayRecordsSorted: sorted,
        ishaDayRolloverTime: settings.ishaDayRolloverTime,
        ianaTimezone: location.ianaTimezone,
      );
      final status = effectivePrayerStatus(
        storedStatus: record.storedStatus,
        scheduledFor: record.scheduledFor,
        cutoff: cutoff,
        now: now,
      );
      if (status == PrayerStatus.due) {
        await _repository.markPrayed(record.id);
        return;
      }
    }
  }
```

- [ ] **Step 9: Write the failing tests for `PrayerModule.onQuickAction`**

In `test/features/prayer/prayer_module_test.dart`, add after the
`onNotificationAction`-related tests (find them by searching for
`'onNotificationAction'` in the file and add these after that block):

```dart
  test('onQuickAction marks the earliest due prayer prayed', () async {
    final now = DateTime.utc(2026, 6, 1, 9);
    final fajr = PrayerRecord(
      id: 'r-fajr',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.fajr,
      scheduledFor: DateTime.utc(2026, 6, 1, 5),
      storedStatus: PrayerStatus.upcoming,
    );
    final dhuhr = PrayerRecord(
      id: 'r-dhuhr',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.dhuhr,
      scheduledFor: DateTime.utc(2026, 6, 1, 8),
      storedStatus: PrayerStatus.upcoming,
    );
    final asr = PrayerRecord(
      id: 'r-asr',
      prayerDate: const LocalDate(2026, 6, 1),
      prayerName: PrayerName.asr,
      scheduledFor: DateTime.utc(2026, 6, 1, 12),
      storedStatus: PrayerStatus.upcoming,
    );

    when(() => repo.watchSettings()).thenAnswer(
      (_) => Stream.value(settings),
    );
    when(
      () => repo.recordsInRange(any(), any()),
    ).thenAnswer((_) async => [asr, dhuhr, fajr]);
    when(
      () => repo.markPrayed(any()),
    ).thenAnswer((_) async => const Result.success(null));

    await withClock(Clock.fixed(now), () async {
      await module.onQuickAction();
    });

    // fajr (5am) is past its cutoff (dhuhr's 8am start) -> missed, not due.
    // dhuhr (8am) is past its own start but before asr's 12pm cutoff -> due.
    // asr (12pm) hasn't started yet -> upcoming.
    verify(() => repo.markPrayed('r-dhuhr')).called(1);
  });

  test('onQuickAction no-ops when nothing is due', () async {
    when(() => repo.watchSettings()).thenAnswer(
      (_) => Stream.value(settings),
    );
    when(() => repo.recordsInRange(any(), any())).thenAnswer((_) async => []);

    await module.onQuickAction();

    verifyNever(() => repo.markPrayed(any()));
  });
```

- [ ] **Step 10: Run the Prayer module test**

Run: `flutter test test/features/prayer/prayer_module_test.dart | tail -10`
Expected: PASS

- [ ] **Step 11: Run `flutter analyze` to confirm the interface change didn't break any other implementer**

Run: `flutter analyze | tail -10`
Expected: `No issues found!` (or pre-existing issues only, none new)

- [ ] **Step 12: Commit**

```bash
git add lib/core/modules/habit_module.dart lib/features/water/water_module.dart lib/features/medicine/medicine_module.dart lib/features/prayer/prayer_module.dart test/features/water/water_module_test.dart test/features/medicine/medicine_module_test.dart test/features/prayer/prayer_module_test.dart
git commit -m "feat(shortcuts): add HabitModule.onQuickAction, implemented by Water/Medicine/Prayer"
```

---

### Task 2: `core/shortcuts/quick_action_handler.dart` dispatcher

**Files:**
- Create: `lib/core/shortcuts/quick_action_handler.dart`
- Test: `test/core/shortcuts/quick_action_handler_test.dart`

**Interfaces:**
- Consumes: `buildHabitModules(AppDatabase db)` from
  `lib/core/modules/module_registry.dart` (existing); `HabitModule
  .onQuickAction()` from Task 1; `testDatabase()` from
  `test/support/test_database.dart` (existing).
- Produces: `Future<void> handleQuickAction({required String type, required
  AppDatabase db})` — consumed by Task 4's `main()` wiring.

- [ ] **Step 1: Write the failing test**

Create `test/core/shortcuts/quick_action_handler_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/shortcuts/quick_action_handler.dart';

import '../../support/test_database.dart';

void main() {
  test(
    'handleQuickAction(type: water) logs a quick water entry',
    () async {
      final db = testDatabase();
      addTearDown(db.close);

      await handleQuickAction(type: 'water', db: db);

      final rows = await db.select(db.waterLogsTable).get();
      expect(rows, hasLength(1));
      expect(rows.single.amountMl, 250);
    },
  );

  test('handleQuickAction ignores an unknown type', () async {
    final db = testDatabase();
    addTearDown(db.close);

    await handleQuickAction(type: 'not_a_module', db: db);

    final rows = await db.select(db.waterLogsTable).get();
    expect(rows, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/shortcuts/quick_action_handler_test.dart | tail -10`
Expected: FAIL — `Error: Not found: 'package:habit_tracker/core/shortcuts/quick_action_handler.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/core/shortcuts/quick_action_handler.dart`:

```dart
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';

/// Dispatches a tapped home-screen/app shortcut to the module whose
/// [module_registry.buildHabitModules]'s `id` equals [type], calling its
/// headless `onQuickAction()`. Mirrors
/// `core/notifications/notification_action_handler.dart`'s `_dispatch` —
/// same shape, no ledger, no navigation (the caller navigates once this
/// returns; see `main.dart`'s `QuickActions.initialize` callback).
Future<void> handleQuickAction({
  required String type,
  required AppDatabase db,
}) async {
  final modules = buildHabitModules(db);
  for (final module in modules) {
    if (module.id == type) {
      await module.onQuickAction();
      return;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/shortcuts/quick_action_handler_test.dart | tail -10`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/shortcuts/quick_action_handler.dart test/core/shortcuts/quick_action_handler_test.dart
git commit -m "feat(shortcuts): add quick_action_handler dispatcher"
```

---

### Task 3: `quick_actions` dependency + `shortcut_items.dart` + new l10n key

**Files:**
- Modify: `pubspec.yaml` (add dependency)
- Modify: `lib/core/l10n/app_en.arb` (add `waterQuickAddAction` key)
- Modify: `lib/core/l10n/app_bn.arb` (add `waterQuickAddAction` translation)
- Create: `lib/core/shortcuts/shortcut_items.dart`
- Test: `test/core/shortcuts/shortcut_items_test.dart`

**Interfaces:**
- Consumes: `AppLocalizations`/`lookupAppLocalizations(Locale)` from
  `lib/core/l10n/app_localizations.dart` (generated, already present
  locally); `ShortcutItem`/`QuickActions` from `package:quick_actions
  /quick_actions.dart` (new dependency).
- Produces: `List<ShortcutItem> buildShortcutItems(AppLocalizations l10n)`
  — consumed by Task 4's `main.dart` wiring.

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml`, insert this line alphabetically between `pointycastle:
^4.0.0` and `riverpod_annotation: ^4.0.3`:

```yaml
  quick_actions: ^1.1.0
```

Run: `flutter pub get | tail -10`
Expected: `Got dependencies!` with `quick_actions` listed as a new
transitive addition (check `pubspec.lock` now has a `quick_actions` entry).

- [ ] **Step 2: Add the new l10n key**

In `lib/core/l10n/app_en.arb`, insert directly after the
`"prayerMarkPrayedAction"`/`"@prayerMarkPrayedAction"` pair (around line
743):

```json
  "waterQuickAddAction": "Log water",
  "@waterQuickAddAction": {"description": "Home-screen/app-shortcut label for Water's one-tap quick-add action (fixed, not amount-specific — unlike the in-app dashboard chip)."},
```

In `lib/core/l10n/app_bn.arb`, insert directly after the
`"prayerMarkPrayedAction"` entry (around line 244):

```json
  "waterQuickAddAction": "পানি যোগ করুন",
```

Run: `flutter gen-l10n | tail -10`
Expected: no errors; `lib/core/l10n/app_localizations.dart` and
`app_localizations_en.dart`/`app_localizations_bn.dart` now declare
`waterQuickAddAction`.

- [ ] **Step 3: Write the failing test**

Create `test/core/shortcuts/shortcut_items_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/shortcuts/shortcut_items.dart';

void main() {
  test('buildShortcutItems returns exactly 3 items keyed by module id, no '
      'icon set', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    final items = buildShortcutItems(l10n);

    expect(items.map((i) => i.type).toList(), ['water', 'medicine', 'prayer']);
    expect(items.every((i) => i.icon == null), isTrue);
    expect(items.first.localizedTitle, l10n.waterQuickAddAction);
  });

  test('buildShortcutItems resolves titles in the requested locale', () {
    final en = buildShortcutItems(lookupAppLocalizations(const Locale('en')));
    final bn = buildShortcutItems(lookupAppLocalizations(const Locale('bn')));

    expect(en.first.localizedTitle, isNot(bn.first.localizedTitle));
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/core/shortcuts/shortcut_items_test.dart | tail -10`
Expected: FAIL — `Error: Not found: 'package:habit_tracker/core/shortcuts/shortcut_items.dart'`

- [ ] **Step 5: Write the implementation**

Create `lib/core/shortcuts/shortcut_items.dart`:

```dart
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:quick_actions/quick_actions.dart';

/// The fixed set of 3 static home-screen/app shortcuts — one per module,
/// `type` matching `HabitModule.id` exactly (`'water'`/`'medicine'`
/// /`'prayer'`). `icon` is left `null` for v1: native drawable/asset-catalog
/// icons are a separate design/asset task, out of scope here.
List<ShortcutItem> buildShortcutItems(AppLocalizations l10n) => [
  ShortcutItem(type: 'water', localizedTitle: l10n.waterQuickAddAction),
  ShortcutItem(type: 'medicine', localizedTitle: l10n.medicineMarkDoneAction),
  ShortcutItem(type: 'prayer', localizedTitle: l10n.prayerMarkPrayedAction),
];
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/core/shortcuts/shortcut_items_test.dart | tail -10`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb lib/core/shortcuts/shortcut_items.dart test/core/shortcuts/shortcut_items_test.dart
git commit -m "feat(shortcuts): add quick_actions dependency and static shortcut-item builder"
```

Note: the generated `lib/core/l10n/app_localizations*.dart` files are
`.gitignore`d (per `CLAUDE.md`) — do not `git add` them; they regenerate
from the `.arb` files on the next `flutter gen-l10n`/`flutter pub get`.

---

### Task 4: Wire `QuickActions` into `main.dart`

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `handleQuickAction` from Task 2; `buildShortcutItems` from
  Task 3; `QuickActions`/`ShortcutItem` from `package:quick_actions
  /quick_actions.dart`; `lookupAppLocalizations` from `lib/core/l10n
  /app_localizations.dart`; `localeControllerProvider` from
  `lib/features/settings/presentation/providers/locale_controller.dart`
  (already imported transitively — not directly imported in `main.dart`
  today, needs adding).
- Produces: nothing consumed by later tasks — this is the final
  integration point.

There is no existing test file for `main.dart` (it has none today — the
notification-engine wiring it already carries is also untested at this
level), so this task's verification is `flutter analyze`, not a test run.

- [ ] **Step 1: Add imports**

In `lib/main.dart`, add these imports in alphabetical position:

```dart
import 'package:habit_tracker/core/shortcuts/quick_action_handler.dart';
import 'package:habit_tracker/core/shortcuts/shortcut_items.dart';
```

(insert between the existing `core/security/screen_privacy_service.dart`
and `core/theme/app_theme.dart` imports)

```dart
import 'package:habit_tracker/features/settings/presentation/providers/locale_controller.dart';
```

(insert between the existing `features/settings/presentation/providers
/app_settings_providers.dart` and `.../theme_controller.dart` imports)

```dart
import 'package:quick_actions/quick_actions.dart';
```

(append as the last import — `quick_actions` sorts after every
`habit_tracker` import)

- [ ] **Step 2: Wire `QuickActions.initialize` in `main()`**

In `lib/main.dart`, directly after the existing
`await registerNotificationWorkmanager();` line (around line 49), add:

```dart
  await const QuickActions().initialize((type) async {
    await handleQuickAction(type: type, db: db);
    container.read(appRouterProvider).go('/$type');
  });
```

- [ ] **Step 3: Register/re-register shortcuts on locale change**

Correction from the original design sketch: `WidgetRef.listen` (the
variant safe to call inside `build()`) does **not** support
`fireImmediately` in this Riverpod version — only `listenManual` does, and
`listenManual` is documented as designed for `State` lifecycle methods
(`initState`), not `build()`. So this goes in `_HabitTrackerAppState
.initState()` instead, directly after the existing `initialDeepLink`
post-frame-callback block:

```dart
    // Registers the 3 static home-screen/app-shortcut items
    // (`core/shortcuts/`) once now and again on every locale change, so
    // labels stay in the user's chosen language. `listenManual` (not the
    // build()-safe `listen`) because this needs `fireImmediately`, which
    // `listen` doesn't support.
    ref.listenManual<Locale>(localeControllerProvider, (previous, next) {
      final l10n = lookupAppLocalizations(next);
      unawaited(
        const QuickActions().setShortcutItems(buildShortcutItems(l10n)),
      );
    }, fireImmediately: true);
```

- [ ] **Step 4: Run analyze**

Run: `flutter analyze | tail -10`
Expected: `No issues found!` (or pre-existing issues only, none new)

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat(shortcuts): wire QuickActions.initialize and setShortcutItems in main.dart"
```

---

## Self-Review Notes

- **Spec coverage:** dependency (Task 3) / `HabitModule.onQuickAction` +
  3 implementations (Task 1) / dispatcher (Task 2) / registration timing
  + locale-driven re-registration (Task 4) / `type` == `HabitModule.id`
  (Tasks 1-2) / navigate-after-action via `appRouterProvider` (Task 4) —
  all covered. Icon assets and dynamic/conditional shortcuts are
  confirmed out of scope by the spec itself, not implemented here.
- **Type consistency:** `handleQuickAction({required String type,
  required AppDatabase db})` (Task 2) matches its only call site in Task
  4. `buildShortcutItems(AppLocalizations l10n)` (Task 3) matches its only
  call site in Task 4.

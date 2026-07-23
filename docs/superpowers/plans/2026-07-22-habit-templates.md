# Habit Templates on First Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Water and Medicine a small, named preset picker at their
first-configuration surface, per `docs/superpowers/specs/
2026-07-21-05-habit-templates-design.md`. (Prayer's own preset banner —
originally this spec's Task 3 — has been descoped; see the note at the
end of this doc.)

**Architecture:** Two independent, per-module const preset lists (no
shared `core/` abstraction), each consumed by that module's existing
first-configuration screen through its existing write path
(`WaterController.updateGoal`, `MedicineController.createMedicine` via
`_rule`). No new DB columns, no new routes, no new Riverpod providers.

**Tech Stack:** Flutter/Riverpod (codegen), `gen_l10n`, Drift (untouched
this plan), `flutter_test` (both test files use a real in-memory
`AppDatabase` + real repository impl, matching `water_home_screen_test
.dart`/`medicine_home_screen_test.dart`'s existing convention).

## Global Constraints

- Two new files, one per module, no shared `core/` preset abstraction:
  `lib/features/water/domain/water_goal_presets.dart`,
  `lib/features/medicine/domain/medicine_schedule_presets.dart`.
- New l10n keys go in **both** `lib/core/l10n/app_en.arb` and
  `lib/core/l10n/app_bn.arb`, then regenerate with `flutter gen-l10n`
  before running any widget test that references them (`AppLocalizations`
  is gitignored/generated, so the getters don't exist until regenerated).
- Per this repo's CLAUDE.md spec-implementation workflow: one commit per
  task, run only that task's own test file (never the full `flutter
  test` suite mid-task), pipe `build_runner`/`test` output through
  `| tail -10`.
- Medicine's preset step 0 uses plain `Card`/`ListTile` + `onTap`, not
  `RadioListTile`/`RadioGroup` — each tap is a one-shot action that
  leaves step 0 immediately, so there's no in-step selection state to
  model.
- Water's goal `_GoalField` call site needs `key: ValueKey(goal.goalMl)`
  so a preset tap (which changes `initialValue` from outside the widget)
  forces the field's `late final TextEditingController` to re-seed.

---

## Task 1: Water goal presets

**Files:**
- Create: `lib/features/water/domain/water_goal_presets.dart`
- Modify: `lib/features/water/presentation/screens/water_settings_screen.dart`
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Test: `test/features/water/presentation/water_settings_screen_test.dart`

**Interfaces:**
- Produces: `class WaterGoalPreset { labelKey: String, goalMl: int }` and
  `const List<WaterGoalPreset> waterGoalPresets` (3 entries: 1500/2000/3000).
  Nothing downstream in this plan consumes these outside this task.

- [ ] **Step 1: Add l10n keys to both arb files**

In `lib/core/l10n/app_en.arb`, insert after the
`"waterSettingsReminderWindowLabel"` block (immediately before the
`"medicineHomeEmpty"` key) — find this exact anchor text:

```json
  "waterSettingsReminderWindowLabel": "Between",
  "@waterSettingsReminderWindowLabel": {
    "description": "Label for the reminder time-of-day window row."
  },
  "medicineHomeEmpty": "No doses scheduled for today",
```

Replace it with:

```json
  "waterSettingsReminderWindowLabel": "Between",
  "@waterSettingsReminderWindowLabel": {
    "description": "Label for the reminder time-of-day window row."
  },
  "waterPresetLight": "Light · 1.5L",
  "@waterPresetLight": {
    "description": "Water goal preset chip: 1500ml/day."
  },
  "waterPresetStandard": "Standard · 2L",
  "@waterPresetStandard": {
    "description": "Water goal preset chip: 2000ml/day (matches the seeded default)."
  },
  "waterPresetActive": "Active · 3L",
  "@waterPresetActive": {
    "description": "Water goal preset chip: 3000ml/day."
  },
  "medicineHomeEmpty": "No doses scheduled for today",
```

In `lib/core/l10n/app_bn.arb`, insert after the
`"waterSettingsReminderWindowLabel"` line (immediately before
`"medicineHomeEmpty"`) — find this exact anchor text:

```json
  "waterSettingsReminderWindowLabel": "মধ্যে",
  "medicineHomeEmpty": "আজকের জন্য কোনো ডোজ নির্ধারিত নেই",
```

Replace it with:

```json
  "waterSettingsReminderWindowLabel": "মধ্যে",
  "waterPresetLight": "হালকা · ১.৫ লি",
  "waterPresetStandard": "স্বাভাবিক · ২ লি",
  "waterPresetActive": "সক্রিয় · ৩ লি",
  "medicineHomeEmpty": "আজকের জন্য কোনো ডোজ নির্ধারিত নেই",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors; `lib/core/l10n/app_localizations.dart` (and
`app_localizations_en.dart`/`_bn.dart`) regenerate with the three new
getters.

- [ ] **Step 3: Write the failing widget test**

Create `test/features/water/presentation/water_settings_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_settings_screen.dart';

Future<void> _pumpWaterSettings(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WaterSettingsScreen(),
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

  testWidgets('shows three goal presets, Standard pre-selected for the '
      'seeded 2000ml default', (tester) async {
    await _pumpWaterSettings(tester, db);

    expect(find.text('Light · 1.5L'), findsOneWidget);
    expect(find.text('Standard · 2L'), findsOneWidget);
    expect(find.text('Active · 3L'), findsOneWidget);

    final standardChip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text('Standard · 2L'),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(standardChip.selected, isTrue);

    final lightChip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text('Light · 1.5L'),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(lightChip.selected, isFalse);

    await disposeTree(tester);
  });

  testWidgets('tapping a preset updates the goal field and its own '
      'selected state', (tester) async {
    await _pumpWaterSettings(tester, db);

    await tester.tap(find.text('Light · 1.5L'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '1500'), findsOneWidget);

    final lightChip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text('Light · 1.5L'),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(lightChip.selected, isTrue);

    await disposeTree(tester);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/water/presentation/water_settings_screen_test.dart | tail -10`
Expected: FAIL — `Light · 1.5L` / `Standard · 2L` / `Active · 3L` not
found (the preset chips don't exist yet).

- [ ] **Step 5: Create the preset const list**

Create `lib/features/water/domain/water_goal_presets.dart`:

```dart
/// A named daily-goal preset offered as a quick-pick chip on
/// `WaterSettingsScreen` (`docs/superpowers/specs/
/// 2026-07-21-05-habit-templates-design.md`).
class WaterGoalPreset {
  /// Creates a water goal preset.
  const WaterGoalPreset({required this.labelKey, required this.goalMl});

  /// L10n key for the chip's label, e.g. `'waterPresetLight'`.
  final String labelKey;

  /// The goal value this preset fills in, in milliliters.
  final int goalMl;
}

/// The three daily-goal presets shown on `WaterSettingsScreen`.
const waterGoalPresets = [
  WaterGoalPreset(labelKey: 'waterPresetLight', goalMl: 1500),
  WaterGoalPreset(labelKey: 'waterPresetStandard', goalMl: 2000),
  WaterGoalPreset(labelKey: 'waterPresetActive', goalMl: 3000),
];
```

- [ ] **Step 6: Wire the chips into `WaterSettingsScreen`**

In `lib/features/water/presentation/screens/water_settings_screen.dart`,
add the import (alongside the existing `water_providers.dart` import):

```dart
import 'package:habit_tracker/features/water/domain/water_goal_presets.dart';
```

Replace:

```dart
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GoalField(
            label: l10n.waterSettingsGoalLabel,
            initialValue: goal.goalMl,
            onChanged: controller.updateGoal,
          ),
          const SizedBox(height: 16),
```

with:

```dart
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final preset in waterGoalPresets)
                ChoiceChip(
                  label: Text(_presetLabel(l10n, preset)),
                  selected: goal.goalMl == preset.goalMl,
                  onSelected: (_) => controller.updateGoal(preset.goalMl),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _GoalField(
            key: ValueKey(goal.goalMl),
            label: l10n.waterSettingsGoalLabel,
            initialValue: goal.goalMl,
            onChanged: controller.updateGoal,
          ),
          const SizedBox(height: 16),
```

Add the label-resolution helper as a top-level function in the same
file (near the bottom, after the `WaterSettingsScreen` class):

```dart
String _presetLabel(AppLocalizations l10n, WaterGoalPreset preset) =>
    switch (preset.labelKey) {
      'waterPresetLight' => l10n.waterPresetLight,
      'waterPresetStandard' => l10n.waterPresetStandard,
      'waterPresetActive' => l10n.waterPresetActive,
      _ => preset.labelKey,
    };
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/features/water/presentation/water_settings_screen_test.dart | tail -10`
Expected: PASS (2 tests).

- [ ] **Step 8: Analyze and format**

Run: `flutter analyze lib/features/water/domain/water_goal_presets.dart lib/features/water/presentation/screens/water_settings_screen.dart | tail -10`
Run: `dart format lib/features/water/domain/water_goal_presets.dart lib/features/water/presentation/screens/water_settings_screen.dart`
Expected: no analyzer issues.

- [ ] **Step 9: Commit**

```bash
git add lib/features/water/domain/water_goal_presets.dart \
  lib/features/water/presentation/screens/water_settings_screen.dart \
  lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  test/features/water/presentation/water_settings_screen_test.dart
git commit -m "feat(water): add daily-goal presets to Water settings"
```

---

## Task 2: Medicine schedule presets

**Files:**
- Create: `lib/features/medicine/domain/medicine_schedule_presets.dart`
- Modify: `lib/features/medicine/presentation/screens/medicine_form_screen.dart`
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Test: `test/features/medicine/presentation/medicine_form_screen_test.dart`

**Interfaces:**
- Produces: `class MedicineSchedulePreset { labelKey: String,
  descriptionKey: String, rule: RepeatRule }` and
  `const List<MedicineSchedulePreset> medicineSchedulePresets` (4 entries).
  Consumed only by `MedicineFormScreen`'s new step 0 in this task.
- Note on interpretation (spec's "Custom tile advances to the existing
  `_ScheduleStep` (now step 3)" is describing Custom's eventual landing
  step in the normal linear wizard, not a skip-ahead jump): tapping
  *any* step-0 tile — preset or Custom — calls `_nextStep()` exactly
  once, landing on step 1 (details) same as today. Only presets also
  overwrite `_rule` before that call; Custom leaves `_rule` at its
  existing `fixedDaily` default. The wizard then proceeds normally
  through steps 1 → 2 → 3 for every path, so Save always happens after
  details/stock are filled in, regardless of which step-0 tile started
  the flow.

- [ ] **Step 1: Add l10n keys to both arb files**

In `lib/core/l10n/app_en.arb`, insert after the
`"medicineFormFrequencyPrn"` block (immediately before
`"medicineFormNextButton"`) — find this exact anchor text:

```json
  "medicineFormFrequencyPrn": "As needed (PRN)",
  "@medicineFormFrequencyPrn": {
    "description": "Repeat-rule option: no fixed schedule."
  },
  "medicineFormNextButton": "Next",
```

Replace it with:

```json
  "medicineFormFrequencyPrn": "As needed (PRN)",
  "@medicineFormFrequencyPrn": {
    "description": "Repeat-rule option: no fixed schedule."
  },
  "medPresetOnceDaily": "Once daily",
  "@medPresetOnceDaily": {
    "description": "Medicine schedule preset title: one dose a day at 8am."
  },
  "medPresetOnceDailyDesc": "One dose every day at 8:00 AM",
  "@medPresetOnceDailyDesc": {
    "description": "Medicine schedule preset subtitle for medPresetOnceDaily."
  },
  "medPresetTwiceDaily": "Twice daily",
  "@medPresetTwiceDaily": {
    "description": "Medicine schedule preset title: two doses a day."
  },
  "medPresetTwiceDailyDesc": "Two doses every day, 8:00 AM and 8:00 PM",
  "@medPresetTwiceDailyDesc": {
    "description": "Medicine schedule preset subtitle for medPresetTwiceDaily."
  },
  "medPresetEveryOtherDay": "Every other day",
  "@medPresetEveryOtherDay": {
    "description": "Medicine schedule preset title: one dose every 2 days."
  },
  "medPresetEveryOtherDayDesc": "One dose every 2 days at 8:00 AM",
  "@medPresetEveryOtherDayDesc": {
    "description": "Medicine schedule preset subtitle for medPresetEveryOtherDay."
  },
  "medPresetAsNeeded": "As needed",
  "@medPresetAsNeeded": {
    "description": "Medicine schedule preset title: PRN, no fixed schedule."
  },
  "medPresetAsNeededDesc": "No fixed schedule — log doses when taken",
  "@medPresetAsNeededDesc": {
    "description": "Medicine schedule preset subtitle for medPresetAsNeeded."
  },
  "medPresetCustom": "Custom schedule",
  "@medPresetCustom": {
    "description": "Trailing step-0 tile that skips presets and goes to the manual schedule step."
  },
  "medicineFormNextButton": "Next",
```

In `lib/core/l10n/app_bn.arb`, insert after the
`"medicineFormFrequencyPrn"` line (immediately before
`"medicineFormNextButton"`) — find this exact anchor text:

```json
  "medicineFormFrequencyPrn": "প্রয়োজন অনুসারে",
  "medicineFormNextButton": "পরবর্তী",
```

Replace it with:

```json
  "medicineFormFrequencyPrn": "প্রয়োজন অনুসারে",
  "medPresetOnceDaily": "দিনে একবার",
  "medPresetOnceDailyDesc": "প্রতিদিন সকাল ৮টায় একটি ডোজ",
  "medPresetTwiceDaily": "দিনে দুইবার",
  "medPresetTwiceDailyDesc": "প্রতিদিন দুটি ডোজ, সকাল ৮টা ও রাত ৮টা",
  "medPresetEveryOtherDay": "একদিন পরপর",
  "medPresetEveryOtherDayDesc": "প্রতি ২ দিনে সকাল ৮টায় একটি ডোজ",
  "medPresetAsNeeded": "প্রয়োজন অনুসারে",
  "medPresetAsNeededDesc": "নির্দিষ্ট সময়সূচি নেই — সেবনের সময় লগ করুন",
  "medPresetCustom": "নিজস্ব সময়সূচি",
  "medicineFormNextButton": "পরবর্তী",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors.

- [ ] **Step 3: Write the failing widget test**

Create `test/features/medicine/presentation/medicine_form_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_form_screen.dart';

Future<GoRouter> _pumpMedicineForm(WidgetTester tester, AppDatabase db) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(path: '/form', builder: (_, __) => const MedicineFormScreen()),
    ],
  );
  router.push('/form');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('step 0 shows the four schedule presets plus Custom', (
    tester,
  ) async {
    await _pumpMedicineForm(tester, db);

    expect(find.text('Once daily'), findsOneWidget);
    expect(find.text('Twice daily'), findsOneWidget);
    expect(find.text('Every other day'), findsOneWidget);
    expect(find.text('As needed'), findsOneWidget);
    expect(find.text('Custom schedule'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('selecting a preset carries its rule through to Save', (
    tester,
  ) async {
    await _pumpMedicineForm(tester, db);

    await tester.tap(find.text('Every other day'));
    await tester.pumpAndSettle();

    // Landed on step 1 (details).
    expect(find.text('Name'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Aspirin');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2 (stock) — leave disabled, advance.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3 (schedule) — save without touching the radio group.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final repo = MedicineRepositoryImpl(db);
    final schedules = await repo.allSchedules();
    expect(schedules, hasLength(1));
    expect(
      schedules.single.rule,
      const RepeatRule.everyNDays(
        intervalDays: 2,
        timesOfDay: [LocalTime(8, 0)],
      ),
    );

    await disposeTree(tester);
  });

  testWidgets("selecting Custom leaves today's fixedDaily default", (
    tester,
  ) async {
    await _pumpMedicineForm(tester, db);

    await tester.tap(find.text('Custom schedule'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Ibuprofen');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final repo = MedicineRepositoryImpl(db);
    final schedules = await repo.allSchedules();
    expect(schedules, hasLength(1));
    expect(
      schedules.single.rule,
      const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
    );

    await disposeTree(tester);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/medicine/presentation/medicine_form_screen_test.dart | tail -10`
Expected: FAIL — step 0's preset text isn't found (screen still opens
straight on the details step).

- [ ] **Step 5: Create the preset const list**

Create `lib/features/medicine/domain/medicine_schedule_presets.dart`:

```dart
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';

/// A named schedule preset offered on `MedicineFormScreen`'s step 0
/// (`docs/superpowers/specs/01-must-have/2026-07-21-05-habit-templates-design.md`).
class MedicineSchedulePreset {
  /// Creates a medicine schedule preset.
  const MedicineSchedulePreset({
    required this.labelKey,
    required this.descriptionKey,
    required this.rule,
  });

  /// L10n key for the tile's title, e.g. `'medPresetOnceDaily'`.
  final String labelKey;

  /// L10n key for the tile's subtitle.
  final String descriptionKey;

  /// The repeat rule this preset fills in.
  final RepeatRule rule;
}

/// The four schedule presets shown on `MedicineFormScreen`'s step 0. A
/// fifth, always-last "Custom" tile is not a list entry — the screen
/// renders it separately and falls through to the existing schedule step.
const medicineSchedulePresets = [
  MedicineSchedulePreset(
    labelKey: 'medPresetOnceDaily',
    descriptionKey: 'medPresetOnceDailyDesc',
    rule: RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
  ),
  MedicineSchedulePreset(
    labelKey: 'medPresetTwiceDaily',
    descriptionKey: 'medPresetTwiceDailyDesc',
    rule: RepeatRule.fixedDaily(
      timesOfDay: [LocalTime(8, 0), LocalTime(20, 0)],
    ),
  ),
  MedicineSchedulePreset(
    labelKey: 'medPresetEveryOtherDay',
    descriptionKey: 'medPresetEveryOtherDayDesc',
    rule: RepeatRule.everyNDays(
      intervalDays: 2,
      timesOfDay: [LocalTime(8, 0)],
    ),
  ),
  MedicineSchedulePreset(
    labelKey: 'medPresetAsNeeded',
    descriptionKey: 'medPresetAsNeededDesc',
    rule: RepeatRule.prn(),
  ),
];
```

- [ ] **Step 6: Add step 0 to `MedicineFormScreen`**

In `lib/features/medicine/presentation/screens/medicine_form_screen.dart`,
add the import (alongside the existing `repeat_rule.dart` import):

```dart
import 'package:habit_tracker/features/medicine/domain/medicine_schedule_presets.dart';
```

Replace the `_nextStep` guard (it currently guards the details step,
which is moving from index 0 to index 1):

```dart
  void _nextStep() {
    if (_step == 0 && _nameController.text.trim().isEmpty) return;
    setState(() => _step += 1);
```

with:

```dart
  void _nextStep() {
    if (_step == 1 && _nameController.text.trim().isEmpty) return;
    setState(() => _step += 1);
```

Replace the progress indicator:

```dart
          child: LinearProgressIndicator(value: (_step + 1) / 3),
```

with:

```dart
          child: LinearProgressIndicator(value: (_step + 1) / 4),
```

Replace the `PageView`'s `children` list:

```dart
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _DetailsStep(
            nameController: _nameController,
            dosageController: _dosageController,
          ),
          _StockStep(
            stockEnabled: _stockEnabled,
            onStockEnabledChanged: (v) => setState(() => _stockEnabled = v),
            stockCountController: _stockCountController,
            stockThresholdController: _stockThresholdController,
          ),
          _ScheduleStep(
            rule: _rule,
            onRuleChanged: (r) => setState(() => _rule = r),
          ),
        ],
      ),
```

with:

```dart
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _PresetStep(
            onPresetSelected: (rule) {
              setState(() => _rule = rule);
              _nextStep();
            },
            onCustomSelected: _nextStep,
          ),
          _DetailsStep(
            nameController: _nameController,
            dosageController: _dosageController,
          ),
          _StockStep(
            stockEnabled: _stockEnabled,
            onStockEnabledChanged: (v) => setState(() => _stockEnabled = v),
            stockCountController: _stockCountController,
            stockThresholdController: _stockThresholdController,
          ),
          _ScheduleStep(
            rule: _rule,
            onRuleChanged: (r) => setState(() => _rule = r),
          ),
        ],
      ),
```

Replace the Save/Next button condition:

```dart
          child: FilledButton(
            onPressed: _step < 2 ? _nextStep : _save,
            child: Text(
              _step < 2
                  ? l10n.medicineFormNextButton
                  : l10n.medicineFormSaveButton,
            ),
          ),
```

with:

```dart
          child: FilledButton(
            onPressed: _step < 3 ? _nextStep : _save,
            child: Text(
              _step < 3
                  ? l10n.medicineFormNextButton
                  : l10n.medicineFormSaveButton,
            ),
          ),
```

Add the new `_PresetStep` widget and its two label-resolution helpers
right after the `MedicineFormScreen`/`_MedicineFormScreenState` classes,
before `_DetailsStep`:

```dart
class _PresetStep extends StatelessWidget {
  const _PresetStep({
    required this.onPresetSelected,
    required this.onCustomSelected,
  });

  final ValueChanged<RepeatRule> onPresetSelected;
  final VoidCallback onCustomSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final preset in medicineSchedulePresets)
          Card(
            child: ListTile(
              title: Text(_presetLabel(l10n, preset)),
              subtitle: Text(_presetDescription(l10n, preset)),
              onTap: () => onPresetSelected(preset.rule),
            ),
          ),
        Card(
          child: ListTile(
            title: Text(l10n.medPresetCustom),
            onTap: onCustomSelected,
          ),
        ),
      ],
    );
  }
}

String _presetLabel(AppLocalizations l10n, MedicineSchedulePreset preset) =>
    switch (preset.labelKey) {
      'medPresetOnceDaily' => l10n.medPresetOnceDaily,
      'medPresetTwiceDaily' => l10n.medPresetTwiceDaily,
      'medPresetEveryOtherDay' => l10n.medPresetEveryOtherDay,
      'medPresetAsNeeded' => l10n.medPresetAsNeeded,
      _ => preset.labelKey,
    };

String _presetDescription(
  AppLocalizations l10n,
  MedicineSchedulePreset preset,
) => switch (preset.descriptionKey) {
  'medPresetOnceDailyDesc' => l10n.medPresetOnceDailyDesc,
  'medPresetTwiceDailyDesc' => l10n.medPresetTwiceDailyDesc,
  'medPresetEveryOtherDayDesc' => l10n.medPresetEveryOtherDayDesc,
  'medPresetAsNeededDesc' => l10n.medPresetAsNeededDesc,
  _ => preset.descriptionKey,
};
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/features/medicine/presentation/medicine_form_screen_test.dart | tail -10`
Expected: PASS (3 tests).

- [ ] **Step 8: Analyze and format**

Run: `flutter analyze lib/features/medicine/domain/medicine_schedule_presets.dart lib/features/medicine/presentation/screens/medicine_form_screen.dart | tail -10`
Run: `dart format lib/features/medicine/domain/medicine_schedule_presets.dart lib/features/medicine/presentation/screens/medicine_form_screen.dart`
Expected: no analyzer issues.

- [ ] **Step 9: Commit**

```bash
git add lib/features/medicine/domain/medicine_schedule_presets.dart \
  lib/features/medicine/presentation/screens/medicine_form_screen.dart \
  lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  test/features/medicine/presentation/medicine_form_screen_test.dart
git commit -m "feat(medicine): add schedule presets to the add-medicine wizard"
```

---

## Task 3 (Prayer method presets): dropped

Descoped at the user's request. Before dropping it, the screen/preset
code was fully written and functionally correct (verified via direct
DB assertions), but two independent pre-existing bugs in
`PrayerController.updateSettings` surfaced along the way — unrelated to
this feature, already latent in every existing caller of that method
(the settings screen's method/madhab/location dropdowns):

1. `ref.invalidate(resolvedPrayerLocationProvider); await
   ref.read(resolvedPrayerLocationProvider.future);` raced Riverpod's
   auto-dispose scheduling on a provider nothing else in the app
   watches.
2. The fix for #1 (`repository.watchSettings().first`) opened a second
   live Drift query against a row a screen may already be watching,
   deadlocking against that subscription's own concurrent re-query.

Both are fixed and committed on `feat/habit-templates` (`prayer_
controller.dart`, `prayer_repository.dart`'s new one-shot
`getSettings()`, `prayer_repository_impl.dart`) — that fix stands on
its own regardless of this feature's fate. The preset banner UI itself
(`prayer_method_presets.dart`, the `PrayerSettingsScreen` edits, its
test) was reverted and is not part of this branch.

---

## After both tasks

Per this repo's CLAUDE.md spec-implementation workflow: once every task
above is committed, open a PR for the spec with the design summary in
the description, then run a code review against the finished PR
(comment → fix → commit cycle, up to 5 rounds), then stop and wait for
the user's own review and merge.

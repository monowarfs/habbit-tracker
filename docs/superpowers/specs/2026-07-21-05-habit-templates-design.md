# Habit Templates on First Configuration

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

The Feature Atlas gap-analysis (Finch-inspired) calls this "habit
templates on first enable" — e.g. a "2L/day" water preset, "twice-daily
BP med" medicine preset, "Hanafi, Dhaka" prayer preset — offered the
moment a module is first turned on.

**That framing doesn't match this codebase.** `lib/core/modules/
module_registry.dart`'s `buildHabitModules()` unconditionally
constructs and registers `MedicineModule`, `WaterModule`, and
`PrayerModule` — there is no enable/disable list, no per-module toggle
anywhere in `lib/features/settings/` (grepped for `enable`/`disable`
across the settings feature: the only hits are PIN lock, biometric
unlock, and screen-privacy, all unrelated to modules). All three
modules are always on from first launch. There is also no app-level
onboarding flow — `AppSettings.onboardingCompletedAt` is a schema field
that is read/written nowhere in `lib/` today.

So "first enable" is reframed as **first configuration of a module
that has no goal/schedule/settings yet**, and each module already
has a different starting point:

- **Water** — `WaterRepositoryImpl._ensureGoalSeeded()`
  (`lib/features/water/data/repositories/water_repository_impl.dart:98-121`)
  silently inserts a `_defaultGoalMl = 2000` goal row the first time
  `watchCurrentGoal()`/`allGoals()` is ever called — before the user
  has looked at the Water tab at all. A "2L/day preset" is *already*
  the seeded default; there is no moment where Water is unconfigured
  from the user's point of view. The only real first-configuration
  surface is `WaterSettingsScreen`'s goal field, which today is a bare
  `TextField` the user edits by hand.
- **Medicine** — has no auto-seeded anything. `MedicineListScreen`
  shows an empty-state string until the user taps the FAB and goes
  through `MedicineFormScreen`'s 3-step wizard (details → stock →
  schedule) from a blank `RepeatRule.fixedDaily(timesOfDay: [08:00])`
  default. There is no "quick add common medicine" shortcut — every
  medicine, including something as common as "twice-daily BP med", is
  built field-by-field through the raw repeat-rule UI
  (`_ScheduleStep`'s four `RadioListTile`s: fixed daily / every-N-days
  / weekday set / PRN).
- **Prayer** — already has locale-aware smart defaults.
  `PrayerRepositoryImpl`'s constructor
  (`lib/features/prayer/data/repositories/prayer_repository_impl.dart:30-49`)
  picks `CalculationMethod.karachi` + `AsrMethod.hanafi` when the
  device locale is Bangladesh, `mwl`/`standard` otherwise, seeded on
  first `watchSettings()` read as `LocationMode.auto` (GPS). So
  "Hanafi, Dhaka" is halfway there already (method+madhab default
  correctly for a BD user) — what's missing is location: `auto` mode
  does a live GPS fix, and there's no city preset shortcut, only a
  40-city raw dropdown in `PrayerSettingsScreen` once the user
  manually flips to `LocationMode.manual`.

In short: **the gap isn't "no defaults exist," it's "no discoverable,
named preset choice exists at the moment a user first touches each
module's configuration."** Water's default is invisible (silently
seeded, never presented as a choice); Medicine has zero shortcuts;
Prayer's smart default is silent and location still requires manual
city hunting.

## Design

A static, per-module list of named presets (`label` + `description` +
concrete field values), rendered as a **preset picker step inserted
into each module's existing first-configuration UI** — not a new
screen, not a new onboarding flow, not a module-enable hook (since
none exists).

### Preset config shape

One small `HabitPreset<T>`-style const list per module, living next to
that module's other domain constants (not a new `core/` abstraction —
each module already owns its own defaults, e.g. `_defaultGoalMl` in
`water_repository_impl.dart`, the locale-branching defaults in
`prayer_repository_impl.dart`). No shared base class or generic
`HabitModule` contract addition — three unrelated value shapes (an
int, a `RepeatRule`, a method/madhab/city triple) gain nothing from a
common interface, and `HabitModule` is already a wide contract per
`core/modules/habit_module.dart`; forcing presets through it would
mean a six-module-spanning generic type for something only the
first-run UI reads.

```dart
// lib/features/water/domain/water_goal_presets.dart
class WaterGoalPreset {
  const WaterGoalPreset({
    required this.labelKey,   // l10n key, e.g. 'waterPresetLight'
    required this.goalMl,
  });
  final String labelKey;
  final int goalMl;
}

const waterGoalPresets = [
  WaterGoalPreset(labelKey: 'waterPresetLight', goalMl: 1500),
  WaterGoalPreset(labelKey: 'waterPresetStandard', goalMl: 2000), // matches _defaultGoalMl
  WaterGoalPreset(labelKey: 'waterPresetActive', goalMl: 3000),
];
```

```dart
// lib/features/medicine/domain/medicine_schedule_presets.dart
class MedicineSchedulePreset {
  const MedicineSchedulePreset({
    required this.labelKey,
    required this.descriptionKey,
    required this.rule,
  });
  final String labelKey;
  final String descriptionKey;
  final RepeatRule rule;
}

const medicineSchedulePresets = [
  MedicineSchedulePreset(
    labelKey: 'medPresetOnceDaily',
    descriptionKey: 'medPresetOnceDailyDesc',
    rule: RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
  ),
  MedicineSchedulePreset(
    labelKey: 'medPresetTwiceDaily', // "twice-daily BP med"
    descriptionKey: 'medPresetTwiceDailyDesc',
    rule: RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0), LocalTime(20, 0)]),
  ),
  MedicineSchedulePreset(
    labelKey: 'medPresetEveryOtherDay',
    descriptionKey: 'medPresetEveryOtherDayDesc',
    rule: RepeatRule.everyNDays(intervalDays: 2, timesOfDay: [LocalTime(8, 0)]),
  ),
  MedicineSchedulePreset(
    labelKey: 'medPresetAsNeeded',
    descriptionKey: 'medPresetAsNeededDesc',
    rule: RepeatRule.prn(),
  ),
  // "Custom" is not a list entry — it's the existing wizard, selected by
  // a fifth, always-last picker tile that skips straight to _ScheduleStep
  // pre-filled with today's fixedDaily default, unchanged from today.
];
```

```dart
// lib/features/prayer/domain/prayer_method_presets.dart
class PrayerMethodPreset {
  const PrayerMethodPreset({
    required this.labelKey,
    required this.calculationMethod,
    required this.asrMethod,
    required this.city, // nullable -> "use GPS" preset
  });
  final String labelKey;
  final CalculationMethod calculationMethod;
  final AsrMethod asrMethod;
  final PrayerCity? city;
}

// Bundled cities already exist (65-city asset per CLAUDE.md); this list
// just names a handful of common region+madhab pairings over the same
// asset, resolved by nameKey lookup at picker-build time — no new city
// data.
const prayerMethodPresets = [
  PrayerMethodPreset(labelKey: 'prayerPresetUseGps', calculationMethod: ..., asrMethod: ..., city: null),
  PrayerMethodPreset(labelKey: 'prayerPresetHanafiDhaka', calculationMethod: CalculationMethod.karachi, asrMethod: AsrMethod.hanafi, city: <Dhaka from bundled asset>),
  PrayerMethodPreset(labelKey: 'prayerPresetStandardMwl', calculationMethod: CalculationMethod.mwl, asrMethod: AsrMethod.standard, city: null),
  // A short, deliberately small list (3-5 entries) — not a second copy
  // of the 65-city dropdown. "Other" falls through to the existing
  // full Settings screen (method dropdown + Manual location + city
  // picker), unchanged.
];
```

### Where each picker slots in

**Water** — `WaterSettingsScreen`'s goal field gains three preset chips
above the existing `_GoalField` (`ChoiceChip` per `waterGoalPresets`
entry, showing e.g. "Light · 1.5L", `selected: goal.goalMl == preset.
goalMl`, plus the field stays editable for a custom number — tapping a
chip just calls `controller.updateGoal(preset.goalMl)`). Because
`_ensureGoalSeeded()` already wrote `2000`ml by the time the user opens
this screen, tapping "Standard" is a normal `setGoal()` call, not a
special first-run path — no change to `_ensureGoalSeeded()` or the
repository at all. This also means Water's "first configuration" moment
is soft: a user who never opens Settings simply keeps the seeded 2L
default, preset or not, which matches the "Must Have" complexity budget
(S) better than forcing a modal on first launch.

**Pre-existing bug this design surfaces:** `_GoalField`'s
`TextEditingController` is `late final`, seeded once from
`widget.initialValue` at first build. A preset chip tap updates the
provider (and thus `widget.initialValue` on rebuild) but the on-screen
text wouldn't follow, since `late final` never re-initializes. Fix:
give the goal `_GoalField` instance a `ValueKey(goal.goalMl)` at its
call site in `WaterSettingsScreen`, forcing Flutter to tear down and
recreate the State (and its controller) whenever the goal value changes
externally — a one-line change, no new lifecycle method. Scoped to the
goal field only; the quick-add `_GoalField`s are untouched (no preset
writes to those).

**Medicine** — `MedicineFormScreen` gains a **new step 0** (schedule
picker), pushing the existing three steps to 1-3, but only in the
`editMedicineId == null` (create) path — editing an existing medicine
skips straight to step 1 as today. The new step shows
`medicineSchedulePresets` as a vertical list of plain `Card`/`ListTile`
rows (label + description), each with a single `onTap` — not a
`RadioListTile`/`RadioGroup`: the tap is a one-shot action (set `_rule`,
call `_nextStep()`) that immediately leaves step 0, so there's no
in-step selection state worth modeling, unlike step 3's `_ScheduleStep`
where the radio group's value persists while the user stays on that
page. Selecting the trailing "Custom" tile advances to the existing
`_ScheduleStep` (now step 3) with today's `fixedDaily` default, i.e.
exactly today's behavior — the preset step is purely additive, no
existing step's logic changes. The progress indicator becomes
`(_step + 1) / 4`.

**Prayer** — `PrayerSettingsScreen` is reached from Settings, not from
a "first run" gate, since there's no onboarding flow to hook. The
practical first-configuration moment is the first time
`watchSettings()` seeds the row (`prayer_repository_impl.dart:52-73`,
already locale-defaulted) *and* the user opens Prayer settings before
ever changing `locationMode` off `auto`. Add a one-time preset banner
at the top of `PrayerSettingsScreen`, shown only while
`locationMode == LocationMode.auto` AND no manual coordinates have
ever been set (i.e. `manualLatitude == null` — today's fresh-seed
state) — a horizontal row of `ActionChip`s built from
`prayerMethodPresets`.

Tapping a city-bearing preset (e.g. "Hanafi, Dhaka") calls
`controller.updateSettings(calculationMethod: ..., asrMethod: ...,
manualLatitude: city.latitude, manualLongitude: city.longitude,
manualTimezone: city.ianaTimezone, locationMode: LocationMode.manual)`
— `locationMode` **must** flip to `manual` in the same call, not just
method/madhab/coordinates: leaving it `auto` would mean the picked
Dhaka coordinates are written but never read (prayer times stay
GPS-driven) and the banner's own dismiss condition
(`locationMode == auto`) would never clear. Tapping "Use GPS" writes
nothing (GPS/auto is already the default) and only needs to dismiss the
banner locally. "Standard (MWL)" is `city: null` like "Use GPS" but is
*not* the GPS chip — it only calls `updateSettings(calculationMethod:
mwl, asrMethod: standard)`, touching neither `locationMode` nor the
local acknowledged flag, so the banner correctly stays visible
afterward (still `locationMode == auto`) until the user picks a
city-bearing preset, edits location manually, or taps "Use GPS".

That local-only dismiss is the one case with no DB signal to key off:
`manualLatitude` staying null and `locationMode` staying `auto` are
both correct, expected state after choosing GPS, so they can't double
as a "user already saw and accepted the banner" flag without a new
persisted column, which is out of scope. Instead, `PrayerSettingsScreen`
becomes a `ConsumerStatefulWidget` holding a local
`bool _gpsPresetAcknowledged = false`; the banner's visibility
condition becomes `locationMode == auto && !_gpsPresetAcknowledged`,
and the "Use GPS" chip's `onPressed` just does
`setState(() => _gpsPresetAcknowledged = true)`. This is intentionally
session-local: leaving and reopening Settings without ever picking a
manual/city preset shows the banner again. Accepted trade-off — no
schema change, and re-tapping "Use GPS" a second time is a harmless
no-op. Once any city-bearing preset is picked, or the user manually
edits location via the existing dropdowns below, `locationMode`
becomes (or already is) `manual`, so the banner's primary condition
(`locationMode == auto`) stops holding on its own — the acknowledged
flag only matters for the GPS branch.

### What stays out of scope

- **No module enable/disable feature** — confirmed absent; not being
  added by this design. "First enable" is not a real event in this
  app.
- **No new onboarding flow / app-level wizard** — `onboardingCompletedAt`
  stays unused; this is deliberately a per-module inline picker, not a
  first-launch modal sequence.
- **No new DB columns, tables, or migration.** Every preset just calls
  each module's existing write path (`WaterController.updateGoal`,
  `MedicineController.createMedicine`, `PrayerController.
  updateSettings`) with pre-filled values — same as a user typing them
  in by hand today.
- **No i18n of preset *values*** (2000ml stays 2000ml, Dhaka's
  lat/long stay as bundled) — only preset *labels/descriptions* are
  localized (`app_en.arb`/`app_bn.arb` keys as sketched above), same
  as every other user-facing string in the app.
- **Achievements/notifications untouched** — a preset-created medicine
  or water goal flows through the exact same
  `pendingNotifications()`/achievement-progress paths as a manually
  created one; presets only pre-fill form state.

## Global Constraints

- Three new small const files, one per module, next to that module's
  existing domain constants:
  `lib/features/water/domain/water_goal_presets.dart`,
  `lib/features/medicine/domain/medicine_schedule_presets.dart`,
  `lib/features/prayer/domain/prayer_method_presets.dart`. No shared
  `core/` preset abstraction.
- `MedicineFormScreen`'s new step 0 only appears in the create
  (`editMedicineId == null`) path; step numbering/progress bar shifts
  from `/3` to `/4` accordingly.
- `PrayerSettingsScreen`'s preset banner visibility is
  `locationMode == auto && !_gpsPresetAcknowledged`, where the latter is
  a new local `bool` on a `ConsumerStatefulWidget` (converted from
  today's `ConsumerWidget`) — not a persisted flag, resets each time the
  screen is reopened.
- `WaterSettingsScreen`'s goal `_GoalField` call site gains
  `key: ValueKey(goal.goalMl)` so preset taps (which change
  `initialValue` externally) force the field's `late final`
  `TextEditingController` to re-seed instead of going stale.
- Medicine's new step-0 preset tiles are plain `Card`/`ListTile` +
  `onTap` (not `RadioListTile`/`RadioGroup`) since a tap is a one-shot
  action that leaves step 0 immediately.
- New l10n keys go in both `app_en.arb` and `app_bn.arb`
  (`waterPresetLight/Standard/Active`, `medPreset*`/`medPreset*Desc`,
  `prayerPresetUseGps/HanafiDhaka/StandardMwl`).

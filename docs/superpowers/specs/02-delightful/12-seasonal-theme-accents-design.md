# Seasonal Theme Accents (Eid/New Year)

**Category:** Delightful · **Atlas complexity:** M · **Retention impact:** Low-Medium
**Date:** 2026-07-23
**Status:** Draft — pending review (date-detection prerequisite below is
not yet resolved; see Global Constraints)

## Problem

`AppTheme` (`lib/core/theme/app_theme.dart`) has exactly one seed color,
`_seedColor` (`Color(0xFF006874)`, a fixed top-level `const`, line 7),
consumed by `AppTheme._build` (lines 80-95) which does
`ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness)` —
no parameter exists today to override the seed per-call. `AppTheme.light`/
`.dark` (lines 66-78) take only `{required bool isBangla}`. The two call
sites are `lib/main.dart:220-221`
(`theme: AppTheme.light(isBangla: isBangla), darkTheme: AppTheme.dark
(isBangla: isBangla)`), inside `HabitTrackerApp.build`, which already
`ref.watch`es `themeControllerProvider`/`localeControllerProvider` for
its other two inputs — this is exactly where a third watched value
(the seasonal seed, if any) would plug in.

`ModuleAccents` (lines 11-22: `water`/`medicine`/`prayer`, three fixed
`Color` literals) and `AppSemanticColors` (lines 29-59, the `success`
green `ThemeExtension`) are **structurally untouched by any seed change**
— neither derives from `ColorScheme.fromSeed` or reads `_seedColor` at
all, so swapping the seed color for a seasonal one automatically
satisfies this item's own non-goal ("no changes to per-module accent
colors' semantic meaning") for free, with zero extra guard code needed.

**No display-name field, no Hijri-date source, and no seasonal-toggle
field exist anywhere in the codebase today** (verified): `AppSettings`
(`lib/features/settings/domain/entities/app_settings.dart:42-58`) has no
boolean remotely related to this; `pubspec.yaml` has no Hijri/lunar-
calendar package (only `adhan_dart`, which — checked its `lib/` source —
exposes prayer-time calculation, not Gregorian↔Hijri conversion). This
is the **same unresolved dependency** `01-ramadan-mode-design.md` already
flags for Ramadan-start detection (its own "Open questions" section:
"Hijri date detection: pull a dependency, or maintain a manually-updated
date range per year"). **Not re-researched here** — flagged as a shared
prerequisite both items need solved once, not twice; whichever of the two
is implemented first should build the shared date-source, the second
reuses it.

## Design

**Extend `AppTheme`'s existing seed mechanism — no parallel theming
system.** `app_theme.dart` changes:

```dart
/// A curated seasonal accent — a substitute seed color, applied only
/// when Settings' opt-out isn't set and today falls in the active window.
class SeasonalAccent {
  const SeasonalAccent({required this.occasion, required this.seedColor});
  final SeasonalOccasion occasion;
  final Color seedColor;

  /// Pohela Boishakh — traditional red-and-white motif.
  static const poholaBoishakh = SeasonalAccent(
    occasion: SeasonalOccasion.poholaBoishakh,
    seedColor: Color(0xFFC62828),
  );

  /// Both Eid occasions share one accent (traditional Eid green) — a
  /// curated design decision, not a per-Eid distinction.
  static const eid = SeasonalAccent(
    occasion: SeasonalOccasion.eid,
    seedColor: Color(0xFF2E7D32),
  );
}
```

`AppTheme.light`/`.dark` gain an optional param, default `null` (no
behavior change for every existing call site that doesn't pass one):

```dart
static ThemeData light({required bool isBangla, Color? seasonalSeed}) =>
    _build(
      brightness: Brightness.light,
      semanticColors: AppSemanticColors.light,
      isBangla: isBangla,
      seedColor: seasonalSeed ?? _seedColor,
    );
```
(`.dark` mirrors it; `_build` gains a `required Color seedColor` param,
replacing its current hardcoded reference to `_seedColor` at line 86 —
the only line inside `_build` that changes).

**Date detection — new file, `lib/core/theme/seasonal_occasion.dart`:**

```dart
/// A curated seasonal occasion this app acknowledges cosmetically.
enum SeasonalOccasion { poholaBoishakh, eid }

/// Pure — returns the active occasion for [today], or `null` if none is
/// active. Takes an explicit [LocalDate] rather than calling
/// `clock.now()` itself, so it's unit-testable and reusable from a
/// `Consumer` that reads the clock once per build
/// (`core/utils/local_date.dart`, same convention as
/// `greetingPeriodFor` in `11-personalized-dashboard-greeting-design.md`).
///
/// Pohela Boishakh (14 April, Gregorian — fixed, no calendar-conversion
/// dependency needed) gets a same-day-plus-one-either-side window.
/// Eid-ul-Fitr/Eid-ul-Adha need a Hijri date source this app doesn't
/// have yet — see this file's Problem section; until that prerequisite
/// lands, [SeasonalOccasion.eid] detection returns `null` unconditionally
/// (dead code path, not wired to a fake/guessed date range).
SeasonalOccasion? activeSeasonalOccasion(LocalDate today) {
  if (today.month == 4 && (today.day - 14).abs() <= 1) {
    return SeasonalOccasion.poholaBoishakh;
  }
  // TODO(seasonal-eid): wire once a Hijri date source exists
  // (shared prerequisite with Ramadan mode, item 1).
  return null;
}
```

**Settings — one new opt-out boolean, following the existing
`quietHoursEnabled` pattern exactly:**

`AppSettings` (`app_settings.dart`) gains `required bool
seasonalAccentsEnabled,` — **not nullable, needs a default**, so (unlike
`11`'s `displayName`) this one does need a `withDefault` at the DB layer
and a value in `_ensureSeeded`'s insert.

`app_settings_table.dart` gains:
```dart
/// Opt-out for the seasonal palette shift (Eid/Pohela Boishakh) —
/// default `true` (opt-in by default, matching the feature's own
/// "festive but tasteful" framing), flip off for users who never want
/// the app's look to change.
BoolColumn get seasonalAccentsEnabled =>
    boolean().withDefault(const Constant(true))();
```

`app_database.dart` — same `schemaVersion` 7 → 8 bump
`11-personalized-dashboard-greeting-design.md` needs; **both columns
belong in one `if (from < 8)` block**, not two separate version bumps —
whichever of the two specs is implemented second must check
`app_database.dart`'s current `schemaVersion` first and fold its
`addColumn` into the existing block rather than bumping to 9.

`SettingsRepository` gains `Future<Result<void>>
updateSeasonalAccentsEnabled({required bool enabled});`, implemented in
`SettingsRepositoryImpl._update(...)` the same way as
`updateBiometricEnabled`; `_ensureSeeded`'s insert
(`settings_repository_impl.dart:45-56`) needs no new explicit value since
`withDefault(true)` covers a fresh row, but `_toDomain` (line 151) still
needs `seasonalAccentsEnabled: row.seasonalAccentsEnabled,` added.

**Toggle UI** — `ThemeSettingsScreen`
(`lib/features/settings/presentation/screens/theme_settings_screen.dart`),
one new `SwitchListTile` below the existing `SegmentedButton<ThemeMode>`
(after line 38), same shape as `QuietHoursScreen`'s toggle
(`quiet_hours_screen.dart:34-42`):
```dart
SwitchListTile(
  title: Text(l10n.settingsSeasonalAccentsToggle),
  subtitle: Text(l10n.settingsSeasonalAccentsDescription),
  value: settings.seasonalAccentsEnabled,
  onChanged: (value) => ref
      .read(settingsRepositoryProvider)
      .updateSeasonalAccentsEnabled(enabled: value),
),
```
(`ThemeSettingsScreen` becomes a `Consumer`/needs `appSettingsProvider`
watched alongside the existing `themeControllerProvider` watch, to read
`settings.seasonalAccentsEnabled`.)

**Wiring into `main.dart`** — a new small Riverpod provider,
`lib/core/theme/seasonal_accent_provider.dart`:
```dart
/// The active seasonal seed color, or `null` if none applies today
/// (opted out, or no occasion active) — `HabitTrackerApp.build` reads
/// this alongside `themeControllerProvider`/`localeControllerProvider`.
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
`main.dart:220-221` becomes:
```dart
final seasonalSeed = ref.watch(seasonalAccentSeedProvider);
...
theme: AppTheme.light(isBangla: isBangla, seasonalSeed: seasonalSeed),
darkTheme: AppTheme.dark(isBangla: isBangla, seasonalSeed: seasonalSeed),
```
No lingering state to revert: the provider is a pure computed read of
`clock.now()` + settings each rebuild — once the date window passes, the
next rebuild (app resume, at minimum) simply recomputes `null` and the
theme reverts to `_seedColor` on its own, with no separate "turn it back
off" code path needed.

**Exact l10n keys** (both `app_en.arb`/`app_bn.arb`):
```json
"settingsSeasonalAccentsToggle": "Seasonal color accents",
"settingsSeasonalAccentsDescription": "Subtly shift the app's color around Eid and Pohela Boishakh"
```

## Out of scope

- **Eid-ul-Fitr/Eid-ul-Adha date detection.** Blocked on the Hijri-date-
  source prerequisite; `SeasonalOccasion.eid` ships permanently
  unreachable until that prerequisite lands elsewhere. Not solved here.
- **Per-occasion granular opt-out.** One boolean, all-or-nothing — the
  original item's own "likely overkill for v1" open question, resolved.
- **New illustration/decorative assets** — accent color only, per the
  original non-goal; doesn't interact with `09`'s `CustomPainter`
  illustrations, which stay in `ModuleAccents` colors regardless.
- **Other candidate dates** (Independence Day, Victory Day) — curated set
  stays exactly the three named occasions; adding more is a design
  decision, not an engineering change, if ever wanted.
- **A shared date-awareness module with Ramadan mode**, built now.
  `activeSeasonalOccasion` stays self-contained until Ramadan mode's own
  implementation round exists to point at — building a shared
  abstraction against a spec that isn't implemented yet is guessing its
  shape. Once a Hijri source exists, the second feature imports it.

## Global Constraints

- **No new dependency for Pohela Boishakh** (pure Gregorian month/day
  check). **Eid detection has an unresolved dependency** — a Hijri-
  calendar date source, absent from `pubspec.yaml` today (`adhan_dart`
  doesn't provide Hijri conversion — checked its `lib/` source). This
  spec ships Pohela Boishakh only; Eid stays a documented no-op until
  that prerequisite (shared with item 1, Ramadan mode) is resolved.
- **Schema migration required**: `schemaVersion` 7 → 8, one `addColumn`
  for `app_settings.seasonal_accents_enabled` (`BoolColumn`, default
  `true`). **Coordinate with `11-personalized-dashboard-greeting-design
  .md`** — both target the same next schema version; fold into one
  migration block if both ship together.
- New files: `lib/core/theme/seasonal_occasion.dart`
  (`SeasonalOccasion` + `activeSeasonalOccasion`), `lib/core/theme/
  seasonal_accent_provider.dart` (`seasonalAccentSeedProvider`); a
  `SeasonalAccent` class added directly to `app_theme.dart`, colocated
  with `ModuleAccents`.
- Modified files: `app_theme.dart` (`AppTheme.light`/`.dark`/`_build`
  gain the optional seed override), `app_settings.dart`,
  `app_settings_table.dart`, `app_database.dart` (migration),
  `settings_repository.dart`/`settings_repository_impl.dart`
  (`updateSeasonalAccentsEnabled`), `theme_settings_screen.dart` (new
  toggle), `main.dart` (watch the new provider, pass `seasonalSeed`
  through).
- `ModuleAccents`/`AppSemanticColors` are unmodified — neither derives
  from `_seedColor`/`ColorScheme.fromSeed`, so a seed swap can't touch
  them structurally.

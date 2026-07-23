# Ramadan Mode

**Category:** Delightful · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — implementation-ready

## Problem

For a Bangladesh-first, Muslim-persona-heavy app, Ramadan is the single
highest-salience month of the year, and today the app has zero awareness of
it. Concretely, two real gaps exist in the current code:

- **Water nags through the fast.** `WaterModule.pendingNotifications()`
  (`lib/features/water/water_module.dart:124-171`) builds reminder slots
  purely from `WaterSettings.reminderWindowStart`/`reminderWindowEnd`
  (fixed `LocalTime` values, optionally overridden per-weekday via
  `reminderWindowOverrides` — see `water_settings.dart:12-20`) stepped every
  `reminderIntervalMinutes`. There is no concept of "skip this window on
  fasting days" — during Ramadan a default `06:00`–`22:00` window fires
  reminders straight through Sehri-to-Iftar with no fasting awareness at
  all.
- **Prayer has no Ramadan framing.** `PrayerModule` renders every prayer
  identically year-round — `dashboardSummary`/`nextUpcoming`
  (`lib/features/prayer/prayer_module.dart:82-109`, `278-300`) always title-case
  the raw `PrayerName`. There is no "Sehri ends"/"Iftar" relabeling of
  Fajr/Maghrib, and no Hijri-calendar awareness anywhere in the codebase —
  confirmed by grep: `adhan_dart` (`pubspec.yaml:13`, v2.0.1) exposes no
  Hijri conversion (its `lib/src/*.dart` files are `CalculationParameters`,
  `Coordinates`, `PrayerTimes`, `Qibla`, `SolarTime`, etc. — nothing
  Hijri-related), and no other dependency in `pubspec.yaml` provides one
  either.
- **Prayer already computes exactly the two instants this feature needs.**
  `calculatePrayerTimes()` (`lib/features/prayer/domain/usecases
  /calculate_prayer_times.dart:24-63`) returns a `PrayerTimes` typedef
  record `(fajr, dhuhr, asr, maghrib, isha)` in UTC, given a `LocalDate` +
  lat/long/timezone + `CalculationMethod`/`AsrMethod`. `fajr` and `maghrib`
  are Sehri-ends and Iftar-begins, respectively — no new calculation
  engine needed, only a caller.
- **Location is already solved.** `resolveLocation()`
  (`lib/features/prayer/data/location_resolver.dart:14-67`) returns a
  `Result<ResolvedLocation>` (`(latitude, longitude, ianaTimezone)`) from
  either GPS (`geolocator`) or the user's manual `PrayerSettings` fields.
  Water has no location concept today; Ramadan mode is the first thing
  that makes Water depend on Prayer's location, not the reverse.

## Design

### 1. Hijri detection — new dependency: `hijri`

No existing dependency does Gregorian↔Hijri conversion. Add
`hijri: ^3.0.0` (pure-Dart, Umm al-Qura-based, zero transitive deps —
the standard, actively-maintained choice; no network calls, so it doesn't
touch the app's offline-first posture). New file:

`lib/core/utils/hijri_date.dart`
```dart
/// Whether [gregorianDate] falls within Ramadan (Hijri month 9),
/// per the Umm al-Qura calendar `package:hijri` implements. Pure,
/// deterministic, no I/O — safe to call from `pendingNotifications()`.
bool isRamadan(LocalDate gregorianDate);

/// The Hijri day-of-Ramadan (1-30), or `null` if [gregorianDate] isn't
/// in Ramadan. Powers "Day 14 of Ramadan" framing if the UI wants it.
int? ramadanDayNumber(LocalDate gregorianDate);
```
Umm al-Qura is a calculated calendar, not local moon-sighting — good
enough for reminder scheduling (off by at most a day around the
boundary, self-correcting the next day), explicitly not good enough to
claim liturgical authority; the settings toggle (below) exists precisely
because auto-detection near the Ramadan boundary can be a day off from
what the user's community observes.

### 2. Settings: new `app_settings` columns, not a new table

Ramadan mode is a single cross-module flag Water and Prayer both read —
same shape as the existing `quietHoursEnabled` toggle
(`app_settings_table.dart:44-46`), not module-owned. Add to
`AppSettingsTable` (`lib/core/database/tables/app_settings_table.dart`):

```dart
/// Manual override: `true`/`false` pins the mode; `null` (default) means
/// "follow `isRamadan(today)` automatically" (FR-new).
BoolColumn get ramadanModeManualOverride => boolean().nullable()();

/// Whether Ramadan-mode auto-detection is enabled at all — the
/// first-run/never-observes-Ramadan opt-out. Default `true`; a user who
/// turns it off never sees the mode regardless of the Hijri date.
BoolColumn get ramadanAutoDetectEnabled =>
    boolean().withDefault(const Constant(true))();
```
Mirrors `AppSettings` (`lib/features/settings/domain/entities
/app_settings.dart:43-58`) with matching fields. `schemaVersion` bumps
`7 → 8`; `AppDatabase.migration`'s `onUpgrade`
(`lib/core/database/app_database.dart:59-110`) gets one more
`if (from < 8) { await m.addColumn(appSettingsTable,
appSettingsTable.ramadanModeManualOverride); await
m.addColumn(appSettingsTable, appSettingsTable.ramadanAutoDetectEnabled);
}` block — no other file needs to change for the migration itself, per
the class doc's existing seam comment (line 107-109).

Effective-mode resolution (a pure helper, not stored):
```dart
/// `ramadanModeManualOverride` wins if set; otherwise falls back to
/// `isRamadan(today)` when `ramadanAutoDetectEnabled`, else always false.
bool resolveRamadanModeActive(AppSettings settings, LocalDate today);
```

### 3. Water: parametrize the reminder window by Fajr/Maghrib, per day

`WaterModule.pendingNotifications()` currently computes `windowStartTime`/
`windowEndTime` per day purely from `settings.reminderWindowOverrides[weekday]`
(`water_module.dart:134-136`). Change: `WaterModule`'s constructor gains an
optional `PrayerRepository? _prayerRepository` (nullable — Water must not
hard-depend on Prayer being registered; see Open question below), and the
per-day-offset loop becomes:

```dart
for (var dayOffset = 0; dayOffset <= _lookaheadDays; dayOffset++) {
  final day = localDayKey(now).addDays(dayOffset);
  final ramadanActive = resolveRamadanModeActive(appSettings, day);
  final (windowStartTime, windowEndTime) = ramadanActive && _prayerRepository != null
      ? await _fastingAwareWindow(day, appSettings)  // Maghrib -> next day's Fajr
      : _weekdayWindow(day, settings);                // existing override logic, unchanged
  ...
}
```
`_fastingAwareWindow` calls `resolveLocation()` +
`calculatePrayerTimes()` (already imported by Prayer, newly imported by
Water) for `day`, converts `maghrib`/`fajr` (next day) from UTC to local
`LocalTime`, and clips the window to whichever is narrower against the
user's own `reminderWindowStart`/`End` (so a user who only wants morning
reminders anyway isn't suddenly nudged at 9pm right after Iftar). If
location resolution fails (`Failure` — no permission, no manual location
set), fall back to the existing weekday-window logic unchanged — Ramadan
mode degrades to "no behavior change" rather than throwing, matching the
Result-based error handling already used throughout (`core/error/result.dart`).

### 4. Sehri/Iftar countdown

Reuses the same "next upcoming" mechanism the dashboard already has per
module — `HabitModule.nextUpcoming(WidgetRef ref)`
(`PrayerModule.nextUpcoming`, `prayer_module.dart:278-300`, currently
returns a `Chip` naming the next prayer). When Ramadan mode is active,
`PrayerModule.nextUpcoming` swaps its label: if the next unprayed record
is Fajr, show "Sehri ends in {countdown}"; if it's Maghrib, show "Iftar in
{countdown}" — computed from `record.scheduledFor - clock.now()`, formatted
via a small new `formatCountdown(Duration)` helper (`lib/core/utils
/countdown_format.dart`, e.g. "42 min", "2h 15m" — no new package, just
`Duration` arithmetic). No new dashboard widget/route: this is a label
change on the existing `nextUpcoming()` chip, consistent with "reuse the
upcoming strip, don't invent a new one" per the CLAUDE.md Run 15 note that
item 08's dashboard countdown tile could piggyback on the same mechanism.

### 5. Prayer framing: Fajr → "Sehri ends", Maghrib → "Iftar"

Purely presentational — `PrayerModule.dashboardSummary`/`nextUpcoming`
and `PrayerHomeScreen`'s tile labels (wherever `_titleCase(record
.prayerName.name)` is called, e.g. `prayer_module.dart:156`, `293`)
branch on `resolveRamadanModeActive` + `record.prayerName == fajr/maghrib`
to substitute the new l10n strings below instead of the plain prayer
name. `calculatePrayerTimes()` itself is untouched — no new calculation
logic, per the existing spec's non-goal, now made concrete: the branch
lives entirely in presentation-layer label selection.

### New l10n keys (`app_en.arb`/`app_bn.arb`)

- `ramadanModeSettingsTitle` — "Ramadan mode"
- `ramadanModeSettingsSubtitle` — "Shift water reminders outside fasting hours and show Sehri/Iftar countdowns"
- `ramadanModeAutoDetectToggle` — "Detect Ramadan automatically"
- `ramadanModeManualToggle` — "Ramadan mode"
- `sehriEndsCountdown` — "Sehri ends in {duration}" (ICU `{duration}` placeholder, string already formatted by `formatCountdown`)
- `iftarCountdown` — "Iftar in {duration}"
- `sehriEndsLabel` — "Sehri ends" (replaces "Fajr" row label)
- `iftarLabel` — "Iftar" (replaces "Maghrib" row label)

## Out of scope

- No new prayer-calculation method or fiqh logic beyond what
  `calculatePrayerTimes()` already computes (unchanged from the original draft).
- No fasting-tracking module (meals, calories, water-intake-during-eating-hours) — this is reminder/timing behavior only.
- No changes to Medicine's scheduling — dose timing during fasting stays a personal medical decision the app doesn't reinterpret.
- No moon-sighting/regional-announcement Ramadan-start override — Umm al-Qura calculation only, with the manual toggle as the escape hatch when it's wrong for a given user's community.
- No retroactive re-plan of notifications already materialized for "today" the moment the toggle flips mid-day — the existing 3-day window (`notification_planner.dart`'s `windowDays = 3` default, `planNotifications()` at `notification_planner.dart:59-97`) naturally picks up the new window on its next re-plan trigger (app resume, WorkManager's 8-hour top-up per `notification_workmanager.dart:39`, or any post-action re-plan) — no special-cased immediate re-plan is being built for the toggle itself.
- No Wear OS complication changes for the countdown in this pass.

## Global Constraints

- **New dependency:** `hijri: ^3.0.0` (pure Dart, no transitive deps, no network).
- **Migration:** `schemaVersion` 7 → 8. Two nullable/defaulted columns added to `AppSettingsTable`: `ramadanModeManualOverride` (nullable bool), `ramadanAutoDetectEnabled` (bool, default `true`). One new `if (from < 8)` block in `AppDatabase.migration.onUpgrade` (`app_database.dart:59-110`); no other schema file changes.
- **New cross-module coupling:** `WaterModule` gains an optional dependency on Prayer's `resolveLocation()`/`calculatePrayerTimes()` (via an injected nullable `PrayerRepository`/location resolver, not a hard import of `PrayerModule` itself — Water must keep working with Prayer's module absent from `module_registry.dart`). This is a deliberate, documented exception to Water's prior 100%-self-contained design.
- **No changes to `notification_planner.dart`'s core window/cap/diff logic** (`planNotifications()`, `notification_planner.dart:59-97) — Ramadan mode only changes what `WaterModule.pendingNotifications()` feeds into that unchanged pipeline.
- New l10n keys listed above, both `app_en.arb`/`app_bn.arb`.
- Settings UI: one new toggle group in `data_settings_screen.dart` (or a new `ramadan_settings_screen.dart` under `lib/features/settings/presentation/screens/`, following the existing `quiet_hours_screen.dart` pattern for a dedicated sub-screen) — auto-detect toggle + manual override toggle, per the existing `AppSettings`-backed settings pattern (`SettingsRepositoryImpl`, `theme_controller.dart`-style Riverpod wiring).

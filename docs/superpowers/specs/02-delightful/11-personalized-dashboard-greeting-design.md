# Personalized Greeting on Dashboard Open

**Category:** Delightful · **Atlas complexity:** S · **Retention impact:** Low-Medium
**Date:** 2026-07-23
**Status:** Draft — pending review

## Problem

`DashboardScreen` (`lib/features/dashboard/presentation/screens/
dashboard_screen.dart`) opens straight into `_DayCompletionIndicator`
(line 67) with no header content above it at all — no greeting, no
personalization, nothing between the `AppBar` and the progress bar.

**The "display name already exists in Settings" premise in this item's
original draft is wrong — verified against the real entity.**
`AppSettings` (`lib/features/settings/domain/entities/app_settings.dart:
42-58`) has exactly these fields: `locale`, `themeMode`, `waterUnit`,
`pinEnabled`, `pinLockTimeoutSeconds`, `biometricEnabled`,
`screenPrivacyEnabled`, `onboardingCompletedAt`, `lastSeenAppVersion`,
`quietHoursEnabled`, `quietHoursStart`, `quietHoursEnd`. No name field of
any kind. There is also no onboarding-flow UI anywhere in `lib/` —
`onboardingCompletedAt` is written and read only by `app_settings_table
.dart`/`settings_repository_impl.dart`, grepping the rest of `lib/` for
`onboardingCompletedAt` turns up zero presentation-layer hits — so there
is no existing "ask for a name during setup" moment to hook into either.
**This item therefore needs one small new field, not just reads
something that's already there.**

The app's clock convention (`clock.now()`, never raw `DateTime.now()`,
per `CLAUDE.md`) is followed almost everywhere pure/domain logic needs
"now" — but **`DashboardScreen` itself is already a live exception**:
`_DayCompletionIndicator.build` (`dashboard_screen.dart:90`) and
`_GlobalCalendarSheetState` (`dashboard_screen.dart:161`) both call raw
`DateTime.now()` today. Not this item's job to fix those, but the new
greeting logic must not add a third instance of the same drift — it uses
`clock.now()` from the start.

A reusable small text-entry pattern already exists for exactly this
shape of input: `showNoteEditorSheet` (`lib/core/widgets/note_editor_sheet
.dart`) is a `showModalBottomSheet` with one `TextFormField` + a Save
button, `canonicalizeNote` trimming/null-collapsing the result. It's
note-specific (its own l10n copy, `noteMaxLength`), so this item follows
the same *shape*, not the same function.

## Design

**Data model — one new nullable field, no default, matching the
`lastSeenAppVersion`/`onboardingCompletedAt` precedent (optional,
non-`required` in the Freezed constructor so existing call sites don't
break):**

`lib/features/settings/domain/entities/app_settings.dart` — add
`String? displayName,` to the `AppSettings` factory (after
`lastSeenAppVersion`).

`lib/core/database/tables/app_settings_table.dart` — add:
```dart
/// Optional user-set display name for the dashboard greeting; null =
/// no name set, greeting degrades to a name-less form.
TextColumn get displayName => text().nullable()();
```

`lib/core/database/app_database.dart` — bump `schemaVersion` from `7` to
`8`, add:
```dart
if (from < 8) {
  await m.addColumn(appSettingsTable, appSettingsTable.displayName);
}
```
(new trailing block, same shape as the existing `from < 7` block at
lines 100-106). **Note:** if `12-seasonal-theme-accents-design.md`'s own
`seasonalAccentsEnabled` column lands in the same release, both belong
in the same `if (from < 8)` block, not two separate schema bumps — flag
this at merge time, whichever spec is implemented second checks the
other's `schemaVersion` first.

`SettingsRepository` (`lib/features/settings/domain/repositories/
settings_repository.dart`) gains:
```dart
/// Updates the display name shown in the dashboard greeting. `null`/
/// empty clears it back to the name-less greeting.
Future<Result<void>> updateDisplayName(String? name);
```
implemented in `SettingsRepositoryImpl` the same `_update(...)` way as
`updateLastSeenAppVersion`; `_toDomain` gains `displayName:
row.displayName,`.

**Where the name gets entered:** a new `ListTile` in
`SettingsHomeScreen` (`lib/features/settings/presentation/screens/
settings_home_screen.dart`), in a new `_SectionHeader(l10n.
settingsProfile)` block inserted first, before `settingsAppearance`
(line 24) — subtitle shows the current name or nothing, `onTap` shows a
small bottom sheet modeled on `note_editor_sheet.dart`'s shape (own file,
`lib/features/settings/presentation/widgets/display_name_editor_sheet
.dart`, single `TextFormField`, `maxLength: 40`, Save button calling
`ref.read(settingsRepositoryProvider).updateDisplayName(...)` with the
trimmed/null-if-empty result). No forced entry anywhere — the field
starts `null` for every install, exactly like `onboardingCompletedAt`
does today.

**Time-of-day bucketing — new pure function, `lib/core/utils/greeting
.dart`:**
```dart
/// Time-of-day bucket for the dashboard greeting. Boundaries: morning
/// 05:00-11:59, afternoon 12:00-16:59, evening 17:00-20:59, night
/// 21:00-04:59.
enum GreetingPeriod { morning, afternoon, evening, night }

/// Pure — takes [now] explicitly rather than calling `clock.now()`
/// itself, so it's unit-testable without `withClock` and reusable from
/// a `Consumer` build method that reads the clock once per build.
GreetingPeriod greetingPeriodFor(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) return GreetingPeriod.morning;
  if (hour >= 12 && hour < 17) return GreetingPeriod.afternoon;
  if (hour >= 17 && hour < 21) return GreetingPeriod.evening;
  return GreetingPeriod.night;
}
```

**Dashboard insertion point** — `dashboard_screen.dart:64-67`, one new
widget immediately before `_DayCompletionIndicator` in the `ListView`'s
`children`:
```dart
children: [
  _DashboardGreeting(),
  const SizedBox(height: 8),
  _DayCompletionIndicator(modules: modules),
  ...
```
`_DashboardGreeting` is a small `ConsumerWidget` (new private class in
the same file, following `_DayCompletionIndicator`'s own pattern): reads
`ref.watch(appSettingsProvider).value?.displayName`, computes
`greetingPeriodFor(clock.now())`, and renders one of 8 l10n strings
(4 periods × name-present/name-absent) via `Text(..., style: Theme.of
(context).textTheme.headlineSmall)`.

**Exact l10n keys** (both `app_en.arb`/`app_bn.arb`):

```json
"dashboardGreetingMorning": "Good morning",
"dashboardGreetingMorningNamed": "Good morning, {name}",
"dashboardGreetingAfternoon": "Good afternoon",
"dashboardGreetingAfternoonNamed": "Good afternoon, {name}",
"dashboardGreetingEvening": "Good evening",
"dashboardGreetingEveningNamed": "Good evening, {name}",
"dashboardGreetingNight": "Hello",
"dashboardGreetingNightNamed": "Hello, {name}",
"settingsProfile": "Profile",
"settingsDisplayName": "Your name",
"settingsDisplayNameNotSet": "Not set"
```
each `...Named` key gets a `"placeholders": {"name": {"type": "String"}}`
metadata block, matching the existing `heatmapCellCompleteSemantics`
convention (`app_en.arb:178-185`). Bangla (`app_bn.arb`) greeting copy is
a judgment call, not a literal translation — "Hello"/"হ্যালো" for the
night bucket rather than a stilted literal "good night" used as a
greeting (Bangla conventionally uses "শুভ রাত্রি" as a farewell, not a
greeting) — flagged here for whoever writes the Bangla strings, not
resolved by this spec.

## Out of scope

- **Backup/restore of `displayName`.** `export_orchestrator.dart`'s
  `_appSettingsToJson` and `import_orchestrator.dart`'s `restoreSettings`
  call already omit `onboardingCompletedAt`/`lastSeenAppVersion` today —
  `displayName` follows the same precedent (not backed up) rather than
  being a new gap this item introduces.
- **Day-completion-aware greeting variants** ("all done for today!") —
  strictly time-of-day, per the original item's own non-goal.
- **Forced name entry / onboarding flow.** No onboarding UI exists at all
  today (confirmed above); this item does not create one — the name
  entry point is a plain optional Settings row, nothing more.
- **Fixing `DashboardScreen`'s existing raw `DateTime.now()` calls**
  (lines 90, 161) — pre-existing, out of scope for this change; only the
  new greeting code follows `clock.now()`.
- **Per-module or per-achievement greeting variation** — one consistent
  greeting line, per the original item's own non-goal.

## Global Constraints

- **Schema migration required**, contrary to the original draft's
  assumption. `schemaVersion` 7 → 8, one `addColumn` for
  `app_settings.display_name` (nullable `TextColumn`, no default).
- No new dependency — `clock`, `flutter_riverpod`, and the existing
  `AppLocalizations` machinery cover everything.
- New files: `lib/core/utils/greeting.dart` (`GreetingPeriod` +
  `greetingPeriodFor`), `lib/features/settings/presentation/widgets/
  display_name_editor_sheet.dart`.
- Modified files: `app_settings.dart` (entity), `app_settings_table.dart`,
  `app_database.dart` (migration), `settings_repository.dart`/
  `settings_repository_impl.dart` (`updateDisplayName`),
  `settings_home_screen.dart` (new Profile section),
  `dashboard_screen.dart` (`_DashboardGreeting` insertion).
- `displayName` max length: 40 characters, UI-enforced
  (`TextField.maxLength`), no DB `CHECK` constraint — same "UI caps
  input" precedent as `noteMaxLength` (`core/widgets/note_editor_sheet
  .dart`).

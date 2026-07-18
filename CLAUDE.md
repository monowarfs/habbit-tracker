# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Runs 05-06 complete: app shell + core infrastructure. Riverpod (codegen) +
GoRouter `StatefulShellRoute` bottom-nav (Dashboard/Water/Medicine/Prayer/
Settings, all placeholder screens except Settings), Material 3 theme
(light/dark/system, teal seed, per-module accents, `AppSemanticColors`
extension, Bangla line-height adjustment), en/bn localization via
`gen_l10n`, the `HabitModule` plugin contract + empty `module_registry.dart`.
Drift database (common tables only: `app_settings`/`notification_ledger`/
`achievements`), settings now persist for real (theme/locale survive
restart), `AppException`/`Result<T>` error taxonomy, rotating-file logger,
injected-clock (`package:clock`) + DST-safe `localDayKey` day-bucketing,
top-level error boundary (`runZonedGuarded` + `ErrorWidget.builder`).
No module (Water/Medicine/Prayer), no notifications, no PIN lock yet.
`docs/engineering/phases-and-dod.md`'s run numbering predates this run
being inserted — see the Architecture section's note before trusting its
exact run numbers for what comes next.

Org id: `dev.shurjomoy.habittracker` (Android `applicationId`
`dev.shurjomoy.habit_tracker`, iOS bundle id `dev.shurjomoy.habitTracker`).
Android minSdk 26 (Oreo — notification channels, needed once
`flutter_local_notifications` lands in Run 08).

## Commands

```
flutter pub get                                              # install dependencies
dart run build_runner build --delete-conflicting-outputs     # generate *.g.dart (Riverpod codegen)
flutter gen-l10n                                              # generate AppLocalizations from lib/core/l10n/*.arb
flutter run                                                   # run on connected device/simulator/emulator
flutter test                                                  # run all tests
flutter test test/widget_test.dart                            # run a single test file
flutter analyze                                               # static analysis / lint (uses analysis_options.yaml)
dart format --output=none --set-exit-if-changed .             # format check
```

Requires Flutter SDK `^3.12.2` (see `pubspec.yaml`). `*.g.dart` and
`gen_l10n`'s generated `lib/core/l10n/app_localizations*.dart` are
`.gitignore`d — regenerate them after `flutter pub get` on a fresh clone.

## Architecture

Feature-first, Clean Architecture (`domain`/`data`/`presentation`) per
`docs/technical/architecture.md` and `docs/technical/folder-structure.md`.

- `lib/main.dart` — entry point: `ProviderScope` → `HabitTrackerApp`
  (`MaterialApp.router` wired to the theme/locale controllers and the router).
- `lib/core/router/app_router.dart` — `GoRouter` root, `StatefulShellRoute`
  with one branch per bottom-nav tab, typed `AppRoutes` path constants, a
  `/lock` redirect stub (always allows — real PIN check lands in Run 12).
- `lib/core/theme/app_theme.dart` — `ColorScheme.fromSeed` light/dark
  themes, per-module `ModuleAccents`, the `AppSemanticColors` theme
  extension (the "success" green), the bn line-height `TextTheme` adjustment.
- `lib/core/l10n/` — `app_en.arb`/`app_bn.arb` (source of truth; generated
  `AppLocalizations` not committed).
- `lib/core/modules/habit_module.dart` — the `HabitModule` plugin contract
  (`module_registry.dart` holds the one shared, currently-empty list).
- `lib/core/database/app_database.dart` — the single Drift `@DriftDatabase`
  class; every table (from every module) must be listed here — the one
  Drift-forced central touchpoint, documented on the class itself and in
  `docs/technical/database-design.md`.
- `lib/core/error/{app_exception,result}.dart` — the `AppException`/
  `Result<T>` Freezed unions repositories/use cases return instead of
  throwing (`docs/strategies/error-handling-logging.md`).
- `lib/core/logging/app_logger.dart` — the `logger` singleton, rotating
  ~1MB log file, `entityRef()` redaction helper.
- `lib/core/utils/{local_date,local_day}.dart` — `LocalDate`/`LocalTime`
  value types and the DST-safe `localDayKey()` bucketing helper. Domain
  logic uses `package:clock`'s `clock.now()`, never `DateTime.now()`.
- `lib/features/settings/` — full `domain`/`data`/`presentation` slice:
  `AppSettings` entity + `AppLocale`/`AppThemeMode`/`WaterUnit` domain
  enums, `SettingsRepository`/`SettingsRepositoryImpl` (Drift-backed,
  seeds the singleton row on first read), `theme_controller.dart`/
  `locale_controller.dart` (derive from the DB-backed `appSettingsProvider`
  stream, map to/from Flutter's `ThemeMode`/`Locale` at this boundary).
- `lib/features/{dashboard,water,medicine,prayer}/` — placeholder screens
  per tab; Water/Medicine/Prayer get their real `domain/data` slices in
  later runs. Note: `docs/engineering/phases-and-dod.md` still numbers
  Water as "Run 06," but the actual run prompts being executed inserted
  this core-infrastructure run as 06 instead — the numbering in that doc
  no longer matches execution order and should be reconciled.
- Lint rules come from `package:very_good_analysis/analysis_options.yaml`
  (`public_member_api_docs` enforced; generated code and `lib/core/l10n/**`
  excluded from analysis) — see `docs/engineering/coding-standards.md`.
- Package name is `habit_tracker`; tests import it as `package:habit_tracker/main.dart`.
- Standard multi-platform Flutter targets present (`android/`, `ios/`,
  `linux/`, `macos/`, `web/`, `windows/`); only `android`/`ios` have been
  configured with the real org id so far.

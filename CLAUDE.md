# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Run 05 complete: app shell + common foundation. Riverpod (codegen) + GoRouter
`StatefulShellRoute` bottom-nav (Dashboard/Water/Medicine/Prayer/Settings,
all placeholder screens except Settings), Material 3 theme
(light/dark/system, teal seed, per-module accents, `AppSemanticColors`
extension, Bangla line-height adjustment), en/bn localization via
`gen_l10n`, the `HabitModule` plugin contract + empty `module_registry.dart`.
No module (Water/Medicine/Prayer), no database, no notifications, no PIN
lock yet — those are Runs 06-12 per `docs/engineering/phases-and-dod.md`.

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
- `lib/features/settings/presentation/providers/theme_controller.dart` +
  `locale_controller.dart` — in-memory `@riverpod(keepAlive: true)`
  controllers; the seam `app_settings` (DB) plugs into once Run 06 adds
  persistence.
- `lib/features/{dashboard,water,medicine,prayer,settings}/` — placeholder
  screens per tab; Water/Medicine/Prayer get their real `domain/data`
  slices in Runs 06/07-08/09-10 respectively.
- Lint rules come from `package:very_good_analysis/analysis_options.yaml`
  (`public_member_api_docs` enforced; generated code and `lib/core/l10n/**`
  excluded from analysis) — see `docs/engineering/coding-standards.md`.
- Package name is `habit_tracker`; tests import it as `package:habit_tracker/main.dart`.
- Standard multi-platform Flutter targets present (`android/`, `ios/`,
  `linux/`, `macos/`, `web/`, `windows/`); only `android`/`ios` have been
  configured with the real org id so far.

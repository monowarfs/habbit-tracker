# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Runs 05-08 complete: app shell + core infrastructure + the Water module
(the first real module, validating the `HabitModule` plugin contract) +
the notification/reminder engine. Riverpod (codegen) + GoRouter
`StatefulShellRoute` bottom-nav (Dashboard/Water/Medicine/Prayer/Settings),
Material 3 theme (light/dark/system, teal seed, per-module accents,
`AppSemanticColors` extension, Bangla line-height adjustment), en/bn
localization via `gen_l10n`. Drift database (common tables + Water's own
`water_goals`/`water_logs`/`water_settings`), settings persist for real,
`AppException`/`Result<T>` error taxonomy, rotating-file logger,
injected-clock (`package:clock`) + DST-safe `localDayKey` day-bucketing,
top-level error boundary. Water: full domain/data/presentation slice
(goal history, streak/aggregation use cases, quick-add/custom logging,
stats charts + history calendar, reminders now actually scheduled),
registered in `module_registry.dart` (a Riverpod provider, not a bare
list) and wired into the router via `WaterModule().routes`.
`core/notifications/`: `flutter_local_notifications` wrapper
(`NotificationService`), a pure/testable planner (`notification_planner
.dart`) materializing each module's `pendingNotifications()` into a
3-day/64-cap OS-scheduling window, a `notification_ledger`-backed audit
trail, a background-isolate Done/Snooze/Skip action handler, Android-only
WorkManager periodic top-up, permission-explainer + reliability-stub
screens. `HabitModule` gained `onNotificationAction` this run (see
`docs/engineering/phases-and-dod.md`'s Run 08 divergence note — the
original plan bundled notifications into Medicine's own run instead).
Medicine is now a complete module (domain/data/presentation/
notifications in one run, per `docs/superpowers/specs/2026-07-18-
medicine-module-design.md`): repeat-rule engine (`fixed_daily`/
`every_n_days`/`weekday_set`/`prn`, D-03 every-other-day anchoring,
DST-safe), lazily-derived dose status (`upcoming`/`due`/`missed` are
never persisted, only `upcoming`/`done`/`skipped` are — FR-M-06), a pure
dose-materialization planner reused by both the 30-day rolling
`medicine_doses` window (D-13) and the notification engine (no new
call sites — `MedicineModule.pendingNotifications()` itself triggers
materialization on the app-resume/WorkManager triggers Run 08 already
wired), stock ledger + one-shot low-stock crossing detection (FR-M-04),
dose timeline/list/add-form/detail/stats screens, full en/bn
localization. Registered in `module_registry.dart` and wired into the
router the same way Water is. Prayer is now a complete module
(domain/data/presentation/notifications, per `docs/superpowers/specs/
2026-07-19-prayer-module-design.md`): pure `calculatePrayerTimes`
wrapper over `adhan_dart` (golden-tested against Al Adhan API
reference), status derivation (`effectivePrayerStatus`), one-shot
missed-prayer/Qadha crossing detector (`sweepMissedPrayers`), day-based
`planPrayerMaterialization` (30-day rolling window), streak/adherence
calculators, 3 Drift tables (`prayer_settings`/`prayer_records`/
`prayer_qadha_counters`), no-DAO repository, bundled 65-city asset +
GPS/manual location resolver, checklist toggle, history calendar with
per-day coloring, Qadha screen with −1 make-up control, stats screen
with streak/7-day chart/on-time %, settings screen for method/madhab/
Jumu'ah/location/reminders, en/bn localization. Registered in
`module_registry.dart` and wired into the router the same way Water/
Medicine are. Notification channel registered. No PIN lock yet — that's
a future run per `docs/engineering/phases-and-dod.md`.

Run 15 adds a v1.1-class cross-module layer: `HabitModule` gained
`dayStatus`/`nextUpcoming`/`quickActions`/`search`/`achievementDefinitions`
(all three modules implement all five); `core/achievements/` (engine +
repository, evaluated from each module's own write path, not a periodic
sweep) now actually reads/writes the `achievements` table that's existed
schema-only since Run 06; `core/reports/` (`day_status_streaks.dart`,
`aggregate_report_usecase.dart`) backs the new Reports screen
(week/month/year, longest-streak records) and Medicine's adherence-streak
achievements; the dashboard gained a day-completion indicator, upcoming
strip, quick actions, a global month calendar (bottom sheet, not a
route), and cross-module search (`showSearch`/`SearchDelegate`, no new
dependency).

Org id: `dev.shurjomoy.habittracker` (Android `applicationId`
`dev.shurjomoy.habit_tracker`, iOS bundle id `dev.shurjomoy.habitTracker`).
Android minSdk 26 (Oreo — notification channels).

## Spec implementation workflow

When given a spec file to implement (e.g. `docs/superpowers/specs/*.md`),
follow this workflow exactly:

1. Use skill `superpowers:executing-plans` to drive implementation.
2. Create a new git branch for the spec/feature before starting.
3. Follow the plan verbatim — the code is already written in it; do not
   redesign it.
4. Per task, run only that task's own targeted test file — never the full
   `flutter test` suite.
5. Pipe `build_runner` and `test` output through `| tail -10`.
6. Commit per task, exactly as the plan specifies (one commit per task,
   not one commit for the whole spec).
7. Once every task is implemented, open a PR for the spec with the details
   in the description.
8. Run a code review against the finished PR. If the reviewer finds an
   issue/missing part/gap: add it as a PR comment, fix it, commit the fix,
   then re-review. Repeat this comment → fix → commit cycle at most 5
   times to drive out gaps.
9. Stop there — wait for the user's own review and merge before starting
   the next spec/feature.

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

- `lib/main.dart` — entry point: an explicit `ProviderContainer` +
  `UncontrolledProviderScope` (not a bare `ProviderScope`) — the
  notification deep-link callback needs to `go()` the router from outside
  any `BuildContext`, and app-resume re-planning needs the same
  `AppDatabase` instance. Wires `NotificationBootstrap` before `runApp`,
  checks for a cold-start notification-tap deep link, registers the
  Android WorkManager top-up, and `HabitTrackerApp` (`ConsumerStatefulWidget`
  with a `WidgetsBindingObserver`) re-plans notifications on every
  foreground resume.
- `lib/core/router/app_router.dart` — `GoRouter` root (exposed via the
  `appRouterProvider` Riverpod provider, not a bare top-level `GoRouter`,
  so it can rebuild from `habitModulesProvider`), `StatefulShellRoute`
  with one branch per bottom-nav tab, typed `AppRoutes` path constants, a
  `/lock` redirect stub (always allows — real PIN check lands in a later run).
  Water's and Medicine's branches use `WaterModule().routes`/
  `MedicineModule(...).routes`; Prayer still uses a placeholder single
  route until its own run does the same swap.
- `lib/core/theme/app_theme.dart` — `ColorScheme.fromSeed` light/dark
  themes, per-module `ModuleAccents`, the `AppSemanticColors` theme
  extension (the "success" green), the bn line-height `TextTheme` adjustment.
- `lib/core/l10n/` — `app_en.arb`/`app_bn.arb` (source of truth; generated
  `AppLocalizations` not committed).
- `lib/core/modules/habit_module.dart` — the `HabitModule` plugin contract
  (`pendingNotifications`/`onNotificationAction`/`exportData`/`importData`
  all take no `Ref` — they run from non-widget code); `module_registry.dart`
  exposes both a `@riverpod` provider (widget code) and a ref-free
  `buildHabitModules(AppDatabase)` function (the notification background
  isolate, `core/notifications/notification_action_handler.dart`, and the
  WorkManager callback all construct modules this same way).
- `lib/core/notifications/` — the reminder engine
  (`docs/strategies/notifications.md`): `notification_service.dart` (the
  only file importing `flutter_local_notifications` directly — channels,
  permission/exact-alarm requests, `schedule`/`cancel`, a stable
  string-id→int hash since the plugin's ids are ints), `notification_
  planner.dart` (pure `planNotifications()` — window/cap/diff logic, unit
  tested with zero plugin dependency — plus `planAndApplyNotifications()`
  wiring it to the DB/service), `notification_ledger_repository.dart`
  (Drift repo over `notification_ledger`, now with `title`/`body` columns
  added this run so a Snooze reschedule doesn't need to ask the module to
  regenerate content), `notification_action_handler.dart` (Done/Snooze/Skip
  logic, callable from the foreground or a fresh background isolate),
  `notification_background_handler.dart` (the
  `@pragma('vm:entry-point')` top-level callback the plugin requires),
  `notification_bootstrap.dart` (the composition root wiring the plugin's
  raw callbacks to the above — kept separate so none of these files import
  each other in a cycle), `notification_workmanager.dart` (Android-only
  periodic top-up, deliberately not registered on iOS), permission-
  explainer + reliability-stub screens.
- `lib/core/widgets/charts/period_bar_chart.dart` — reusable `fl_chart`
  bar chart (bars + optional goal target line), built for Water's stats
  screen, now also used by Medicine's; meant for Prayer's own stats
  screen too.
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
- `lib/features/water/` — full slice: `domain/entities`
  (`WaterEntry`/`WaterGoal`/`WaterSettings`), `domain/usecases`
  (`LogWaterEntryUseCase` validates amount>0 and no future timestamp;
  `ResolveGoalForDateUseCase`/`CalculateWaterStreakUseCase` are pure,
  reused by both the settings-goal lookup and streak math;
  `AggregateWaterSeriesUseCase` buckets daily totals for charts),
  `data/repositories/water_repository_impl.dart` (no DAO — one caller,
  same precedent as settings), `presentation/` (providers, controller,
  4 screens, 5 widgets), `water_module.dart` (`pendingNotifications()`
  projects reminder slots 3 days ahead per `core/notifications`'
  materialization window; `onNotificationAction` logs the first quick-add
  amount on Done, no-ops on Snooze/Skip). `uuid` (`core/utils/uuid.dart`)
  and `mocktail` (dev) were added in Run 07 — first module that needs
  generated row ids / usecase-level fakes.
- `lib/features/medicine/` — full slice: `domain/entities`
  (`Medicine`/`MedicineSchedule`/`RepeatRule` sealed union/`MedicineDose`/
  `MedicineStockEvent`), `domain/usecases` (`expandRepeatRule` — pure,
  DST-immune-by-construction repeat-rule expansion, the module's most
  heavily tested unit; `effectiveDoseStatus`/`isScheduleActive` — the
  D-05/D-04 state machines; `calculateDoseTakenAdjustment`/
  `calculateDoseUndoneAdjustment` — pure stock-delta calculators, always
  clamp-consistent so undo reverses exactly what was applied;
  `planDoseMaterialization` — pure gap-filler planner, D-02 collision
  resolution; `calculateAdherence`), `data/repositories/
  medicine_repository_impl.dart` (no DAO, 4 Drift tables, `RepeatRule`
  <-> DB string/JSON mapping, one denormalization beyond `database-
  design.md`'s original column list — `medicine_doses.grace_window_
  minutes` — to avoid a join back to the schedule on the dose-timeline
  hot path), `presentation/` (providers, controller, 5 screens, 3
  widgets), `medicine_module.dart` (`pendingNotifications()` runs
  `materializeDoses` itself, first thing, before querying — this is the
  D-13 30-day-window top-up, reusing Run 08's existing app-resume/
  WorkManager triggers with no new call site anywhere else in the app;
  low-stock alerts get a synthetic near-future `scheduledAt` since the
  engine only schedules future-dated notifications). Dose notification
  ids are bare dose UUIDs (not a `medicine_dose_`-prefixed string like
  Water's reminder ids) — safe today since `notification_ledger.id` is a
  single cross-module namespace and dose ids are random UUIDs, but a
  convention Prayer's own run should weigh before following.
- `lib/features/{dashboard,prayer}/` — still placeholder screens; Prayer
  gets its real `domain/data` slice in an upcoming run (exact numbering
  pending the reconciliation noted in `docs/engineering/phases-and-dod
  .md`) — it'll plug into the existing `core/notifications` engine
  rather than integrating `flutter_local_notifications` from scratch.
- Lint rules come from `package:very_good_analysis/analysis_options.yaml`
  (`public_member_api_docs` enforced; generated code and `lib/core/l10n/**`
  excluded from analysis) — see `docs/engineering/coding-standards.md`.
- Package name is `habit_tracker`; tests import it as `package:habit_tracker/main.dart`.
- Standard multi-platform Flutter targets present (`android/`, `ios/`,
  `linux/`, `macos/`, `web/`, `windows/`); only `android`/`ios` have been
  configured with the real org id so far.

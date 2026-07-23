# Habit Tracker

An offline-first, multi-module habit tracker for Android and iOS. Track water intake, manage medication schedules, and monitor daily prayers — all with a clean Material 3 interface, smart reminders, and full Bengali/English localization.

## Features

### Core

- **3 Habit Modules** — Water, Medicine, Prayer — each with full domain/data/presentation slices
- **Material 3 Design** — light/dark/system theme, teal seed color, per-module accent colors, `AppSemanticColors` extension
- **Bengali & English** — full bilingual UI via `gen_l10n`, including Bangla line-height adjustments
- **Bottom Navigation** — GoRouter `StatefulShellRoute` with 5 tabs: Dashboard, Water, Medicine, Prayer, Settings
- **Offline-First** — Drift (SQLite) database, no backend required, all data lives on device

### Water

- Quick-add logging (configurable amounts: 250/500/750 ml)
- Custom daily goal with history tracking
- Streak calculation and achievement system
- Stats screen with period bar charts and history calendar
- Per-reminder-window overrides (different times on different weekdays)

### Medicine

- Flexible scheduling: fixed daily, every N days, weekday sets, PRN
- Dose status machine: upcoming / due / done / skipped (never persisted as "missed" — FR-M-06)
- Stock ledger with low-stock crossing detection
- 30-day rolling dose materialization window
- Dose timeline, detail, and stats screens

### Prayer

- Pure prayer-time calculation via `adhan_dart` (golden-tested against Al Adhan API)
- GPS and manual location resolver with bundled 65-city asset
- Daily checklist toggle with per-day history calendar
- Qadha (make-up) counter with −1 control
- Streak, adherence %, and 7-day chart

### Notifications & Reminders

- Smart reminder scheduling: 3-day lookahead window, 64-notification iOS cap
- Done / Snooze / Skip actions from notification shade (background isolate)
- Quiet-hours suppression (app-defined sleep window, DST-immune)
- Android WorkManager periodic top-up (8-hour cycle)
- Per-module `pendingNotifications()` contract — each module owns its own schedule

### Security

- PIN lock with PBKDF2-HMAC-SHA256 hashing
- Optional biometric unlock (opt-in, persisted)
- Screen privacy mode (flag secure, app-switcher blur)
- Exponential backoff on wrong PIN attempts
- Change PIN requires old PIN verification
- Forgot PIN: typed-confirmation friction before full data reset

### Dashboard

- Day-completion indicator per module
- Upcoming strip showing next actionable items
- Quick-actions row (one-tap log/mark-done)
- Global month calendar (bottom sheet)
- Cross-module search

### Data Management

- Full backup export/import (JSON envelope, per-module round-trip)
- Import validation with preview (row counts per module, replace warning)
- Export/share via OS share sheet

### Home Screen Widgets (Android)

- Interactive widgets for Water (quick-add) and Medicine (mark-done)
- Display-only widget for Prayer (next prayer time)
- Background tap handler — actions work without opening the app
- Refresh on foreground resume + periodic WorkManager top-up

### Wearable (Flutter-side foundation)

- `WidgetSummaryData.pendingCount` per module (cross-module total for complication)
- MethodChannel sync bridge to Wear OS Data Layer API
- Native Wear OS module (`:wear` Gradle module) is a follow-up

### What's New

- In-app changelog shown on app update
- Version comparison engine, bottom sheet with release highlights
- "View what's new" entry on About screen
- Fresh installs silently seed current version

### Reports

- Week / Month / Year period views
- Longest-streak records
- Per-module adherence tracking

### Achievements

- Module-contributed achievement definitions
- Progress evaluated from each module's own data
- Achievement gallery screen

### Responsive Layout

- Tablet/landscape support via `NavigationRail` (≥600dp)
- `MaxContentWidth` (840dp) on dashboard and stats screens
- Breakpoint helper: `isWideLayout(context)`

### App Icon & Splash

- Custom teal checkmark icon (adaptive icon for Android)
- Themed splash screen (light/dark)

## Architecture

Feature-first, Clean Architecture (`domain` / `data` / `presentation`) per module.

```
lib/
├── core/                        # Shared infrastructure
│   ├── achievements/            # Achievement engine + repository
│   ├── changelog/               # What's New data + presentation
│   ├── database/                # Drift database, tables, migrations
│   ├── error/                   # AppException / Result<T> taxonomy
│   ├── l10n/                    # ARB files (en/bn), generated localizations
│   ├── logging/                 # Rotating-file logger
│   ├── modules/                 # HabitModule contract + registry
│   ├── notifications/           # Reminder engine, planner, ledger, actions
│   ├── reports/                 # Aggregate reports + streaks
│   ├── router/                  # GoRouter config + route constants
│   ├── security/                # PIN lock, biometrics, screen privacy
│   ├── shortcuts/               # App shortcuts / quick actions
│   ├── theme/                   # Material 3 themes, module accents
│   ├── utils/                   # LocalDate, LocalTime, day bucketing
│   ├── wearable/                # Wear OS MethodChannel bridge
│   └── widgets/                 # Shared widgets, responsive breakpoints
├── features/
│   ├── dashboard/               # Dashboard screen
│   ├── medicine/                # Medicine module (domain/data/presentation)
│   ├── prayer/                  # Prayer module
│   ├── reports/                 # Reports screen
│   ├── settings/                # Settings (domain/data/presentation)
│   └── water/                   # Water module
└── main.dart                    # Entry point, ProviderContainer, lifecycle hooks
```

**Key patterns:**
- `HabitModule` plugin contract — each module registers routes, notifications, export/import, widget summaries
- `module_registry.dart` — single source of truth for module list (Riverpod provider + ref-free builder)
- `NotificationPlanner` — pure, testable notification scheduling (no plugin dependency)
- `AppException` / `Result<T>` — error taxonomy (no thrown exceptions in domain/data layers)
- `package:clock` — injected clock for DST-safe, testable time logic

## Getting Started

### Prerequisites

- Flutter SDK `^3.12.2`
- Android Studio / Xcode for platform builds
- A connected device or emulator

### Installation

```bash
# Clone the repository
git clone https://github.com/monowarfs/habit-tracker.git
cd habit-tracker

# Install dependencies
flutter pub get

# Generate code (Riverpod codegen, Drift, Freezed)
dart run build_runner build --delete-conflicting-outputs

# Generate localization files
flutter gen-l10n

# Run the app
flutter run
```

### Development

```bash
# Watch mode — regenerate code on file save
dart run build_runner watch --delete-conflicting-outputs

# Run all tests
flutter test

# Run a single test file
flutter test test/features/water/water_module_test.dart

# Static analysis
flutter analyze

# Format check
dart format --output=none --set-exit-if-changed .

# Generate app icons (after modifying assets/icon/)
dart run flutter_launcher_icons

# Generate splash screens (after modifying assets/splash/)
dart run flutter_native_splash:create
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| State Management | Riverpod (codegen) |
| Routing | GoRouter (`StatefulShellRoute`) |
| Database | Drift (SQLite) |
| Serialization | Freezed + json_serializable |
| Notifications | flutter_local_notifications |
| Background Tasks | WorkManager (Android) |
| Home Widgets | home_widget |
| Prayer Times | adhan_dart |
| Charts | fl_chart |
| Security | flutter_secure_storage, local_auth, PBKDF2 |
| Localization | gen_l10n (en/bn) |
| Analysis | very_good_analysis |

## Testing

```bash
flutter test                    # all tests
flutter test --coverage        # with coverage report
```

Tests cover:
- Domain use cases (streak calculation, dose status, prayer times, stock adjustment)
- Repository implementations (Drift-backed, round-trip)
- Notification planner (window/cap/diff logic, quiet hours)
- Security (PIN hashing, backoff, lock screen, settings toggles)
- Backup export/import (envelope validation, round-trip)
- Widget summaries and background handlers

## Platform Support

| Platform | Status |
|----------|--------|
| Android | Fully supported (widgets, WorkManager, quick actions) |
| iOS | Supported (notifications, quick actions, biometrics) |
| iOS Widgets | Deferred (separate WidgetKit extension) |
| Wear OS | Flutter-side ready, native module deferred |
| macOS / Linux / Windows / Web | Not supported (Drift requires FFI) |

## Project Structure

```
android/                  # Android-specific config + native widget provider
ios/                      # iOS-specific config
assets/
  icon/                   # App icon source PNGs
  splash/                 # Splash screen source PNG
  data/                   # Bundled data (prayer cities)
docs/
  engineering/            # Coding standards, phases, DB design
  strategies/             # Architecture decisions (notifications, security, backup)
  superpowers/specs/      # Feature specifications
  technical/              # Architecture docs, folder structure
lib/                      # Dart source (see Architecture section)
test/                     # Test files mirroring lib/ structure
```

## Contributing

1. Read `CLAUDE.md` for project conventions and architecture decisions
2. Read `docs/engineering/coding-standards.md` for lint rules and style
3. Create a feature branch from `dev`
4. Follow the feature-first, Clean Architecture structure
5. Run `flutter analyze` and `flutter test` before committing
6. Open a PR against `dev`

## License

This is a private project. All rights reserved.

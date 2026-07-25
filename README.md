# Habit Tracker

An offline-first, multi-module habit tracker for Android and iOS. Track water intake, manage medication schedules, and monitor daily prayers — all with a clean Material 3 interface, smart reminders, and full Bengali/English localization.

## Features

### Core

- **3 Habit Modules** — Water, Medicine, Prayer — each with full domain/data/presentation slices
- **Material 3 Design** — light/dark/system theme, teal seed color, per-module accent colors, `AppSemanticColors` extension
- **Seasonal Accent Colors** — automatic Pohela Boishakh (Bengali New Year) theme accent with opt-out toggle
- **Bengali & English** — full bilingual UI via `gen_l10n`, including Bangla line-height adjustments
- **Bottom Navigation** — GoRouter `StatefulShellRoute` with 5 tabs: Dashboard, Water, Medicine, Prayer, Settings
- **Offline-First** — Drift (SQLite) database, no backend required, all data lives on device

### Water

- Quick-add logging (configurable amounts: 250/500/750 ml)
- Custom daily goal with history tracking
- Streak calculation and achievement system
- Stats screen with period bar charts and history calendar
- Per-reminder-window overrides (different times on different weekdays)
- **Weather-aware reminders** — opt-in temperature clause in reminder copy (Open-Meteo API, cached via WorkManager)
- **Ramadan-aware reminders** — fasting-aware window splitting (before Fajr / after Maghrib) with Sehri/Iftar relabeling
- **Habit-stacking suggestions** — detects Medicine/Prayer → Water correlations and nudges reminder timing
- **Empty-state illustrations** — custom-painted water drop illustration on empty log screen

### Medicine

- Flexible scheduling: fixed daily, every N days, weekday sets, PRN
- Dose status machine: upcoming / due / done / skipped (never persisted as "missed" — FR-M-06)
- Stock ledger with low-stock crossing detection
- 30-day rolling dose materialization window
- Dose timeline, detail, and stats screens
- **Optional completion chime** — opt-in sound effect when marking a dose done (respects silent mode)
- **Gentle no-guilt copy** — missed doses use neutral outline color instead of error red

### Prayer

- Pure prayer-time calculation via `adhan_dart` (golden-tested against Al Adhan API)
- GPS and manual location resolver with bundled 65-city asset
- Daily checklist toggle with per-day history calendar
- Qadha (make-up) counter with −1 control
- Streak, adherence %, and 7-day chart
- **Ramadan mode** — Hijri-calendar detection, Sehri/Iftar countdown chips, fasting-aware reminder relabeling
- **Prayer countdown widget** — Android home screen widget showing time until next prayer
- **Gentle no-guilt copy** — "Due for Qadha" framing replaces "Missed" verdict

### Notifications & Reminders

- Smart reminder scheduling: 3-day lookahead window, 64-notification iOS cap
- Done / Snooze / Skip actions from notification shade (background isolate)
- Quiet-hours suppression (app-defined sleep window, DST-immune)
- Android WorkManager periodic top-up (8-hour cycle)
- Per-module `pendingNotifications()` contract — each module owns its own schedule
- **Weather-aware copy** — Water reminders include temperature when fresh weather data is cached
- **Ramadan-aware scheduling** — Water reminders split around fasting hours (before Fajr / after Maghrib)

### Security

- PIN lock with PBKDF2-HMAC-SHA256 hashing
- Optional biometric unlock (opt-in, persisted)
- Screen privacy mode (flag secure, app-switcher blur)
- Exponential backoff on wrong PIN attempts
- Change PIN requires old PIN verification
- Forgot PIN: typed-confirmation friction before full data reset

### Dashboard

- **Personalized greeting** — time-of-day-aware greeting with optional display name
- Day-completion indicator per module
- Upcoming strip showing next actionable items
- Quick-actions row (one-tap log/mark-done)
- Global month calendar (bottom sheet)
- Cross-module search
- **Habit-stacking suggestions** — dismissible cards detecting cross-module correlations
- **Micro-education cards** — one-time "why this matters" hints for Water hydration and Prayer Qadha

### Data Management

- Full backup export/import (JSON envelope, per-module round-trip)
- Import validation with preview (row counts per module, replace warning)
- Export/share via OS share sheet
- **Shareable monthly recap card** — 1080×1920 gradient card with module streaks, shareable via OS share sheet

### Home Screen Widgets (Android)

- Interactive widgets for Water (quick-add) and Medicine (mark-done)
- **Prayer countdown widget** — shows time remaining until next prayer, auto-refreshes every 30 minutes
- Background tap handler — actions work without opening the app
- Refresh on foreground resume + periodic WorkManager top-up
- **In-app widget preview** — Prayer settings screen shows a live countdown preview

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
- **Streak celebration overlay** — brief confetti animation on streak milestones (7/30/100-day), respects reduced motion
- **Anniversary badges** — 1-year and 2-year tenure milestones (auto-evaluated on app resume)

### Retention & Long-Term Engagement

- **Yearly "Wrapped" Recap** — end-of-year story cards showing per-module stats (Water total, Medicine adherence, Prayer on-time %, longest streaks), triggered on 365-day install anniversary
- **Re-engagement Nudge** — gentle notification after 7 days of inactivity, dashboard banner fallback when notifications are disabled
- **Archive/Revive** — archive Water goals and Medicine schedules you're not actively tracking, revive them later
- **Life-Event Pause** — pause a module for a date range (travel, illness) — paused days excluded from streaks and dayStatus
- **Quarterly Goal Recalibration** — periodic prompt asking "Is your goal still right?" with fatigue backoff
- **Progressive Onboarding** — new users choose which modules to enable, with Water as the recommended default
- **Data Privacy Reassurance** — card in Data settings confirming data stays on-device
- **Data Longevity Guarantee** — card confirming data is never pruned, with notification ledger 90-day FIFO cleanup
- **Cosmetic Rewards** — "Midnight" theme accent unlocked after 2 years of use

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
│   ├── achievements/            # Achievement engine + repository + tenure evaluator
│   ├── audio/                   # ChimePlayer (dose-done sound)
│   ├── backup/                  # Export/import orchestrator
│   ├── changelog/               # What's New data + presentation
│   ├── cosmetics/               # Cosmetic unlock engine + repository
│   ├── database/                # Drift database, tables, migrations (v17)
│   ├── error/                   # AppException / Result<T> taxonomy
│   ├── l10n/                    # ARB files (en/bn), generated localizations
│   ├── logging/                 # Rotating-file logger
│   ├── modules/                 # HabitModule contract + registry + module settings
│   ├── notifications/           # Reminder engine, planner, ledger, actions
│   ├── nudges/                  # Re-engagement nudge (trigger, builder, lifecycle)
│   ├── pauses/                  # Life-event pause (repository, service, UI)
│   ├── recalibration/           # Quarterly goal recalibration (trigger, service, card)
│   ├── recaps/                  # Yearly wrapped recap (generator, trigger, providers)
│   ├── reports/                 # Aggregate reports + streaks
│   ├── router/                  # GoRouter config + route constants
│   ├── security/                # PIN lock, biometrics, screen privacy
│   ├── shortcuts/               # App shortcuts / quick actions
│   ├── stacking/                # Habit-stacking correlation heuristic
│   ├── theme/                   # Material 3 themes, module accents, seasonal accents
│   ├── utils/                   # LocalDate, LocalTime, day bucketing, Hijri, greeting
│   ├── wearable/                # Wear OS MethodChannel bridge
│   └── widgets/                 # Shared widgets, illustrations, responsive breakpoints
├── features/
│   ├── dashboard/               # Dashboard screen + greeting + stacking suggestions
│   ├── medicine/                # Medicine module (domain/data/presentation)
│   ├── onboarding/              # Progressive module unlock onboarding flow
│   ├── prayer/                  # Prayer module + Ramadan framing
│   ├── reports/                 # Reports screen + yearly recap + shareable card
│   ├── settings/                # Settings (domain/data/presentation)
│   └── water/                   # Water module + weather client
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
| Audio | audioplayers (dose-done chime) |
| Weather | Open-Meteo API (weather-aware reminders) |
| Hijri Calendar | hijri (Ramadan detection) |
| Location | geolocator (GPS for weather/prayer) |
| Sharing | share_plus (recap card sharing) |

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

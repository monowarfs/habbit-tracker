# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Stock Flutter counter-app scaffold (`flutter create`). `lib/main.dart` still holds the default demo app, not a habit tracker yet. No routing, state management, persistence, or models exist yet — build from scratch.

## Commands

```
flutter pub get              # install dependencies
flutter run                  # run on connected device/simulator/emulator
flutter test                 # run all tests
flutter test test/widget_test.dart   # run a single test file
flutter analyze              # static analysis / lint (uses analysis_options.yaml)
```

Requires Flutter SDK `^3.12.2` (see `pubspec.yaml`).

## Architecture

- `lib/main.dart` — sole entry point (`MyApp` → `MyHomePage`), currently the default Flutter counter demo.
- Lint rules come from `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`, no custom rules added.
- Package name is `habit_tracker`; tests import it as `package:habit_tracker/main.dart`.
- Standard multi-platform Flutter targets present (`android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/`) but unconfigured beyond scaffolding defaults.

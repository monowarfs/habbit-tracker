# habit_tracker

An offline, multi-module habit tracker (Water/Medicine/Prayer). See
`CLAUDE.md` and `docs/` for the full product/technical/engineering docs.

## Running

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates *.g.dart (Riverpod)
flutter gen-l10n                                            # generates AppLocalizations (also runs automatically on `flutter run`/`build`)
flutter run
```

During active development, regenerate Riverpod providers on file save with:

```
dart run build_runner watch --delete-conflicting-outputs
```

## Commands

```
flutter test        # run all tests
flutter analyze     # static analysis (very_good_analysis, see analysis_options.yaml)
dart format .        # format
```

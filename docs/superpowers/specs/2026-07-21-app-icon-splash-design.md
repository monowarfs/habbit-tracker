# App Icon & Splash Screen

**Date:** 2026-07-21
**Status:** Approved

## Problem

App ships with Flutter's default placeholder launcher icon and no splash
screen (blank/white flash on cold start).

## Design

**Mark:** a single bold white rounded checkmark (`Icons.check_rounded`
glyph, hand-rendered to PNG — no new font/asset dependency), representing
"habit completed." Generic across all three modules (water/medicine/
prayer), not biased toward any one.

**Icon:**
- Background: solid teal `#006874` (the app's existing Material seed
  color, `lib/core/theme/app_theme.dart`'s `_seedColor`).
- Foreground: white checkmark, centered.
- Android adaptive icon: separate transparent-background foreground layer
  (checkmark only, sized within the 66% safe zone) + solid `#006874`
  background layer, per Android's adaptive icon spec.
- iOS/legacy Android: single flattened PNG (teal bg + checkmark), no
  transparency (iOS ignores/flattens alpha anyway).

**Splash screen:**
- Light mode: `#006874` background, white checkmark centered.
- Dark mode: `#00363A` (a darker teal, same hue) background, white
  checkmark centered.
- Uses Android 12+ native splash API where available, legacy splash
  (`launch_background.xml`) + iOS `LaunchScreen.storyboard` otherwise —
  all generated, not hand-authored.

## Approach

Source PNGs are generated headlessly (no external image tools installed
on this machine, no `imagemagick`/`inkscape`/`cairosvg`) via a throwaway
`flutter test` widget-capture script: pump a `RepaintBoundary`-wrapped
`CustomPaint`/`Icon` widget, call `toImage()`, write the PNG bytes to
`assets/icon/` and `assets/splash/`. The script is deleted after
generating the assets — it is not a real test and doesn't belong in the
suite.

Platform icon/splash files (Android mipmaps, adaptive-icon XML, iOS
`Assets.xcassets`, `LaunchScreen.storyboard`, `launch_background.xml`)
are then generated from those source PNGs by two dev-dependency
generators, not hand-edited:
- [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons)
  — reads `assets/icon/icon.png` (flattened) +
  `assets/icon/icon_foreground.png` (transparent) + `#006874` background,
  writes all Android mipmap densities/adaptive-icon XML and the iOS
  `AppIcon.appiconset`.
- [`flutter_native_splash`](https://pub.dev/packages/flutter_native_splash)
  — reads `assets/splash/splash_logo.png` + light/dark background colors,
  writes Android 12+ splash config, legacy `launch_background.xml`, and
  iOS `LaunchScreen.storyboard`.

Both are one-shot code generators (run via `dart run <pkg>:main`), not
runtime dependencies — configured under `dev_dependencies` and a config
block in `pubspec.yaml`, per each package's standard usage.

## Out of scope

- Per-module or animated splash variants — single static mark, matches
  "no PIN lock yet"-style deferred-polish precedent in this codebase.
- Redesigning the app's color system — reuses existing seed/accent
  colors verbatim.

## Testing

No new runtime logic — nothing to unit test. Verification is visual:
run the app on Android/iOS (simulator or device) and confirm the
launcher icon and splash screen render as designed, in both light and
dark system theme.

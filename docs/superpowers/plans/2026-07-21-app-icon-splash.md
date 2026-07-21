# App Icon & Splash Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Flutter's default placeholder launcher icon with a
teal-background white-checkmark icon, and add a matching native splash
screen (light + dark), per
`docs/superpowers/specs/2026-07-21-app-icon-splash-design.md`.

**Architecture:** Generate three source PNGs (flattened icon, transparent
adaptive-icon foreground, transparent splash mark) headlessly via a
throwaway `flutter test` widget-capture script (no image tools installed
on this machine). Feed those PNGs to two dev-dependency code generators —
`flutter_launcher_icons` (writes Android mipmaps/adaptive-icon XML + iOS
`AppIcon.appiconset`) and `flutter_native_splash` (writes Android 12+
splash config, legacy `launch_background.xml`, iOS
`LaunchScreen.storyboard`) — instead of hand-editing platform files.

**Tech Stack:** Flutter 3.44 (stable), `flutter_launcher_icons`,
`flutter_native_splash`, `dart:ui`/`flutter_test` for headless PNG capture.

## Global Constraints

- Icon background: solid teal `#006874` (existing `_seedColor` in
  `lib/core/theme/app_theme.dart`).
- Mark: `Icons.check_rounded`, white, centered — no new font/asset
  dependency.
- Splash background: `#006874` light mode, `#00363A` dark mode.
- Android adaptive icon foreground must stay within the 66% safe zone
  (transparent bg, checkmark comfortably inside a 677px circle on a
  1024px canvas).
- No hand-edited platform files (Android mipmaps/XML, iOS
  `Assets.xcassets`/storyboard) — generated only.
- Temporary capture script is not a real test; delete it after use, don't
  leave it in `test/`.

---

### Task 1: Generate source brand-asset PNGs

**Files:**
- Create (temporary, deleted in Task 2): `test/_generate_brand_assets_test.dart`
- Produces: `assets/icon/icon.png`, `assets/icon/icon_foreground.png`,
  `assets/splash/splash_logo.png`

**Interfaces:**
- Produces: three 1024×1024 PNG files on disk, consumed by Task 2's
  `flutter_launcher_icons`/`flutter_native_splash` config.

- [ ] **Step 1: Write the capture script**

Create `test/_generate_brand_assets_test.dart`:

```dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _teal = Color(0xFF006874);

void main() {
  testWidgets('generate brand asset PNGs', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Flattened icon: teal bg + white checkmark. Used as the base image
    // for flutter_launcher_icons (iOS AppIcon + Android legacy icon).
    await _capture(
      tester,
      background: _teal,
      iconSize: 620,
      outputPath: 'assets/icon/icon.png',
    );

    // Adaptive-icon foreground: transparent bg, checkmark sized to stay
    // inside Android's 66% safe zone.
    await _capture(
      tester,
      background: Colors.transparent,
      iconSize: 420,
      outputPath: 'assets/icon/icon_foreground.png',
    );

    // Splash mark: transparent bg, centered by flutter_native_splash on
    // its own configured background color.
    await _capture(
      tester,
      background: Colors.transparent,
      iconSize: 240,
      outputPath: 'assets/splash/splash_logo.png',
    );
  });
}

Future<void> _capture(
  WidgetTester tester, {
  required Color background,
  required double iconSize,
  required String outputPath,
}) async {
  final GlobalKey key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: Container(
          color: background,
          alignment: Alignment.center,
          child: Icon(
            Icons.check_rounded,
            size: iconSize,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  final File file = File(outputPath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(byteData!.buffer.asUint8List());
}
```

- [ ] **Step 2: Run the script**

Run: `flutter test test/_generate_brand_assets_test.dart`
Expected: `00:0X +1: All tests passed!` and three new files exist:
`assets/icon/icon.png`, `assets/icon/icon_foreground.png`,
`assets/splash/splash_logo.png`.

- [ ] **Step 3: Verify the PNGs look right**

Run: `file assets/icon/icon.png assets/icon/icon_foreground.png assets/splash/splash_logo.png`
Expected: each reports `PNG image data, 1024 x 1024`. Open
`assets/icon/icon.png` in an image viewer/Preview and confirm: solid
teal square, centered white checkmark, no transparency artifacts.
Confirm `icon_foreground.png` and `splash_logo.png` have a transparent
background (checkerboard in Preview) with only the white checkmark
opaque.

- [ ] **Step 4: Commit the source assets**

```bash
git add assets/icon/icon.png assets/icon/icon_foreground.png assets/splash/splash_logo.png
git commit -m "feat(brand): add source icon and splash mark PNGs"
```

(The temporary test file is intentionally left uncommitted here — it's
deleted in Task 2, Step 6.)

---

### Task 2: Wire up icon/splash generators and remove placeholders

**Files:**
- Modify: `pubspec.yaml` (add dev deps + `flutter_launcher_icons`/
  `flutter_native_splash` config blocks)
- Delete: `test/_generate_brand_assets_test.dart`
- Generated (not hand-edited): `android/app/src/main/res/mipmap-*/
  ic_launcher.png`, `android/app/src/main/res/mipmap-anydpi-v26/
  ic_launcher.xml`, `android/app/src/main/res/values*/colors.xml`,
  `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`,
  `ios/Runner/Assets.xcassets/LaunchImage.imageset/*`,
  `ios/Runner/Base.lproj/LaunchScreen.storyboard`,
  `android/app/src/main/res/drawable*/launch_background.xml`,
  `android/app/src/main/res/values*/styles.xml`

**Interfaces:**
- Consumes: `assets/icon/icon.png`, `assets/icon/icon_foreground.png`,
  `assets/splash/splash_logo.png` from Task 1.

- [ ] **Step 1: Add the generator dev-dependencies**

Run: `flutter pub add --dev flutter_launcher_icons flutter_native_splash`
Expected: `pubspec.yaml`'s `dev_dependencies:` block gains
`flutter_launcher_icons: ^<resolved version>` and
`flutter_native_splash: ^<resolved version>` entries, and command exits 0.

- [ ] **Step 2: Add the icon/splash config blocks to `pubspec.yaml`**

Append at the end of `pubspec.yaml` (after the existing `flutter:`
block):

```yaml

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/icon.png"
  adaptive_icon_background: "#006874"
  adaptive_icon_foreground: "assets/icon/icon_foreground.png"
  min_sdk_android: 26

flutter_native_splash:
  color: "#006874"
  image: assets/splash/splash_logo.png
  color_dark: "#00363A"
  image_dark: assets/splash/splash_logo.png
  android_12:
    image: assets/splash/splash_logo.png
    icon_background_color: "#006874"
    image_dark: assets/splash/splash_logo.png
    icon_background_color_dark: "#00363A"
  android: true
  ios: true
```

- [ ] **Step 3: Run the icon generator**

Run: `dart run flutter_launcher_icons`
Expected: output ends with something like
`✓ Successfully generated launcher icons`. Verify
`android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` and
`ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
have changed: `git status` shows them modified.

- [ ] **Step 4: Run the splash generator**

Run: `dart run flutter_native_splash:create`
Expected: output ends with something like
`[✓] Native splash screen created successfully.`. Verify
`android/app/src/main/res/drawable/launch_background.xml` and
`ios/Runner/Base.lproj/LaunchScreen.storyboard` show as modified in
`git status`.

- [ ] **Step 5: Regenerate and analyze**

Run: `flutter pub get && flutter analyze`
Expected: `No issues found!` (the two new dev deps must not introduce
lint issues; if `analysis_options.yaml` excludes generated code only,
confirm the new generated Android/iOS files aren't Dart — they aren't,
so this should be a no-op check that nothing else broke).

- [ ] **Step 6: Delete the temporary capture script**

```bash
rm test/_generate_brand_assets_test.dart
```

Run: `flutter test`
Expected: existing suite still passes, and the temp file is gone from
`git status` (it was never committed, so nothing to unstage).

- [ ] **Step 7: Visually verify on a device/simulator**

Run: `flutter run`
Expected: cold start shows the teal splash screen with the white
checkmark before the app UI loads (both light and dark system theme, if
you can toggle it on the test device/simulator), and the home-screen/
app-switcher launcher icon shows the teal square with white checkmark
(not Flutter's default logo). Report what you observed — this step
can't be verified from output alone.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock android/ ios/
git commit -m "feat(brand): generate app launcher icon and splash screen"
```

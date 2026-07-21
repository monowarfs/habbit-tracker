# App Icon & Splash Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Flutter's default placeholder launcher icon with a
teal-background white-checkmark icon, and add a matching native splash
screen (light + dark), per
`docs/superpowers/specs/2026-07-21-app-icon-splash-design.md`.

**Architecture:** Generate three source PNGs (flattened icon, transparent
adaptive-icon foreground, transparent splash mark) headlessly via a
throwaway script (no image tools installed on this machine — see Task 1's
deviation note for why a pure-Python PNG encoder was used instead of a
`flutter test` capture). Feed those PNGs to two dev-dependency code
generators — `flutter_launcher_icons` (writes Android mipmaps/
adaptive-icon XML + iOS `AppIcon.appiconset`) and `flutter_native_splash`
(writes Android 12+ splash config, legacy `launch_background.xml`, iOS
`LaunchScreen.storyboard`) — instead of hand-editing platform files.

**Tech Stack:** Flutter 3.44 (stable), `flutter_launcher_icons`,
`flutter_native_splash`, Python 3 (stdlib only) for headless PNG
generation.

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
- Generator script is a one-shot tool, not project code; it lives outside
  the repo and isn't committed.

---

### Task 1: Generate source brand-asset PNGs

**Files:**
- Produces: `assets/icon/icon.png`, `assets/icon/icon_foreground.png`,
  `assets/splash/splash_logo.png`

**Interfaces:**
- Produces: three 1024×1024 PNG files on disk, consumed by Task 2's
  `flutter_launcher_icons`/`flutter_native_splash` config.

**Deviation from original approach:** a `flutter test` widget-capture
script (`RepaintBoundary` + `CustomPaint`, `toImage()`) was tried first
and abandoned — `toImage()` hung indefinitely (60s+ timeout, no error)
in this sandboxed shell, most likely because the software rasterizer
can't get GPU/framebuffer access here. Replaced with a throwaway
pure-Python script (stdlib `zlib` only — no Pillow/cairosvg/numpy
installed) that hand-encodes PNG chunks directly: solid background
fill, checkmark stroked via per-pixel distance-to-segment with a 1px
anti-aliased edge. Run from outside the repo (scratch directory) and
discarded after use.

- [x] **Step 1: Write and run the generator script**

Script (run once from a scratch location, not committed):

```python
import struct
import zlib
import os

CANVAS = 1024
TEAL = (0x00, 0x68, 0x74)
WHITE = (255, 255, 255)


def seg_dist(px, py, x1, y1, x2, y2):
    dx, dy = x2 - x1, y2 - y1
    length_sq = dx * dx + dy * dy
    t = max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / length_sq))
    cx, cy = x1 + t * dx, y1 + t * dy
    return ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5


def checkmark_coverage(x, y, p1, p2, p3, half_width):
    d = min(seg_dist(x, y, *p1, *p2), seg_dist(x, y, *p2, *p3))
    return max(0.0, min(1.0, half_width - d + 0.5))


def render(path, background, mark_size, has_alpha):
    left = (CANVAS - mark_size) / 2
    top = (CANVAS - mark_size) / 2
    p1 = (left + 0.18 * mark_size, top + 0.52 * mark_size)
    p2 = (left + 0.42 * mark_size, top + 0.75 * mark_size)
    p3 = (left + 0.84 * mark_size, top + 0.26 * mark_size)
    half_width = mark_size * 0.14 / 2

    channels = 4 if has_alpha else 3
    bg_pixel = bytes(background) + (
        bytes([background[3] if len(background) > 3 else 255]) if has_alpha else b""
    )
    pixels = bytearray(bg_pixel * CANVAS * CANVAS)

    margin = int(half_width) + 2
    x0 = max(0, int(min(p1[0], p2[0], p3[0])) - margin)
    x1 = min(CANVAS, int(max(p1[0], p2[0], p3[0])) + margin)
    y0 = max(0, int(min(p1[1], p2[1], p3[1])) - margin)
    y1 = min(CANVAS, int(max(p1[1], p2[1], p3[1])) + margin)

    for y in range(y0, y1):
        row_offset = y * CANVAS * channels
        for x in range(x0, x1):
            cov = checkmark_coverage(x + 0.5, y + 0.5, p1, p2, p3, half_width)
            if cov <= 0:
                continue
            off = row_offset + x * channels
            if has_alpha:
                base_a = pixels[off + 3] / 255.0
                out_a = cov + base_a * (1 - cov)
                if out_a > 0:
                    for c in range(3):
                        base = pixels[off + c] * base_a
                        blended = WHITE[c] * cov + base * (1 - cov)
                        pixels[off + c] = round(blended / out_a)
                pixels[off + 3] = round(out_a * 255)
            else:
                for c in range(3):
                    base = pixels[off + c]
                    pixels[off + c] = round(WHITE[c] * cov + base * (1 - cov))

    write_png(path, CANVAS, CANVAS, bytes(pixels), has_alpha)


def write_png(path, width, height, pixel_bytes, has_alpha):
    channels = 4 if has_alpha else 3
    color_type = 6 if has_alpha else 2
    stride = width * channels
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw.extend(pixel_bytes[y * stride:(y + 1) * stride])

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    idat = zlib.compress(bytes(raw), 9)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


os.makedirs("assets/icon", exist_ok=True)
os.makedirs("assets/splash", exist_ok=True)

render("assets/icon/icon.png", (*TEAL,), mark_size=620, has_alpha=False)
render("assets/icon/icon_foreground.png", (0, 0, 0, 0), mark_size=420, has_alpha=True)
render("assets/splash/splash_logo.png", (0, 0, 0, 0), mark_size=240, has_alpha=True)

print("done")
```

Run from the repo root (so the relative `assets/...` paths land in the
right place): `python3 <path-to-script>/generate_assets.py`
Expected: prints `done`; three files exist at
`assets/icon/icon.png`, `assets/icon/icon_foreground.png`,
`assets/splash/splash_logo.png`.

- [x] **Step 2: Verify the PNGs look right**

Run: `file assets/icon/icon.png assets/icon/icon_foreground.png assets/splash/splash_logo.png`
Expected: each reports `PNG image data, 1024 x 1024`.
`icon.png` is `8-bit/color RGB` (flattened, no alpha); the other two are
`8-bit/color RGBA`. Visual check confirmed: `icon.png` shows a solid
teal square with a centered white checkmark; the RGBA files preview as
blank/white against a white viewer background (expected — transparent
PNGs do that), so alpha was verified separately by decoding the PNG
IDAT and confirming the alpha channel is `0` at the background and
ramps up to opaque at the checkmark strokes.

- [x] **Step 3: Commit the source assets**

```bash
git add assets/icon/icon.png assets/icon/icon_foreground.png assets/splash/splash_logo.png
git commit -m "feat(brand): add source icon and splash mark PNGs"
```

---

### Task 2: Wire up icon/splash generators and remove placeholders

**Files:**
- Modify: `pubspec.yaml` (add dev deps + `flutter_launcher_icons`/
  `flutter_native_splash` config blocks)
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

- [ ] **Step 6: Confirm the test suite is untouched**

Run: `flutter test`
Expected: existing suite still passes (this task added no Dart test
files — the source-PNG generator was a Python script run outside the
repo, never part of `test/`).

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

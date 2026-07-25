# Implementation Plan: Share-a-Streak Image

**Spec:** `01-share-a-streak-image-design.md`
**Complexity:** S · **Estimated effort:** 1 day
**Depends on:** `share_plus` package, streak use cases

---

## Task 1: Add `share_plus` dependency

**File:** `pubspec.yaml`

```yaml
dependencies:
  share_plus: ^10.0.0
```

Run `flutter pub get`.

---

## Task 2: Create image capture utility

**File:** `lib/core/widgets/image_capture.dart`

A reusable utility for rendering any widget to an image:

```dart
class ImageCapture {
  /// Renders [widget] to a PNG image file in temp storage.
  /// Returns the file path on success.
  static Future<String> captureWidget({
    required Widget widget,
    required BuildContext context,
    double pixelRatio = 3.0,
  }) async {
    final boundary = RenderRepaintBoundary(
      child: widget,
    );
    // ... render to image, save to temp dir
  }
}
```

Key considerations:
- Use `RenderRepaintBoundary.toImage()` with `pixelRatio: 3.0` for
  sharp output on high-DPI screens.
- Save to `Directory.systemTemp` — auto-cleaned by OS.
- Wrap in `LayoutBuilder` to ensure the widget is laid out before capture.
- Handle `toImage()` exceptions with `AppException.unexpected`.

---

## Task 3: Create streak card widget

**File:** `lib/features/community/presentation/widgets/streak_card.dart`

A stateless widget that renders the shareable card:

```dart
class StreakCard extends StatelessWidget {
  const StreakCard({
    required this.moduleName,
    required this.moduleIcon,
    required this.accentColor,
    required this.streakCount,
    required this.date,
    required this.locale,
  });
  // ... fields
}
```

Card layout:
- Top: module accent color bar (8px)
- Center: module icon (48px) + streak count (large text)
- Bottom: date + "Habit Tracker" branding
- Background: white/light gray (works in both light/dark themes)

Size: 1080x1920 (9:16 portrait) — optimal for WhatsApp/Messenger sharing.

---

## Task 4: Create share streak controller

**File:** `lib/features/community/presentation/providers/share_streak_provider.dart`

A Riverpod provider that orchestrates the share flow:

```dart
@riverpod
class ShareStreakController extends _$ShareStreakController {
  @override
  Future<void> build() async {}

  Future<void> shareStreak({
    required String moduleId,
    required WidgetRef ref,
  }) async {
    // 1. Get streak data from module's use case
    // 2. Build StreakCard widget
    // 3. Capture to image via ImageCapture
    // 4. Share via Share.shareXFiles()
    // 5. Clean up temp file
  }
}
```

---

## Task 5: Add share buttons to stats screens

**Files:**
- `lib/features/water/presentation/screens/water_stats_screen.dart`
- `lib/features/medicine/presentation/screens/medicine_stats_screen.dart`
- `lib/features/prayer/presentation/screens/prayer_stats_screen.dart`

Add a share `IconButton` in the app bar or as a FAB on each stats screen.
The button is only visible when a meaningful streak exists (streak > 0).

```dart
IconButton(
  icon: const Icon(Icons.share),
  onPressed: () => ref.read(shareStreakControllerProvider.notifier)
      .shareStreak(moduleId: 'water', ref: ref),
)
```

---

## Task 6: Add localization strings

**Files:** `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`

Add ARB keys:
```json
"shareStreakTitle": "Share Your Streak",
"shareStreakSubtitle": "Create a shareable image",
"shareStreakWaterLabel": "Water Streak",
"shareStreakMedicineLabel": "Medicine Streak",
"shareStreakPrayerLabel": "Prayer Streak",
"shareStreakOverallLabel": "Overall Streak",
"shareStreakDays": "{count} days",
"shareStreakShareAction": "Share",
"shareStreakSavedToGallery": "Saved to gallery",
"shareStreakNoShareApp": "No sharing app available"
```

Run `flutter gen-l10n`.

---

## Task 7: Add golden test assets

**File:** `test/goldens/share_streak_card_water.png`
**File:** `test/goldens/share_streak_card_medicine.png`
**File:** `test/goldens/share_streak_card_prayer.png`

Capture golden images for each module variant.

---

## Performance considerations

- **Image capture:** `RenderRepaintBoundary.toImage()` is synchronous
  on the raster thread — offload to avoid jank. Show a brief loading
  indicator during capture.
- **Temp file cleanup:** delete the temp image file after sharing
  completes (or after 60 seconds as fallback).
- **Widget rebuild:** the card is stateless — no rebuild needed. The
  capture utility creates an offscreen `RenderView` for the widget.

## Testing

- `test/features/community/share_streak_image_test.dart` — unit tests
  for streak data mapping to card content.
- `test/widgets/streak_card_widget_test.dart` — widget renders correctly
  with mock data, respects locale, shows correct accent colors.
- `test/goldens/streak_card_water_golden.png` — golden test for
  visual regression.

## Localization

All ARB keys listed in Task 6. The rendered image text uses
`AppLocalizations` for locale-aware rendering — the card widget reads
localized strings and renders them at capture time.

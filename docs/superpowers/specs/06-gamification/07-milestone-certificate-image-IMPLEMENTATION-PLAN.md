# Implementation Plan: Milestone Certificate Image

**Spec:** 07-milestone-certificate-image-design.md
**Complexity:** S | **Estimated effort:** 2 days
**Dependencies:** Achievement engine (to identify milestone unlocks), platform share sheet

---

## Overview

Generate a shareable certificate image for significant milestones (streak-length achievements where `target >= 30`). Uses `RepaintBoundary`-based image capture. No DB tables needed.

---

## Implementation Tasks

### Task 1: Image Renderer Utility

**Files to create:**
- `lib/core/widgets/image_renderer.dart`

```dart
class ImageRenderer {
  /// Captures a RepaintBoundary widget as a PNG image.
  /// Returns the image as bytes, ready for sharing or saving.
  static Future<Uint8List> captureWidget(Widget widget, {
    required Size size,
    double pixelRatio = 2.0,
  });

  /// Renders a widget to a PNG file in the app's documents directory.
  /// Returns the file path.
  static Future<String> renderToFile(Widget widget, {
    required String fileName,
    required Size size,
  });
}
```

**Implementation:** Uses `RepaintBoundary` + `toImage()` + `ByteData` + `png` encoding. The widget is rendered in an offscreen `Overlay` or `Navigator` for capture.

**Dependencies:** Add `image` package to `pubspec.yaml` (for PNG encoding).

---

### Task 2: Certificate Widget

**Files to create:**
- `lib/core/gamification/certificate/certificate_widget.dart`

```dart
class CertificateWidget extends StatelessWidget {
  const CertificateWidget({
    required this.moduleName,
    required this.streakDays,
    required this.date,
    required this.userName,
    required this.accentColor,
  });

  final String moduleName;
  final int streakDays;
  final DateTime date;
  final String? userName;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _repaintKey,
      child: Container(
        width: 1080, // 1080×1080 for social media
        height: 1080,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentColor.withOpacity(0.1), Colors.white],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTitle(context),
            _buildStreakText(context),
            _buildModuleName(context),
            _buildDate(context),
            _buildUserName(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }
}
```

**Design:** Clean, dignified layout — not childish. Uses the module's accent color as a gradient accent. App name at bottom. Locale-aware text rendering.

---

### Task 3: Certificate Generation Logic

**Files to create:**
- `lib/core/gamification/certificate/certificate_generator.dart`

```dart
class CertificateGenerator {
  /// Generates a certificate image for the given milestone.
  /// Returns the image file path.
  Future<String> generate({
    required String moduleName,
    required int streakDays,
    required Color accentColor,
    String? userName,
    required AppLocalizations l10n,
  });

  /// Determines if an achievement qualifies for a certificate.
  /// Qualifies if: isStreakMilestoneKey(key) && target >= 30.
  bool qualifiesForCertificate(AchievementDefinition definition);
}
```

**Qualification rules:** Any achievement where `target >= 30` (30-day, 100-day, 365-day streaks). Smaller milestones don't warrant a certificate.

---

### Task 4: Share Integration

**Files to create:**
- `lib/core/gamification/certificate/certificate_share.dart`

```dart
class CertificateShare {
  /// Shares the certificate via the platform's share sheet.
  /// Falls back to saving to photo library if share fails.
  Future<void> shareCertificate(String imagePath, {String? text});

  /// Saves the certificate to the device's photo library.
  Future<void> saveToLibrary(String imagePath);
}
```

**Dependencies:** Add `share_plus` and `image_gallery_saver` packages to `pubspec.yaml`.

**Integration:** Triggered from achievement unlock dialog or badge gallery.

---

### Task 5: Certificate Cache

**Files to create:**
- `lib/core/gamification/certificate/certificate_cache.dart`

```dart
class CertificateCache {
  /// Cache directory: app_documents/certificates/
  Directory get _cacheDir;

  /// Returns cached certificate path if it exists.
  String? getCached(String achievementKey);

  /// Stores a generated certificate in the cache.
  void cache(String achievementKey, String imagePath);

  /// Clears old cache entries (older than 30 days).
  Future<void> pruneOldEntries();
}
```

**Integration:** `CertificateGenerator` checks cache before regenerating. Cache keyed by `achievementKey + date`.

---

### Task 6: Trigger from Achievement Unlock

**Files to modify:**
- Achievement unlock dialog/notification (in `lib/features/achievements/presentation/`)

**Changes:**
When an achievement unlocks and `CertificateGenerator.qualifiesForCertificate()` returns true, show a "Share Certificate" button in the unlock celebration dialog.

---

### Task 7: Localization

**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**ARB keys:**
```
"certificateTitle": "Achievement Unlocked",
"certificateDayStreak": "{count}-Day Streak",
"certificateModuleName": "{module}",
"certificateDate": "Achieved on {date}",
"certificateFooter": "Generated by Habit Tracker",
"certificateShareButton": "Share Certificate",
"certificateSaveButton": "Save to Photos",
"certificateShareSuccess": "Certificate saved!",
"certificateShareFailed": "Could not share certificate"
```

---

## Performance Considerations

- **Caching:** Certificates are cached as PNG files in app documents. Regenerated only on re-share if the cache is pruned.
- **Lazy loading:** Certificate generation is on-demand (user taps "Share"), not on achievement unlock.
- **Memory:** Widget is rendered offscreen and disposed immediately after capture — no long-lived widget tree.

---

## Testing

**Files to create:**
- `test/core/gamification/certificate/certificate_generator_test.dart`
- `test/core/gamification/certificate/certificate_widget_test.dart`
- `test/core/gamification/certificate/certificate_cache_test.dart`

**Coverage:**
| Test | Covers |
|---|---|
| `certificate_generator_test.dart` | Qualification rules (target >= 30), generation with mock data |
| `certificate_widget_test.dart` | Layout renders correctly, locale-aware text (en/bn) |
| `certificate_cache_test.dart` | Cache hit/miss, pruning old entries |

---

## Edge Cases

- **No renderer exists:** Build `ImageRenderer` utility as prerequisite (Task 1). Reusable for Spec 04-premium/05 (PDF reports).
- **Large text at high scale:** Certificate layout must accommodate localized text at 200% text scale without clipping.
- **Share sheet failure:** Fall back to saving to photo library.
- **Which milestones qualify:** Any achievement where `target >= 30`.
- **Locale:** Certificate text rendered in user's active locale.

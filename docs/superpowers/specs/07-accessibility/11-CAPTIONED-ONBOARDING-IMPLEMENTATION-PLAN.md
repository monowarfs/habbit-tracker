# Implementation Plan: 11 Captioned Onboarding

## Overview

- **Spec:** Captioned Onboarding
- **Complexity:** S (but effectively zero-effort today)
- **Estimated effort:** 0.5 day (when onboarding animation is built)
- **Dependencies:** BLOCKED on future onboarding animation/video feature. No onboarding animation exists today.
- **Prerequisites:** The onboarding flow is currently a placeholder skeleton per CLAUDE.md.

---

## Implementation Tasks

### Task 1: BLOCKED — Wait for onboarding animation feature

**Status:** This spec cannot be implemented until a Must Have or Delightful atlas item adds an onboarding animation or video. Today, onboarding is a placeholder.

**What to do when unblocked:**

### Task 2: Add WebVTT caption files

**Files to create/modify:**
- `assets/captions/onboarding_en.vtt` (new, when animation exists)
- `assets/captions/onboarding_bn.vtt` (new, when animation exists)
- `pubspec.yaml` (modify — register caption assets)

**Detailed changes:**
- Create WebVTT (`.vtt`) caption files for each locale.
- Each caption file contains timestamped text synchronized with the animation/video.
- Register the `assets/captions/` directory in `pubspec.yaml`.

**Integration:** Standard Flutter asset registration.

### Task 3: Add text-only alternative screen

**Files to create/modify:**
- `lib/features/onboarding/presentation/onboarding_text_only_screen.dart` (new, when animation exists)

**Detailed changes:**
- Create a plain-text onboarding screen that covers the same content as the animation/video.
- Must be reachable without watching/listening to the media.
- Localized in both en and bn.
- The text-only alternative must be genuinely equivalent in content, not a stripped-down summary.

**Integration:** Part of the onboarding flow — a parallel route to the animation.

### Task 4: Add pause/stop/hide controls for auto-play

**Files to create/modify:**
- `lib/features/onboarding/presentation/onboarding_animation_screen.dart` (modify, when animation exists)

**Detailed changes:**
- If the animation auto-plays, add controls to:
  - Pause the animation.
  - Stop the animation.
  - Hide/collapse the animation (WCAG 2.2.2 Pause, Stop, Hide).
- Controls must be keyboard-operable and have `Semantics` labels.

**Integration:** Additive controls on the animation screen.

### Task 5: Tests

**Files to create/modify:**
- `test/features/onboarding/presentation/onboarding_captions_test.dart` (new, when animation exists)

**Detailed changes:**
- Verify captions are present and synchronized (if caption parsing is in-app).
- Verify the text-only alternative screen renders the same content.
- Verify pause/stop/hide controls work.
- Verify all onboarding accessibility from spec 12 (screen-reader labels) works alongside captions.

**Integration:** Standard widget tests.

---

## Performance Considerations

- **Caching strategy:** N/A — captions are static asset files.
- **Lazy loading:** Caption files can be loaded on demand when the animation screen is opened.
- **Memory efficiency:** WebVTT files are small (<10KB each); negligible memory impact.

---

## Testing

- When the animation is built:
  - Verify captions are synchronized, localized in en/bn.
  - Verify the text-only alternative is accessible.
  - Widget test for pause/stop/hide controls.

---

## Localization

When the onboarding animation is built:
- Caption files must be provided in both en and bn (WebVTT format).
- The text-only alternative must also be localized.
- New ARB keys for caption UI controls may be needed.

---

## Edge Cases

1. **No animation exists yet** — this spec is a placeholder requirement. Attach it to whichever future spec builds the onboarding animation.
2. **Auto-play** — WCAG requires a mechanism to pause/stop/hide. Include this in the requirement.
3. **Caption file format** — use WebVTT for screen-reader compatibility and searchability.
4. **Caption sync** — captions must be synchronized with the animation timeline.

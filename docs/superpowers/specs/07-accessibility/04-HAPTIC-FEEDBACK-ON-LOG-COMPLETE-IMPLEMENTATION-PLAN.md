# Implementation Plan: 04 Haptic Feedback on Log/Complete

## Overview

- **Spec:** Haptic Feedback on Log/Complete
- **Complexity:** S
- **Estimated effort:** 0.5 day
- **Dependencies:** None — standalone. Water/Medicine/Prayer modules are all complete.
- **Prerequisites:** No new dependencies. `HapticFeedback` ships with Flutter.

---

## Implementation Tasks

### Task 1: Add haptic to Water log success path

**Files to create/modify:**
- `lib/features/water/presentation/water_home_controller.dart` (or equivalent controller) (modify)

**Detailed changes:**
- After the successful write in the quick-add and custom-log flows, add:
  ```dart
  HapticFeedback.lightImpact();
  ```
- Import `package:flutter/services.dart` for `HapticFeedback`.
- Place the call strictly in the success branch — after DB write completes, before or after the snackbar. Never before the async write.

**Integration:** One-line addition at the known success point in Water's controller.

### Task 2: Add haptic to Medicine dose-done success path

**Files to create/modify:**
- `lib/features/medicine/presentation/medicine_home_controller.dart` (or equivalent controller) (modify)

**Detailed changes:**
- After marking a dose done successfully, add `HapticFeedback.lightImpact()`.
- Ensure the haptic does NOT fire on undo (the undo snackbar's action callback should skip the haptic).

**Integration:** One-line addition at Medicine's dose-done success point.

### Task 3: Add haptic to Prayer checklist toggle success path

**Files to create/modify:**
- `lib/features/prayer/presentation/prayer_home_controller.dart` (or equivalent controller) (modify)

**Detailed changes:**
- After toggling a prayer to "prayed" successfully, add `HapticFeedback.lightImpact()`.
- Do NOT fire on toggling back to "not prayed" (undo).

**Integration:** One-line addition at Prayer's toggle success point.

### Task 4: Create shared haptic helper (optional, for DRY)

**Files to create/modify:**
- `lib/core/accessibility/haptic_helper.dart` (new, optional)

**Detailed changes:**
- Create `void confirmationHaptic()` that calls `HapticFeedback.lightImpact()`.
- This centralizes the haptic type if it ever needs to change (e.g. switching to `HapticFeedback.mediumImpact()`).
- NOT required — three one-liners are also acceptable.

**Integration:** Consumed by Water/Medicine/Prayer controllers. Pure utility, no state.

### Task 5: Test on physical devices

**Files to create/modify:**
- None (manual verification)

**Detailed changes:**
- Verify on at least one physical iOS and one physical Android device that:
  - The haptic is perceptible and not overly strong.
  - The haptic fires only on success, not on failure/no-op.
  - The haptic does not fire on undo/skip actions.

**Integration:** Manual QA step.

---

## Performance Considerations

- **Caching strategy:** N/A — `HapticFeedback.lightImpact()` is a fire-and-forget platform call.
- **Lazy loading:** N/A.
- **Memory efficiency:** No new objects or widgets — just a platform channel call.

---

## Testing

- `test/core/accessibility/haptic_feedback_test.dart` — mocks `HapticFeedback` and verifies:
  - `HapticFeedback.lightImpact()` is called exactly once after a successful water log.
  - `HapticFeedback.lightImpact()` is called exactly once after a successful medicine dose mark.
  - `HapticFeedback.lightImpact()` is called exactly once after a successful prayer toggle.
  - `HapticFeedback.lightImpact()` is NOT called on a failed write or no-op.

---

## Localization

No new ARB keys needed — haptic feedback is non-visual and non-audible.

---

## Edge Cases

1. **OS-level haptics disabled** — `HapticFeedback` silently no-ops; visual confirmation (snackbar) remains the primary channel.
2. **Haptic on no-op/failed write** — call must be in the success branch only, never before or during async operation.
3. **Undo action** — ensure undo path does not emit the same haptic; skip haptic on undo.
4. **Rapid repeated taps** — guard against duplicate haptics by only calling in the once-per-action success branch.
5. **Platform differences** — iOS Taptic Engine vs Android vibration motor; `lightImpact()` abstracts this, but verify perceptibility on both.

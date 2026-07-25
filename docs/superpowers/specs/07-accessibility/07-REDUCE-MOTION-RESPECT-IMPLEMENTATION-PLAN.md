# Implementation Plan: 07 Reduce-Motion Respect

## Overview

- **Spec:** Reduce-Motion Respect
- **Complexity:** S
- **Estimated effort:** 0.5 day
- **Dependencies:** Standalone, preventive. No code to change today if no animations exist yet.
- **Prerequisites:** No new dependency — `MediaQuery.disableAnimations` ships with Flutter.

---

## Implementation Tasks

### Task 1: Audit existing animations

**Files to create/modify:**
- Scan all `lib/` files for `AnimationController`, `Tween`, `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSwitcher`, `AnimatedPositioned`, `SlideTransition`, `FadeTransition`, `ScaleTransition`.

**Detailed changes:**
- Run a grep for animation-related widgets and classes across the codebase.
- For each found usage, check if it already respects `MediaQuery.disableAnimations`.
- Document findings (expected: minimal to none, based on current project state per spec).

**Integration:** Read-only audit pass.

### Task 2: Create reduce-motion helper utility

**Files to create/modify:**
- `lib/core/accessibility/reduce_motion.dart` (new)

**Detailed changes:**
- Create a utility:
  ```dart
  bool shouldAnimate(BuildContext context) {
    return !MediaQuery.disableAnimationsOf(context);
  }
  ```
- Or a widget wrapper `ReduceMotionWrapper` that conditionally applies animation or instant state change.
- This becomes the standing convention for all future animation work.

**Integration:** Consumed by any widget that uses animations.

### Task 3: Apply to existing animations (if any found)

**Files to create/modify:**
- Per audit findings (likely no changes needed currently).

**Detailed changes:**
- For each existing animation widget found in Task 1:
  - Wrap in a conditional: if `disableAnimations` is true, render the end-state directly without the animated transition.
  - For `AnimatedContainer`: replace with `Container` when reduce-motion is active.
  - For `AnimatedOpacity`: replace with `Opacity` at the target value.
  - For route transitions: use `NoTransitionPage` or instant `SlideTransition` when reduce-motion is active.

**Integration:** Each fix is localized to the specific animation widget.

### Task 4: Document the standing rule

**Files to create/modify:**
- `docs/engineering/coding-standards.md` (modify)

**Detailed changes:**
- Add a section: "Reduce-Motion Convention"
- Rule: "Any new `AnimationController`, `Tween`, `AnimatedContainer`, `AnimatedOpacity`, `Lottie`, or `Rive` usage must include a `MediaQuery.disableAnimations` check that provides a non-animated fallback reaching the same end state."
- Reference the `ReduceMotionWrapper` utility.

**Integration:** Documentation-only change.

### Task 5: Verify route transitions

**Files to create/modify:**
- `lib/core/router/app_router.dart` (modify, if needed)

**Detailed changes:**
- Check if `GoRouter` uses custom transitions (`CustomTransitionPage`, `SlideTransition`).
- If so, verify these honor `disableAnimations` or replace with instant transitions when the setting is active.
- Flutter's default `MaterialPageRoute` already respects `disableAnimations` — only custom transitions need checking.

**Integration:** Router-level change, affects all screen transitions.

---

## Performance Considerations

- **Caching strategy:** `MediaQuery.disableAnimations` is read from the framework's inherited widget — no caching needed.
- **Lazy loading:** N/A.
- **Memory efficiency:** The non-animated fallback actually uses less memory (no animation controller).

---

## Testing

- `test/accessibility/reduce_motion_test.dart`:
  - Pumps a widget with `MediaQuery(disableAnimations: true)` and verifies no `AnimationController` is running (or that the non-animated fallback state is rendered).
  - Pumps the same widget with `disableAnimations: false` and verifies the animation plays.
- Once Delightful/Gamification animations exist, unit test the `ReduceMotionWrapper` to confirm it branches correctly.
- Manual verification on both iOS and Android with OS reduce-motion toggle enabled.

---

## Localization

No new ARB keys needed — the non-animated fallback is the same state shown after an animation completes.

---

## Edge Cases

1. **Existing route transitions** — Flutter's default `MaterialPageRoute` honors `disableAnimations`; custom transitions may not.
2. **`AnimatedContainer` / `AnimatedOpacity` in existing widgets** — scan for all uses and wrap each.
3. **Lottie/Rive (if added later)** — convention must extend to those libraries' play/pause APIs.
4. **Partial reduction** — initial scope is binary (animate or instant); duration reduction is a future enhancement.
5. **End-state equivalence** — non-animated path must reach identical final state, just without the transition.

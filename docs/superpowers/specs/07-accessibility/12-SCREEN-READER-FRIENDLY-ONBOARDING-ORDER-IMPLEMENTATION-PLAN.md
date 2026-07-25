# Implementation Plan: 12 Screen-Reader-Friendly Onboarding Order

## Overview

- **Spec:** Screen-Reader-Friendly Onboarding Order
- **Complexity:** S
- **Estimated effort:** 0.5 day (when onboarding screen is built)
- **Dependencies:** BLOCKED on onboarding module-toggle screen being built. Today it's a placeholder.
- **Prerequisites:** The onboarding flow is currently a placeholder skeleton per CLAUDE.md.

---

## Implementation Tasks

### Task 1: BLOCKED — Wait for onboarding module-toggle screen

**Status:** This spec cannot be implemented until the onboarding module-toggle checklist screen (Water/Medicine/Prayer toggle screen) is built. Today it's a placeholder.

**What to do when unblocked:**

### Task 2: Add Semantics labels to module toggles

**Files to create/modify:**
- `lib/features/onboarding/presentation/onboarding_module_screen.dart` (modify, when screen exists)

**Detailed changes:**
- Each module toggle row (`SwitchListTile` or similar) must announce:
  - Module name (e.g. "Water", "Medicine", "Prayer").
  - Current state (on/off).
  - Purpose description (e.g. "Track your daily water intake" from `onboardingModuleWaterDesc`).
- Use `Semantics` wrapper with `label` and `toggled` properties:
  ```dart
  Semantics(
    label: '${module.name}, ${enabled ? "on" : "off"}',
    toggled: enabled,
    child: SwitchListTile(...),
  )
  ```
- Ensure the visual list order matches the focus/reading order (top to bottom).

**Integration:** Follows spec 01's labeling conventions for switches.

### Task 3: Verify skip path is reachable and labeled

**Files to create/modify:**
- `lib/features/onboarding/presentation/onboarding_module_screen.dart` (modify, when screen exists)

**Detailed changes:**
- The "I know what I want" / skip button (`onboardingModuleSkip`) must:
  - Have a clear `Semantics` label (e.g. "Skip module setup").
  - Be reachable by keyboard/tab.
  - Be visually prominent enough for a screen-reader user to find.
- Verify the skip button's `Semantics` label announces its purpose, not just its visual text.

**Integration:** Uses existing `onboardingModuleSkip` ARB key.

### Task 4: Verify toggle state announcements

**Files to create/modify:**
- `lib/features/onboarding/presentation/onboarding_module_screen.dart` (modify, when screen exists)

**Detailed changes:**
- When a toggle is switched, verify the screen reader immediately announces the new state (e.g. "Water, on" / "Water, off").
- Flutter's `SwitchListTile` should handle this automatically via its `Semantics` properties — verify and add explicit `Semantics(toggled: ...)` if needed.

**Integration:** Flutter's built-in `Switch` accessibility behavior.

### Task 5: Check other first-run screens

**Files to create/modify:**
- Notification permission explainer screen (verify, per CLAUDE.md)

**Detailed changes:**
- If a permission explainer screen exists (e.g. `notificationPermissionExplainerTitle`/`notificationPermissionExplainerBody`), verify:
  - All text is announced by screen readers.
  - The "Allow notifications" and "Not now" buttons are clearly labeled.
  - Focus order is logical (body text → Allow button → Not now button).

**Integration:** Uses existing permission explainer ARB keys.

### Task 6: Verify dashboard empty state

**Files to create/modify:**
- `lib/features/dashboard/presentation/dashboard_screen.dart` (verify)

**Detailed changes:**
- If the user skips all modules, the dashboard's empty state (`emptyDashboardMessage`) must also be accessible.
- Verify the empty state text is announced by screen readers.

**Integration:** Uses existing `emptyDashboardMessage` ARB key.

### Task 7: Tests

**Files to create/modify:**
- `test/features/onboarding/presentation/onboarding_accessibility_test.dart` (new, when screen exists)

**Detailed changes:**
- Widget test: verify each toggle announces name and state under semantics.
- Widget test: verify skip button is reachable and labeled.
- Widget test: verify toggle state changes are announced.
- Manual audit: walk the onboarding screen with TalkBack enabled.

**Integration:** Standard widget tests.

---

## Performance Considerations

- **Caching strategy:** N/A — semantics labels are resolved via `AppLocalizations`.
- **Lazy loading:** N/A.
- **Memory efficiency:** No impact — `Semantics` wrappers are lightweight.

---

## Testing

- Widget test: verify toggle announces name and state under semantics.
- Widget test: verify skip button is reachable and labeled.
- Manual audit: walk the onboarding screen with TalkBack enabled.

---

## Localization

No new ARB keys needed — the audit verifies existing toggle labels and skip/continue buttons are properly announced. The `Semantics` labels should use existing localized strings from `app_en.arb`/`app_bn.arb`.

---

## Edge Cases

1. **Toggle state announcement** — verify toggling announces "Water, on" / "Water, off" immediately.
2. **Skip path accessibility** — "Skip Setup" button must be keyboard-reachable and clearly labeled.
3. **Empty state** — if user skips all modules, dashboard's empty state must be accessible.
4. **Notification permission screen** — if it exists, check in the same pass as a first-run screen.

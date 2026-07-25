# Implementation Plan: 10 Focus-Order and Keyboard Navigation Pass

## Overview

- **Spec:** Focus-Order and Keyboard Navigation Pass
- **Complexity:** M
- **Estimated effort:** 1 day
- **Dependencies:** Pairs with specs 01 and 05 (shares screen walkthrough). All module forms exist.
- **Prerequisites:** Physical or simulated external keyboard / switch-control setup.

---

## Implementation Tasks

### Task 1: Tab through Water custom-log form

**Files to create/modify:**
- `lib/features/water/presentation/water_add_entry_screen.dart` (modify, if needed)

**Detailed changes:**
- Attach external keyboard and tab through the form fields:
  - Amount text field → Date/time picker → Notes field → Save button.
- Verify focus visits fields in visual top-to-bottom order.
- If any field is skipped or focus jumps illogically, add `FocusTraversalOrder` or reorder widgets in the widget tree.
- Verify the date/time picker dialog is keyboard-operable (tab to select date, arrow keys to navigate, enter to confirm).

**Integration:** Uses Flutter's default `FocusTraversalPolicy` unless override is needed.

### Task 2: Tab through Medicine add-medicine form

**Files to create/modify:**
- `lib/features/medicine/presentation/medicine_form_screen.dart` (modify, if needed)

**Detailed changes:**
- Tab through the multi-step form:
  - Step 0 (presets): tabs through preset tiles, custom schedule option.
  - Step 1 (schedule): name field → dosage field → stock toggle → stock fields → frequency picker → time pickers → duration selector → save button.
- Verify the repeat-rule picker is keyboard-operable (it may need explicit `Focus` node handling).
- Verify `showTimePicker` dialogs are keyboard-navigable.

**Integration:** Uses Flutter's `FocusTraversalPolicy`. Repeat-rule picker may need a custom `FocusNode`.

### Task 3: Tab through Medicine add-dose form

**Files to create/modify:**
- `lib/features/medicine/presentation/` dose-add screen (modify, if needed)

**Detailed changes:**
- Tab through dose entry fields in logical order.
- Verify all controls are reachable by keyboard.

**Integration:** Standard focus traversal.

### Task 4: Tab through Prayer settings form

**Files to create/modify:**
- `lib/features/prayer/presentation/prayer_settings_screen.dart` (modify, if needed)

**Detailed changes:**
- Tab through: calculation method dropdown → Asr method dropdown → Jumu'ah toggle → location mode dropdown → city picker → notification toggles.
- Verify dropdowns are keyboard-operable (open with Enter/Space, navigate with arrows, select with Enter).
- Verify the city picker is keyboard-navigable.

**Integration:** Standard focus traversal for `DropdownButton` and `Switch` widgets.

### Task 5: Verify form validation error focus

**Files to create/modify:**
- Per-module form screens (verify)

**Detailed changes:**
- Submit each form with invalid data and verify focus moves to the first error field.
- If focus doesn't auto-move to errors, add `FocusNode.requestFocus()` on the first error field in the form's validation callback.

**Integration:** Flutter's `FormState.validate()` doesn't auto-focus errors — manual `FocusNode` handling is needed.

### Task 6: Check dialog focus trapping

**Files to create/modify:**
- `lib/features/dashboard/presentation/` global month calendar bottom sheet (verify)
- Medicine add-stock dialog (verify)
- Any other dialogs/bottom sheets (verify)

**Detailed changes:**
- Verify that when a dialog or bottom sheet is open, Tab cycles within it and doesn't escape to background content.
- Flutter's `showDialog` / `showModalBottomSheet` handle focus trapping by default — verify this is the case.
- If focus escapes, wrap dialog content in a `FocusScope` with a custom `FocusTraversalPolicy`.

**Integration:** Flutter's dialog system handles this by default; verification is the main task.

### Task 7: Document findings

**Files to create/modify:**
- `docs/superpowers/specs/07-accessibility/10-keyboard-navigation-results.md` (new)

**Detailed changes:**
- Record focus order findings for each form.
- Document any `FocusTraversalPolicy` overrides added.
- Note any controls that are not keyboard-operable and need follow-up.

**Integration:** Repository artifact.

---

## Performance Considerations

- **Caching strategy:** N/A — focus traversal is a runtime behavior, not a cached value.
- **Lazy loading:** N/A.
- **Memory efficiency:** `FocusNode` objects are lightweight; adding explicit focus nodes has negligible overhead.

---

## Testing

- Widget tests verifying focus order on key forms using `FocusNode` traversal:
  - `test/features/water/presentation/water_form_focus_test.dart`
  - `test/features/medicine/presentation/medicine_form_focus_test.dart`
  - `test/features/prayer/presentation/prayer_settings_focus_test.dart`
- CI check that verifies focus traversal on key forms matches expected order.
- Manual audit walking every form with external keyboard.

---

## Localization

No new ARB keys needed — the audit verifies existing forms are keyboard-navigable.

---

## Edge Cases

1. **Form validation error focus** — `FormState.validate()` doesn't auto-focus; manual `FocusNode.requestFocus()` needed.
2. **Dialog focus trapping** — `showDialog`/`showModalBottomSheet` handle this by default; verify.
3. **Date/time picker focus** — Flutter's `showDatePicker`/`showTimePicker` open dialogs that may or may not be keyboard-navigable; verify on both platforms.
4. **Custom controls** — Medicine's repeat-rule selector and Prayer's city picker may need explicit `FocusTraversalPolicy` overrides.
5. **Settings toggles** — verify all `Switch`/`SwitchListTile` widgets are reachable and operable by keyboard.

# Focus-Order and Keyboard Navigation Pass

**Category:** Accessibility · **Atlas complexity:** M · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is an audit-and-fix item, not a net-new feature. Every module's forms (Water's custom-log entry, Medicine's add-dose/add-medicine forms, Prayer's settings forms) were built and tested with touch input in mind, and nobody has verified tab/focus order with an external keyboard or switch-control device attached. For a user who relies on a hardware keyboard or a switch-control scanning input rather than touch, an illogical focus order (jumping between unrelated fields, skipping a field entirely, or trapping focus in a widget) makes a form unusable even though it works perfectly by touch — a distinct failure mode from anything the screen-reader audit (item #1) catches.

## Goals

- Attach an external keyboard (or enable switch-control/scanning) and tab through every form across all three modules, confirming focus visits fields in a logical, visually-matching order and that every actionable control is reachable this way.
- Fix any form where default `FocusTraversalPolicy` ordering produces an illogical jump, using Flutter's existing focus-traversal APIs rather than a custom navigation system.
- Confirm submit/cancel actions and any custom controls (date/time pickers, repeat-rule selectors in Medicine, dropdowns) are all keyboard-operable, not just tab-reachable.

## Non-goals / out of scope

- Screen-reader semantics (that's item #1) — this item is about physical focus/tab order for keyboard and switch-control input, a different access need than TalkBack/VoiceOver navigation.
- Building any new keyboard-shortcut system (e.g. app-wide hotkeys) — this is purely about correct tab/focus traversal on existing forms.
- Non-form screens (list/detail/stats screens where there's little to focus) — scope this to the actual data-entry forms named in the atlas item.

## Proposed approach (high-level)

Walk each module's add/edit forms (Water custom-log, Medicine add-dose/add-medicine, Prayer settings) with an external keyboard attached (or switch-control/scanning enabled) and confirm Tab/Shift-Tab moves focus in the same order a sighted user would naturally move through the form visually, using Flutter's default `FocusTraversalPolicy` behavior as the starting point and only overriding traversal order where the default widget-tree order doesn't match the visual layout. Any control that isn't reachable by keyboard at all (custom pickers, repeat-rule selectors) needs its focus/activation behavior verified explicitly, since these are more likely than standard text fields to have been built with only touch gestures in mind.

## Dependencies & prerequisites

- Depends on all three modules' forms being feature-complete (they are, per current project state).
- Needs a physical or simulated external keyboard / switch-control setup to actually test tab order — this can't be verified from reading code alone.
- Can run independently of items #1 (screen-reader) and #5 (text-scaling), though scheduling it alongside those two since all three require a full walkthrough of the same screens is efficient.

## Open questions for the implementation round

- Are there any custom form controls (e.g. Medicine's repeat-rule picker) that may need an explicit `FocusTraversalPolicy` override rather than relying on default ordering?
- Should this audit also cover the Settings screen's various toggles/pickers, or is it scoped strictly to the "add-dose, add-medicine"-class data-entry forms named in the atlas item?
- Is switch-control/scanning testing considered in scope for this pass, or does it warrant its own separate audit given it's a different interaction model from a plain external keyboard?

## Effort & sequencing notes

Complexity M — moderate breadth (every form across three modules) with typically simple fixes (traversal-order overrides) once a bad order is found. Lower priority (Low retention impact) relative to items #1/#5/#6; can be scheduled alongside those since it reuses the same screen walkthrough.

## Database schema

No database changes. This is a code-level audit of focus-traversal
behavior.

## Localization

No new ARB keys needed. The audit verifies that existing forms are
keyboard-navigable, not that new text is accessible.

## Edge cases & error handling

- **Form validation error focus:** when a form submission fails
  validation, focus should move to the first error field. Verify this
  works with keyboard navigation.
- **Dialog focus trapping:** confirmation dialogs and bottom sheets
  (e.g. the global month calendar) need focus trapping — Tab should
  cycle within the dialog, not escape to the background.
- **Date/time picker focus:** Flutter's `showDatePicker`/`showTimePicker`
  open dialogs that may or may not be keyboard-navigable. Verify on
  both platforms.
- **Custom controls:** Medicine's repeat-rule selector and Prayer's
  location picker may need explicit `FocusTraversalPolicy` overrides.

## Cross-references

- Related: Spec 07-accessibility/01 (TalkBack audit) — complementary
  audit (physical focus vs. screen-reader semantics).
- Related: Spec 07-accessibility/06 (Simple Mode) — larger touch
  targets may change focus traversal order.
- Forms: per-module add/edit screens in `lib/features/*/presentation/`.

## Test strategy

- Widget tests: verify focus order on key forms using
  `FocusNode` traversal.
- Manual audit: walk every form with external keyboard.
- Regression: add a CI check that verifies focus traversal on key
  forms matches expected order.

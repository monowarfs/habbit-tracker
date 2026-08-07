# Focus-Order and Keyboard Navigation Pass — Results

**Spec:** `10-focus-order-keyboard-navigation-pass-design.md` /
`10-FOCUS-ORDER-KEYBOARD-NAVIGATION-PASS-IMPLEMENTATION-PLAN.md`
**Date:** 2026-08-07

## Method note (deviation from the plan's stated prerequisite)

The plan's prerequisite was a physical or simulated external keyboard.
No interactive simulator with an attached hardware keyboard is available
in this environment, so the audit instead used `flutter_test` widget
tests that drive `FocusNode`/`FocusManager` traversal directly —
`node.requestFocus()` for the starting field, then
`FocusManager.instance.primaryFocus!.nextFocus()` repeated once per
expected Tab press, asserting the resulting `hasFocus` at each step.
This exercises the exact same `FocusTraversalPolicy` machinery a
physical Tab key drives (Flutter's default `WidgetsApp` shortcuts map
Tab to the same `NextFocusIntent`/`nextFocus()` call), and is
CI-enforceable as a regression gate, at the cost of not producing a
recorded keyboard-driven screen capture.

Extracting the right `FocusNode` for a given on-screen control from a
widget test needed some care: `TextField` exposes its node directly via
`EditableTextState.widget.focusNode`, but `ListTile`/`FilledButton`/
`SwitchListTile` build their own `Focus` widget as a *descendant* of
themselves (wrapped around their `InkWell`), so `Focus.of(context)`
has to be looked up from something painted *inside* the control (an
`Icon`/`Text` child), not from the control's own element. `DropdownButton`
needed a third approach again: it pre-builds its (invisible, but still
present in the element tree) menu items inside its own subtree, each
wrapped in its own nested `Focus`/`ExcludeFocus`, so walking up from an
arbitrary descendant `Text` risks landing on one of those instead of the
button's own traversal-relevant node — the fix was to take the
*outermost* `Focus` descendant of the `DropdownButton`, found via
`find.byType(Focus).first`, which is the button's own.

## Coverage

- Water add-entry form (`WaterAddEntryScreen`) —
  `test/features/water/presentation/water_form_focus_test.dart`.
- Medicine add-medicine form, details + stock steps (`MedicineFormScreen`)
  — `test/features/medicine/presentation/medicine_form_focus_test.dart`.
- Prayer settings form (`PrayerSettingsScreen`) —
  `test/features/prayer/presentation/prayer_settings_focus_test.dart`.
- Manual code-read audit (no dedicated widget test) of: Medicine dose
  actions (`DoseTile`), Medicine stock-refill dialog (`StockCard`),
  Medicine rename/archive/unarchive dialogs (`MedicineDetailScreen`),
  Dashboard's global month calendar bottom sheet
  (`_GlobalCalendarSheet`).

## Task-by-task findings

### Task 1 — Water custom-log form tab order

**Already correct, no change.** `WaterAddEntryScreen`'s body is a plain
`Column` (amount field → notes field → date/time `ListTile` → Save
button); tab order follows the default `FocusTraversalPolicy`, which
walks the widget tree in build order — identical to the visual
top-to-bottom layout. The date/time `ListTile` (opens `showDatePicker`
then `showTimePicker`) is a standard focusable/tappable Material
control, reachable and operable by keyboard (Enter/Space activates it);
both picker dialogs are Flutter's stock `showDatePicker`/`showTimePicker`,
which are keyboard-navigable by default (arrow keys move the calendar
grid/time spinner, Enter confirms). No `FocusTraversalOrder` override
needed.

### Task 2 — Medicine add-medicine form tab order

**Already correct, no change.** Verified two of the four steps directly
with widget tests (Details: name → dosage → Next; Stock: track-stock
switch → count → threshold, in both the collapsed and
stock-tracking-enabled states). The Schedule step's repeat-rule
`RadioListTile`s and duration `ChoiceChip`s are stock Material widgets
— each individually focusable and operable via Space/Enter — matching
"reachable and operable," which is what the plan asks this task to
verify; Flutter doesn't provide roving-arrow-key radio-group navigation
out of the box, and the plan doesn't ask for it here. `showTimePicker`
(used for picking the schedule's time-of-day) is the same stock,
keyboard-navigable dialog as Task 1's.

### Task 3 — Medicine add-dose form

**No such screen exists in this codebase; audited the closest
equivalent instead.** Per `CLAUDE.md`'s Medicine section, doses are
never manually created through a form — they're derived automatically
by `planDoseMaterialization` into the rolling `medicine_doses` window.
The user-facing analog to "logging a dose" is the action row on each
`DoseTile` in the dose timeline: a note-icon `IconButton`, and (while
unresolved) skip/done `IconButton`s. All three are stock Material
`IconButton`s, focusable and operable by keyboard by default — no gap
found. Flagged here as a plan/codebase mismatch rather than silently
skipped.

### Task 4 — Prayer settings form tab order

**Already correct, no change.** Verified with a widget test covering
the default (auto-location) state: calculation-method dropdown → Asr
dropdown → "Observe Jumu'ah" switch → location-mode dropdown →
prayer-notifications switch → pre-reminder switch. All three
`DropdownButton`s and three `SwitchListTile`s are stock Material
widgets in build order matching the visual layout; `DropdownButton` is
keyboard-operable by default (Enter/Space opens it, arrow keys move the
selection, Enter confirms). The manual-location city `DropdownButton`
only renders when `locationMode == manual`, so it wasn't exercised in
the default-state test, but it's the same `DropdownButton` construction
as the other two — no reason to expect different behavior.

### Task 5 — Validation-error focus

**Found and fixed on both forms that have text-entry validation.**
`FormState.validate()` isn't even in use on either screen (both build
plain `Column`s of individually-validated `TextField`s), and neither
was moving focus to the field carrying the new error text:

- **Water add-entry:** `_save()` already set an inline error message on
  the amount field's `errorText` (for both the "amount must be > 0" and
  "no future date/time" failures — the latter is a pre-existing product
  choice this pass didn't change, not a bug this spec covers) but never
  focused it. Added a `FocusNode` on the amount `TextField` and
  `requestFocus()` it whenever `_error` is set.
- **Medicine form:** worse than a missing focus move — `_nextStep()`'s
  empty-name guard on the Details step silently no-opped with *zero*
  feedback of any kind (not even a visual error), for any input method.
  Added an inline `errorText` on the name field (reusing the existing
  `profileNameRequiredError` string, "Enter a name." — no new ARB key
  needed, per the plan) plus a `FocusNode` that gets `requestFocus()`'d
  alongside it, and clears the error as soon as the user starts typing.

Prayer's settings form has no text-entry validation (only
dropdowns/switches, all always valid), so Task 5 doesn't apply there.

### Task 6 — Dialog focus trapping

**Already correct by construction, no change.** Every dialog/bottom
sheet audited — Dashboard's global month calendar
(`showModalBottomSheet`) and its per-day detail dialog (`showDialog`),
Medicine's stock-refill dialog and its rename/archive/unarchive dialogs
(all `showDialog` + `AlertDialog`) — goes through Flutter's stock
`showDialog`/`showModalBottomSheet`, which push a new, focus-scoped
route with a modal barrier by default: Tab cannot reach anything behind
the barrier while the route is on top. None of them roll their own
`OverlayEntry`-based popup that would need a manual `FocusScope`/
`FocusTraversalPolicy` wrapper. (The one `OverlayEntry` usage
elsewhere in the app, `ReportsScreen._shareMonth`'s off-screen
`RecapCardCapture` render for the share-image export, is never shown to
the user at all — positioned at `left: -9999` purely to let
`RenderRepaintBoundary` lay out and capture it — so it isn't a dialog
and doesn't need focus trapping.)

## Edge cases from the plan, re-checked

1. **Form validation error focus** — found missing on both applicable
   forms (Water, Medicine); fixed on both (Task 5).
2. **Dialog focus trapping** — confirmed correct everywhere audited
   (Task 6).
3. **Date/time picker focus** — confirmed `showDatePicker`/
   `showTimePicker` are keyboard-navigable by default (Task 1/2); not
   re-verified per-platform (no device/simulator available in this
   environment), but this is stock Flutter framework behavior, not
   app code.
4. **Custom controls** — Medicine's repeat-rule selector is built from
   stock `RadioListTile`s (Task 2); Prayer's city picker is a stock
   `DropdownButton` (Task 4). Neither needed a custom
   `FocusTraversalPolicy` override.
5. **Settings toggles** — every `Switch`/`SwitchListTile` audited
   (Medicine's stock toggle, Prayer's three switches) is reachable and
   operable by keyboard by default.

# Haptic Feedback on Log/Complete

**Category:** Accessibility · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is a net-new feature, and a small one. Today, marking a dose taken, a prayer done, or logging water relies on a visual confirmation (a snackbar, a state change on screen) to tell the user the action registered. A low-vision user, or anyone acting quickly without looking closely at the screen, may not notice that confirmation. A short haptic pulse on a successful log/complete action gives an immediate, non-visual confirmation channel — this is standard iOS/Android system-level practice for confirm actions, not a novel interaction.

## Goals

- Add a short, distinct haptic pulse (e.g. a light impact) at the moment a log/complete action succeeds, across all three modules' primary log actions (water quick-add/custom log, medicine dose marked done, prayer checklist toggle to done).
- Keep the haptic tied to actual success — it should not fire on a failed write or a no-op.
- Make it feel like a system-level confirm, not a novelty buzz — short and consistent across modules.

## Non-goals / out of scope

- Distinct haptic patterns per module or per action type — one consistent "confirm" pulse is the goal, not a haptic vocabulary.
- A settings toggle to disable haptics specifically (if the OS-level haptic/vibration setting is respected by the underlying API, that's sufficient; no separate in-app switch unless the implementation round finds a gap).
- Any audio equivalent — that's covered separately for notification actions in item #8, and is out of scope for in-app foreground actions here.

## Proposed approach (high-level)

Use Flutter's built-in `HapticFeedback` API (no new dependency) triggered at the same point in each module's controller where a log/complete action currently confirms success — the existing quick-add/custom-log flow in Water, dose-marked-done flow in Medicine, and checklist-toggle flow in Prayer. This is a small addition to each module's existing success path, not a new abstraction; each module already has one clear place where "the write succeeded" is known, and that's where the haptic call belongs.

## Dependencies & prerequisites

- No new dependency — `HapticFeedback` ships with Flutter.
- Depends only on each module's existing log/complete success path already being identifiable (they are, per current project state — Water/Medicine/Prayer are all complete modules).
- Should respect the OS-level haptics/vibration setting automatically, since `HapticFeedback` defers to the platform; confirm this during implementation rather than adding app-level logic to re-check it.

## Open questions for the implementation round

- Should undo/skip/snooze actions also get a (different, lighter) haptic, or is this scoped strictly to the positive "done" confirmation?
- Does the existing snackbar/visual confirmation stay as-is alongside the haptic, or does the haptic reduce the need for the snackbar's prominence?
- Any platform difference to account for (iOS's richer haptic engine vs. Android's simpler vibration motor) or is the same `HapticFeedback.lightImpact()`-class call acceptable on both?

## Effort & sequencing notes

Complexity S — a one-line addition at three or four known success points, no new UI or dependency. Independent of the other items in this category; can ship any time, including in parallel with the audits.

## Localization

- No new ARB keys are needed — haptic feedback is non-visual and non-audible in terms of strings; the user perceives it through the device's vibration motor, not through any on-screen text.
- If a settings toggle is added later to control haptics (see open question), it would require new ARB keys (`settings_haptic_feedback_label`, `settings_haptic_feedback_description`), but the initial implementation does not need them.
- Existing snackbar confirmation strings (e.g. `water_log_success`, `medicine_dose_marked_done`, `prayer_toggle_done`) that accompany the haptic remain unchanged.

## Edge cases & error handling

1. **OS-level haptics disabled** — `HapticFeedback` automatically defers to the platform's vibration settings; if the user has disabled system vibration, the haptic silently no-ops. The visual confirmation (snackbar/state change) must remain the primary confirmation channel — the haptic is additive, not a replacement.
2. **Haptic fires on a no-op or failed write** — the haptic call must be placed strictly after the write succeeds in the controller's success path, not before or during the async operation. If the DB write throws or returns an error, no haptic should fire.
3. **Undo action triggering haptic** — if the undo path also goes through a success callback, ensure it does not emit the same "done" haptic; either skip the haptic on undo or use a distinct lighter pattern (per open question). The safest initial approach is to not fire haptics on undo.
4. **Platform differences in haptic richness** — iOS's Taptic Engine provides richer haptic patterns than Android's vibration motor; `HapticFeedback.lightImpact()` abstracts this, but the implementer should verify on a real Android device that the haptic is perceptible and not annoyingly strong compared to iOS.
5. **Rapid repeated taps** — if a user double-taps the log button before the first write completes, the second haptic should not fire if the second action is a no-op (already logged). Guard against duplicate haptics by only calling `HapticFeedback` in the success branch that runs exactly once per action.

## Cross-references

- `docs/superpowers/specs/07-accessibility/08-audio-cue-alternative-notification-actions-design.md` — audio earcons for notification actions (complementary but scoped to background/locked-screen path).
- `lib/features/water/presentation/` — Water quick-add/custom-log controller success path.
- `lib/features/medicine/presentation/` — Medicine dose-marked-done controller success path.
- `lib/features/prayer/presentation/` — Prayer checklist-toggle controller success path.
- Flutter's `HapticFeedback` API — no external dependency; ships with the framework.

## Test strategy

- **Widget tests**: Create `test/core/accessibility/haptic_feedback_test.dart` that mocks `HapticFeedback` (using `TestWidgetsFlutterBinding` or a wrapper) and verifies:
  - `HapticFeedback.lightImpact()` is called exactly once after a successful water log.
  - `HapticFeedback.lightImpact()` is called exactly once after a successful medicine dose mark.
  - `HapticFeedback.lightImpact()` is called exactly once after a successful prayer toggle.
  - `HapticFeedback.lightImpact()` is NOT called on a failed write or no-op.
- **Unit tests**: If the haptic call is extracted into a small helper (e.g. `confirmationHaptic()`), unit test the helper directly to confirm it delegates to `HapticFeedback.lightImpact()`.
- **Regression-prevention strategy**: Since `HapticFeedback` calls are one-liners at known success points, a widget test per module that asserts the call was made (via mock/spy) is sufficient. No golden tests needed — haptics are not visual.
- **Manual verification**: Test on at least one physical iOS and one physical Android device to confirm the haptic is perceptible and not overly strong.

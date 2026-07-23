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

# Sound Design Pass, Optional Off by Default

**Category:** Delightful · **Atlas complexity:** S · **Retention impact:** Low-Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Habitica leans on satisfying sound feedback (task completion chimes,
level-up sounds) as a cheap but genuinely effective reinforcement signal.
This app currently relies entirely on the OS notification sound and
silent in-app interactions, which is appropriately unobtrusive by default
but leaves a small, easy opportunity on the table: a distinct, soft
in-app chime when a dose is marked done (or a water goal is hit, or a
prayer is checked off) gives a moment of tactile satisfaction that a
purely visual state change doesn't. Because this needs to be strictly
optional and off by default — Rafiq and many users in this app's target
demographic keep phones on silent as a matter of course — this is
explicitly a respectful addition, not a default behavior change.

## Goals

- Add a short, pleasant sound effect on key completion actions (dose
  marked done at minimum; water/prayer completion optionally too).
- Ship with the feature off by default — purely opt-in via a Settings
  toggle.
- Make the sound distinct from the OS notification sound, so it reads as
  an intentional in-app touch rather than a duplicate alert.
- Respect system silent/vibrate mode — the in-app sound should not
  override a user's phone being on silent.

## Non-goals / out of scope

- No sound design system covering every interaction in the app (button
  taps, navigation, etc.) — scoped specifically to completion/success
  moments.
- No custom sound packs or user-selectable sound themes in v1 — one
  well-chosen default sound per completion type is enough to start.
- No changes to notification sounds themselves (those are OS-level and
  already configurable via the existing notification channel setup).

## Proposed approach (high-level)

This is a small, self-contained addition: a Settings toggle (defaulting
to off) that, when enabled, plays a short local sound asset at the same
moment a completion action already triggers other feedback (e.g.,
whatever visual confirmation already happens when a dose is marked
done). The audio-playback mechanism itself is a bounded, well-trodden
problem — a lightweight audio-playing dependency plays a short bundled
asset file, checked against the toggle before every play, and should
respect the device's silent/vibrate state so it never becomes an
unwanted interruption. No existing engine needs to change; this hooks
into the same action-completion points that already exist across
Water/Medicine/Prayer for their own state updates and (where applicable)
achievement-engine triggers.

## Dependencies & prerequisites

- An audio-playback capability (a small, already-common Flutter
  dependency, or platform-native sound APIs if that's simpler than
  pulling in a package) — this app hasn't needed one before, so it would
  be a genuinely new dependency to evaluate.
- Settings screen space for the toggle.
- One or a small handful of short sound asset files to bundle.
- Confirmation that respecting system silent mode is the platform
  default behavior for whatever playback mechanism is chosen (it usually
  is, but should be verified rather than assumed).

## Open questions for the implementation round

- Which specific completion actions get a sound — dose-done only, or
  also water quick-add and prayer checklist toggles?
- One universal chime, or a distinct (but related) sound per module,
  echoing the per-module accent-color pattern used elsewhere?
- Which audio package (if any) is the lightest-weight option that still
  reliably respects silent mode across both Android and iOS?
- Does this toggle live globally in Settings, or per-module (a user might
  want it for Medicine but not Water)?

## Effort & sequencing notes

Complexity S — small, isolated feature with one new dependency
decision. No dependency on other atlas items; pairs naturally with item
2 (the streak-save celebration animation) if the two are ever bundled
into a single "celebratory feedback" pass, though neither requires the
other.

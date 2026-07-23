# Audio Cue Alternative for Notification Actions

**Category:** Accessibility · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is a net-new feature. When a user acts on a notification's Done/Snooze/Skip action — often from a locked screen, without opening the app — the only confirmation today is whatever the OS itself shows (a brief system UI change), which a low-vision user may not see. A distinct short sound ("earcon") per action gives an immediate audible confirmation that the tap registered and which action was taken, matching the iOS convention of using distinct accessibility sounds for distinct outcomes.

## Goals

- Play a short, distinct sound for each of the three notification actions (Done, Snooze, Skip) at the moment the action handler processes it, so the user gets audible confirmation of which action fired without needing to look at the screen.
- Keep the three sounds clearly distinguishable from each other (e.g. an ascending tone for Done vs. a neutral tone for Snooze vs. a lower tone for Skip), not just "a beep" for all three.
- Make sure this works both when the handler runs in the foreground and when it runs in the background isolate (both paths currently exist for these actions).

## Non-goals / out of scope

- A full custom sound-design pass or brand sound identity — three short, clearly distinguishable system-style tones are sufficient.
- Respecting a silent/DND OS state is assumed to be handled by the OS's own notification-sound rules, not re-implemented in-app — the app plays a sound through the normal channel, it doesn't override system silence settings.
- Any visual or haptic equivalent — haptics for in-app actions are covered separately in item #4; this item is specifically about the background/locked-screen notification-action path.

## Proposed approach (high-level)

Add a short sound-play call at the point each notification action currently completes its processing — the background-isolate Done/Snooze/Skip action handler that already exists as the single place all three actions are processed, whether triggered from the foreground or from a fresh background isolate. Bundle three short audio assets (or reuse platform system sound APIs if available for the confirm/dismiss/neutral cases) and trigger playback keyed to which action ran, using the same action-handler entry point that already fans out Done/Snooze/Skip today rather than adding a second call site.

## Dependencies & prerequisites

- Depends on the existing notification action handler and its background-isolate entry point already existing (they do, per current project state) as the single place to hook in playback for both foreground and background triggers.
- Needs a small number of short audio assets bundled with the app (or a decision to use platform system sounds instead, avoiding new assets entirely).
- Should be checked against platform constraints on playing audio from a background isolate/headless context, which may differ between Android and iOS.

## Open questions for the implementation round

- Bundle custom audio assets, or use each platform's built-in system sound APIs to avoid adding audio files to the app bundle?
- Does this need a Settings toggle to disable earcons independently of the OS's own sound/vibration settings, or is respecting the OS notification-sound setting sufficient?
- Are there platform limitations on playing a sound from the background isolate that already exists for action handling, and if so, does the sound need to instead play only when the app is subsequently foregrounded?

## Effort & sequencing notes

Complexity S — one shared action-handler hook, three short sounds, no new architecture. Independent of the other items in this category; lowest priority in the list (Low retention impact) so it can slot in whenever convenient rather than needing early sequencing.

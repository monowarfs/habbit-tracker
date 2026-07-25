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

## Localization

- Audio earcons are non-linguistic (short tones, not speech), so they do not need en/bn ARB translations.
- However, if a settings toggle is added to enable/disable earcons (per open question), new ARB keys are needed:
  - `settings_audio_cues_label` — "Audio Cues" / "অডিও কিউ"
  - `settings_audio_cues_description` — "Play sounds when acting on notifications" / "নোটিফিকেশনে কাজ করার সময় শব্দ বাজান"
- The notification action handler itself (`notification_action_handler.dart`) already uses localized strings for notification titles/bodies; the earcon logic is additive and does not change existing localized content.

## Edge cases & error handling

1. **Background isolate audio playback limitations** — on Android, playing audio from a background isolate/headless context may be restricted by the OS; the implementer should test the `notification_action_handler.dart` background path and fall back to playing the sound only when the app is foregrounded if background playback fails.
2. **OS Do Not Disturb / Silent mode** — the app should not bypass the user's system-level sound settings; if the OS is in DND or silent mode, the earcon should not play. `HapticFeedback` (item #4) is the complementary channel that works even when sound is silenced.
3. **Audio asset bundle size** — three short audio files (each under 50KB) add minimal bundle size, but if platform system sound APIs are used instead (per open question), no assets are bundled at all; prefer system sounds where available to avoid bundle bloat.
4. **Rapid successive actions** — if a user taps Done then immediately taps Snooze on two different notifications, both earcons should play sequentially (not overlap); queue audio playback rather than firing concurrent play calls.
5. **Foreground vs. background sound consistency** — the same earcon for "Done" should sound identical whether the app is in the foreground or background; verify that the audio playback path produces the same result in both cases.

## Cross-references

- `docs/superpowers/specs/07-accessibility/04-haptic-feedback-on-log-complete-design.md` — haptics for in-app foreground actions (complementary to earcons for background/locked-screen actions).
- `docs/superpowers/specs/07-accessibility/01-talkback-voiceover-navigation-audit-design.md` — screen-reader users may also benefit from audio cues; verify no conflict between earcons and TalkBack/VoiceOver audio.
- `lib/core/notifications/notification_action_handler.dart` — the single entry point where Done/Snooze/Skip are processed; the earcon hook goes here.
- `lib/core/notifications/notification_background_handler.dart` — the background isolate entry point; must also trigger earcons.
- `lib/core/notifications/notification_service.dart` — the notification plugin wrapper; may provide platform-specific sound APIs.

## Test strategy

- **Unit tests**: Create `test/core/notifications/audio_cue_test.dart` that:
  - Mocks the audio playback API and verifies the correct earcon is triggered for each action (Done, Snooze, Skip).
  - Verifies that the earcon fires from both the foreground handler and the background isolate handler paths.
  - Verifies that rapid successive actions queue audio sequentially (no overlap).
- **Widget tests**: Not applicable — earcons are non-visual and triggered from the notification action handler, not from widget code.
- **Regression-prevention strategy**: Add a test in `test/core/notifications/notification_action_handler_test.dart` that asserts `playEarcon(action)` is called for each action type, ensuring future refactors don't accidentally remove the earcon hook.
- **Manual verification**: Test on at least one physical iOS and one physical Android device with the app both in the foreground and background; verify earcons are audible, distinct, and not played when the OS is in silent/DND mode.

# Voice Logging (On-Device Speech-to-Text)

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Logging today always requires navigating to a module's screen and
tapping through a UI, even for the simplest action ("I took my morning
dose"). Apple Health's voice-entry pattern shows that a short spoken
command can meaningfully lower the friction of routine logging,
particularly for accessibility (users with limited dexterity or vision)
and for quick hands-busy moments (cooking, driving). Since this app
already has a natural-language quick-add parser planned for Water (item
02), voice logging is a thin input-method layer on top of the same
parsing/action-matching logic rather than a separate feature built from
scratch.

## Goals
- Let a user speak a short command ("mark my morning dose taken", "log 2
  glasses of water") and have the app recognize the intended module and
  action.
- Keep all speech recognition on-device — no audio ever leaves the
  device, consistent with the app's offline/no-account trust story.
- Serve as both an accessibility win and a convenience shortcut,
  reachable from wherever quick actions already live (e.g. the
  dashboard's quick-actions strip from Run 15).

## Non-goals / out of scope
- No cloud speech-to-text service of any kind — only on-device engines.
- No open-ended conversational assistant — a bounded set of recognized
  command phrases/intents, not general voice control of the whole app.
- No always-listening/background voice activation — this is an
  explicit, user-initiated action (e.g. holding a mic button), not
  passive listening.

## Proposed approach (high-level)
A speech-to-text package that runs its recognition entirely on-device
converts spoken audio to text locally; that text is then handed to the
same rule-based intent/parameter extraction the natural-language
quick-add feature already builds (item 02) — the module/action-matching
step (e.g. "morning dose" → MedicineModule's relevant dose, "taken" →
the Done action) plus its parsing for Water's amount/time phrases. This
keeps voice logging a thin front-end on top of existing text-parsing
logic and each module's already-existing action-handling paths (the same
`onNotificationAction`-style Done/Snooze/Skip handling Medicine and Water
already implement for notification actions), rather than a parallel
logging pipeline. The UI surface is a mic-trigger control with a visible
transcript-and-confirm step before any action is actually applied, so a
misrecognition is caught before data is logged.

## Dependencies & prerequisites
- An on-device speech-to-text package (e.g. the `speech_to_text` plugin
  family) — a new dependency, evaluated specifically for on-device-only
  operation, not one that silently phones home to a cloud recognition
  service.
- Microphone permission handling (iOS/Android), including a clear
  permission-rationale moment consistent with how notification
  permissions are already explained in this app.
- The natural-language quick-add parser (item 02) as the intent/parameter
  extraction layer this feature reuses, if built in that order.

## Open questions for the implementation round
- Which on-device STT package best covers both English and Bangla given
  the app's existing en/bn localization commitment — on-device engine
  language coverage varies significantly by platform and package.
- What's the bounded vocabulary/command grammar — a fixed phrase list, or
  a looser pattern grammar reusing item 02's parser across all modules
  (not just Water)?
- Does this need its own dedicated screen/entry point, or does it hang
  off the dashboard's existing quick-actions strip?
- How is a low-confidence transcription handled — always show the
  confirm step, or only when recognition confidence is below a threshold
  (if the chosen package even exposes one)?

## Effort & sequencing notes
Complexity M — the speech-to-text integration itself is a fairly
standard plugin wiring, but the intent-matching layer's quality (and
therefore user trust in the feature) depends heavily on the natural-
language quick-add parser from item 02 being solid first. Sequencing
this after item 02 avoids duplicating parsing logic.

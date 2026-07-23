# Captioned Onboarding

**Category:** Accessibility · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is a preventive, conditional item: it's a standing requirement to apply if and when a specific other feature ships, not something with code to write today. No onboarding animation or video exists in the app yet (onboarding is still a placeholder skeleton per CLAUDE.md). If the Must Have or Delightful categories' atlas items ever add an onboarding animation or video, WCAG 2.1 requires it to be usable without sound and without relying on the visual track alone — captions and a text-only alternative need to be there from the first ship, not retrofitted after users without audio or without full vision have already had a broken first-run experience.

## Goals

- Establish the requirement, ahead of time: any onboarding animation or video added by another atlas feature ships with synchronized captions and a text-only alternative (a plain-text walkthrough covering the same content) available from day one.
- Make sure whichever feature builds the onboarding animation treats captions/text-alternative as part of that feature's own definition of done, not a follow-up task.
- Keep the text-only alternative genuinely equivalent in content, not a stripped-down summary.

## Non-goals / out of scope

- Designing or building any onboarding animation/video itself — that belongs to whichever Must Have/Delightful feature introduces it.
- Audio-description tracks for purely decorative visual flourish that carries no informational content — captions and a text-alternative for informational content are the bar, not a full audio-description production.
- Any other onboarding accessibility concern — the screen-reader operability of the onboarding module-toggle flow is covered separately in item #12.

## Proposed approach (high-level)

Treat this as a requirement to attach to the backlog item that eventually builds an onboarding animation/video, rather than a standalone task with its own implementation today: whenever that feature is scheduled, its plan should include synchronized captions on the video/animation track and a parallel plain-text version of the same onboarding content, reachable without needing to watch or listen to the media at all. Since the onboarding flow is currently just a skeleton placeholder, there's no existing asset to retrofit — the cheapest path is simply making sure this requirement is visible to whoever implements the eventual animation, so it's built in rather than bolted on.

## Dependencies & prerequisites

- Fully dependent on the Must Have/Delightful onboarding animation/video feature being scheduled first — there is nothing to caption or provide a text-alternative for until that exists.
- No current onboarding animation exists in the codebase to audit (onboarding is a placeholder today per CLAUDE.md).
- Should be referenced from whichever spec eventually defines the onboarding animation/video, so this requirement isn't lost between categories.

## Open questions for the implementation round

- Which specific atlas item (Must Have or Delightful) is expected to introduce the onboarding animation, so this requirement can be attached to that item's own spec directly rather than tracked separately?
- Should the text-only alternative be a route within the app (a plain-text onboarding screen) or simply the captions themselves serving double duty?
- Do captions need bn translation from day one alongside en, consistent with the rest of the app's localization approach?

## Effort & sequencing notes

Complexity S, but effectively zero-effort today since there is no onboarding animation yet. Sequence: this is a requirement to carry forward and attach to whichever future spec adds an onboarding animation/video — it isn't schedulable as independent work right now.

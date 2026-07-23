# Progressive Module Unlock in Onboarding

**Category:** Long-Term Retention · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
This category is about what keeps someone using the app in month six and year two, and the single biggest predictor of a long relationship is often what happened in the first five minutes. A new user handed three toggles (Water/Medicine/Prayer) and asked to configure all of them before they've felt any payoff is exactly the setup cost that produces early abandonment before month six ever arrives — the user never builds the first habit loop that would have carried them there. Starting minimal (just Water, the simplest module) and surfacing Medicine and Prayer later as optional, low-pressure suggestions gives the user a chance to succeed at one thing before being asked to commit to three.

## Goals
- Reduce day-one onboarding to a single, minimal-setup module rather than a wall of three module toggles.
- Surface the other modules as an optional, dismissible suggestion after the user has some initial success with the first (not immediately, not never).
- Preserve the ability for a user who already knows they want all three modules to enable them upfront — this is a default path, not a removed capability.

## Non-goals / out of scope
- No change to the modules themselves once enabled — this only affects the onboarding sequencing, not module functionality.
- No forced module ordering beyond "Water first" — the atlas names Water as the natural minimal starting point given its simplicity relative to Medicine's repeat-rule engine or Prayer's location/method setup.
- No A/B-testable onboarding variants in this pass — one sequenced flow.
- No changes to `module_registry.dart`'s registration mechanism itself — modules are still all registered; this only changes what's surfaced/enabled during onboarding.

## Proposed approach (high-level)
The onboarding skeleton currently presents module setup as a single step; this reshapes it into a sequence where Water is enabled by default with minimal setup (or as the sole highlighted option), while Medicine and Prayer are mentioned as available but deferred, with an explicit path to enable them from within Settings or a dashboard suggestion. The mechanism these later suggestions plug into is the module registry's existing enable/disable concept — no new module lifecycle is needed, just a later, lower-pressure entry point to the same enablement action onboarding already performs upfront. A "suggest a new module" moment (e.g. after the user has logged a few days of water, or simply after a short time delay) is the main new surface, likely a dashboard card or a one-time prompt rather than a hard gate.

## Dependencies & prerequisites
- The onboarding skeleton, to be resequenced.
- `module_registry.dart`'s module enable/disable mechanism, reused rather than replaced for the deferred-enrollment moment.
- A trigger condition for when to suggest the next module (time-based, activity-based, or both) — needs to be defined.
- Settings screen, since users need a persistent way to enable Medicine/Prayer manually regardless of whether the suggestion fires.

## Open questions for the implementation round
- What exactly triggers the "you might also like Medicine/Prayer" suggestion — elapsed time, a completed streak, first successful week?
- Does a user who skips Water during onboarding (e.g. they only want Medicine) still get funneled through a "start with one module" flow, or does onboarding let them pick any single starting module?
- Should suggested-but-declined modules be re-suggested later, or is it a one-time offer per module?
- Does this materially change new-user analytics/success metrics in a way that needs baseline comparison before/after?

## Effort & sequencing notes
Complexity M — reshapes an existing onboarding flow and adds one new deferred-suggestion surface, but doesn't touch module internals. Lower urgency than the inactivity-nudge or pause-mode features since it affects only new users, not the existing base of long-term users this category is mostly about; reasonable to sequence later in this category's rollout.

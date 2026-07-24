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

## Resolved Dependencies
| Prerequisite | Status | Required by |
|---|---|---|
| Module enable/disable mechanism in `module_registry.dart` | **Not built** — currently all modules register as always-on; no per-user enable/disable toggle exists. Must be added before this spec can gate module visibility. | This spec |
| Onboarding flow (`/onboarding` route) | **Not built** — no onboarding screen or route exists in the codebase. Must be created before resequencing it. | This spec |
| Drift schema migration for `onboarding_progress` table | **Not built** — no onboarding state table exists. Needed to persist which modules the user has enabled/dismissed during onboarding. | This spec |
| Multi-profile data model | **Not built** — Spec 09 depends on this. No impact on this spec unless onboarding state needs to be per-profile (likely yes). | Spec 09 |

## Dependencies & prerequisites
- **Module enable/disable mechanism** (`module_registry.dart`): Currently all modules are registered as always-on; there is no per-user toggle. This spec requires adding an enable/disable API (likely a `module_settings` Drift table) so onboarding can start with Water-only and later enable Medicine/Prayer. This is a cross-cutting infrastructure gap — build it once, reuse in Settings.
- **Onboarding flow**: No onboarding route/screen exists. Must be created from scratch — at minimum a `GoRouter` route under a new `/onboarding` path, with steps for module selection and initial Water setup.
- **Schema migration plan**: Any new tables (`onboarding_progress`, `module_settings`) require Drift migration steps. No migration infrastructure beyond the initial schema exists yet; this must be addressed.
- **Settings screen**: Already exists — users need a persistent way to enable Medicine/Prayer manually regardless of whether the suggestion fires.
- **Cross-cutting gap:** Module enable/disable mechanism must be built as shared infrastructure before this spec can gate module visibility (see Resolved Dependencies row 1).
- **Cross-cutting gap:** Schema migration for `onboarding_progress` and `module_settings` tables must be planned and executed (see Resolved Dependencies row 3).
- **Cross-cutting gap:** Module enable/disable must trigger `planAndApplyNotifications` to cancel/re-plan notifications when modules are toggled (see Edge Cases).

## Open questions for the implementation round
- **Trigger for "you might also like" suggestion**: Decision — use a time + activity hybrid: show the suggestion after the user has logged at least 3 water entries OR 3 days have elapsed, whichever comes first. This avoids both "too early to care" and "too late to matter."
- **Skip-Water onboarding path**: Decision — onboarding presents Water as the recommended starting module but allows the user to pick any single module. A "I know what I want" escape hatch avoids forcing a flow that contradicts user intent.
- **Re-suggestion after decline**: Decision — once per module. If the user declines Medicine during onboarding, do not re-surface the suggestion card. The user can always enable modules manually from Settings.
- **Analytics impact**: Decision — track `onboarding_module_selected` and `onboarding_module_skipped` events. No A/B test needed for v1; measure conversion from onboarding to 7-day retention as a baseline, compare against current (no-onboarding) baseline after rollout.

## Edge Cases & 3-4 Year Considerations
- **User enables all modules during onboarding**: Must not show the deferred-suggestion card. Track enabled modules at onboarding completion; if all three are on, skip the "suggest" phase entirely.
- **User force-quits mid-onboarding**: On resume, restart onboarding from the beginning (not from a partial state). Persisting partial onboarding state adds complexity for minimal benefit in v1.
- **New module added in future (e.g. a 4th module)**: The deferred-suggestion mechanism should be data-driven (list of suggestible modules from a config), not hardcoded. When a new module ships, add it to the suggestible list — no new onboarding code needed.
- **Module enable/disable interaction with notifications**: Disabling a module must cancel its pending notifications. Enabling must re-plan them via the existing notification planner. This is a cross-cutting concern — the enable/disable API must trigger `planAndApplyNotifications`.
- **Onboarding state vs. settings state**: If a user disables Medicine in Settings after the onboarding phase, the deferred-suggestion should not re-suggest it. The "has been suggested" flag and the "is currently enabled" state are separate concerns.

## Acceptance Criteria
- [ ] New users see only Water module enabled by default after completing onboarding.
- [ ] Medicine and Prayer are visible but not enabled during onboarding; user can opt in if desired.
- [ ] A "You might also like Medicine/Prayer" suggestion card appears on the Dashboard after the defined trigger condition (3 entries or 3 days).
- [ ] Suggestion card is dismissible per-module; dismissed modules are not re-suggested.
- [ ] All modules can be enabled/disabled from Settings without restarting onboarding.
- [ ] Disabling a module cancels its pending notifications; enabling re-plans them.
- [ ] `onboarding_module_selected` and `onboarding_module_skipped` events are logged.
- [ ] Drift migration for new tables (`onboarding_progress`, `module_settings`) succeeds cleanly.
- [ ] Onboarding restarts cleanly on force-quit (no partial state persisted).

## Effort & sequencing notes
Complexity M — reshapes an existing onboarding flow and adds one new deferred-suggestion surface, but doesn't touch module internals. Lower urgency than the inactivity-nudge or pause-mode features since it affects only new users, not the existing base of long-term users this category is mostly about; reasonable to sequence later in this category's rollout. Depends on module enable/disable infrastructure being built first (cross-cutting gap).

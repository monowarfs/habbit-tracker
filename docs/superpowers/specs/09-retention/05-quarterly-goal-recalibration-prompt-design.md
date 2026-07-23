# Quarterly Goal-Recalibration Prompt

**Category:** Long-Term Retention · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
A goal set on day one — a water target, a medicine schedule — is right for the life the user had on day one. By month six or year two, that life has usually changed: a new job, a new season, a new prescription, a body that needs less or more. Apps that never revisit the original setup quietly become less accurate over time, and an inaccurate goal is a slow, invisible reason a long-term user disengages ("this app thinks I should drink 2.5L but I stopped needing that months ago"). A periodic, low-friction "still right for you?" check-in is a small nudge that keeps the app's model of the user from going stale across a multi-year relationship.

## Goals
- Periodically (roughly quarterly) surface a dismissible prompt asking whether a module's current goal still fits.
- Make the prompt one tap to dismiss and one tap to jump into the relevant settings/goal-editing screen.
- Keep it infrequent and skippable enough that it never feels naggy — this is a check-in, not a gate.
- Cover the goal-bearing entities that plausibly go stale (Water's daily target, at minimum; Medicine schedules if the atlas intends it broadly).

## Non-goals / out of scope
- No automatic goal adjustment or AI-suggested new targets — this only prompts the user to look, it never changes a goal itself.
- No recalibration for Prayer (its "goal" is a fixed set of five daily prayers, not a tunable target) — scope to Water and, if desired, Medicine schedule review.
- No complex scheduling engine — a simple "last shown" timestamp per module is enough, not a general-purpose campaign scheduler.
- No in-app survey/feedback collection tied to this — it's a direct link to settings, not a questionnaire.

## Proposed approach (high-level)
This is a lightweight, mostly presentation-layer feature: a periodic check (on app open, similar in spirit to other periodic checks already in the app) comparing "time since this module's goal was last confirmed or edited" against a quarterly threshold, sourced from each module's existing settings/goal entity (Water's goal entity already has the amount and, implicitly, whenever it was last changed). When the threshold is crossed, show a small dismissible banner or bottom-sheet prompt on the relevant module's screen, linking directly to its existing goal-editing UI. Dismissing resets the timer; editing the goal also resets it naturally since the goal's own last-modified point moves forward.

## Dependencies & prerequisites
- Water's goal entity (and Medicine's schedule entity, if included) — needs a "last confirmed/edited" timestamp to compare against.
- The settings entity, for storing a lightweight "last shown" marker per module if the goal entity itself doesn't already carry a usable timestamp.
- Each module's existing goal-editing screen, as the destination the prompt links to — no new editing UI.

## Open questions for the implementation round
- Is "quarterly" a fixed 90-day interval from install date, or from the last time the goal was actually touched?
- Should dismissing "not now" differ from dismissing "yes it's still right" (the latter could reset the timer further out, the former sooner)?
- Does this need its own settings toggle to opt out entirely for users who find any prompt intrusive?
- Where does it render — dashboard-level banner, or per-module screen only?

## Effort & sequencing notes
Complexity S — a timestamp comparison and a dismissible banner, no new domain logic. Low-risk, can be built independently of everything else in this category; reasonable to slot in whenever a quiet sprint needs a small win.

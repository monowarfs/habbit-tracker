# Gentle Re-Engagement Nudge After Inactivity

**Category:** Long-Term Retention · **Atlas complexity:** S · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Every retention feature in this category exists because streaks and week-one novelty eventually run out. When a year-two user goes quiet for a week — travel, a bad stretch, simple forgetting — most habit apps respond with an escalating guilt campaign of daily reminders. This app has committed to a no-guilt tone throughout (soft reminders, no shaming copy), and the silence-then-nothing default is itself a retention failure: users who lapse and are never gently invited back just stay gone. A single warm "pick back up?" message after roughly a week of no activity is the minimum intervention that respects both the user and the tone the app has already set.

## Goals
- Detect sustained inactivity (no logging across any module) over a meaningful window (~7 days).
- Send exactly one warm, low-pressure notification — not a recurring or escalating series.
- Keep copy consistent with the app's existing no-guilt reminder tone.
- Reset cleanly once the user logs anything again, so it can fire again after a future lapse.

## Non-goals / out of scope
- No multi-stage drip campaign (day 3, day 7, day 14 escalation) — explicitly one message.
- No per-module inactivity nudges in this pass (this is a whole-app "haven't seen you" signal, not "you haven't logged water").
- No A/B-testable notification copy variants — one message, one tone.
- No push-to-re-onboard flow; this is just a notification, not a forced walkthrough.

## Proposed approach (high-level)
Track a simple last-activity timestamp derived from the most recent write across all modules (any log, dose, or prayer record touch). Extend the existing notification planner's scheduling window logic to include a single conditional "re-engagement" notification candidate: if the gap since last activity crosses the threshold and no such nudge has fired since the last activity reset, schedule one. This slots into the planner's existing 3-day materialization window and cap logic rather than requiring a separate scheduling subsystem — it's just another notification candidate the planner considers, sourced from a lightweight last-activity query instead of a module's own `pendingNotifications()`. The ledger (already tracking sent notifications) is the natural place to record "nudge already sent for this inactivity period" to prevent duplicates.

## Dependencies & prerequisites
- The notification planner and its existing scheduling/cap/diff logic.
- A queryable "last activity across all modules" signal — needs a lightweight cross-module timestamp query, likely a new small helper rather than a per-module concept.
- The notification ledger, to dedupe so the nudge doesn't refire every day once the threshold is crossed.
- Copy that matches the existing reminder tone (no new localization system, just new strings in the existing en/bn arb files).

## Open questions for the implementation round
- Exactly what counts as "activity" — does opening the app count, or only a logged entry/dose/prayer record?
- Should the threshold be a fixed 7 days or configurable in settings?
- Does the nudge need per-module content ("you haven't logged water in a while") or is a single generic "pick back up?" message sufficient for v1?
- How does this interact with a user who has disabled notifications entirely — silent no-op, or is this exempt from per-module notification toggles?

## Effort & sequencing notes
Complexity S — small, self-contained addition to existing notification infrastructure, no new domain concepts. High retention impact for low effort makes this a strong early candidate within this category, largely independent of the others.

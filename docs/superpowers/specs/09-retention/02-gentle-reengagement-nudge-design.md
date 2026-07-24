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

## Resolved Dependencies

These prerequisites must be built before this spec can be implemented:

1. **`installDate` field (shared with Spec 01)** — While the nudge does not directly use `installDate`, it must respect the same first-use grace period: never nudge a user within their first 7 days of app usage. The `installDate` field (added for Spec 01) provides this.
2. **`ModuleDayStatusKind.paused` awareness** — If a user has all modules paused (e.g. on vacation), the 7-day inactivity threshold should not count paused days. The `paused` variant (added for Spec 01/03) feeds the last-activity query so paused days do not trigger a nudge.
3. **Schema migration** — A new `last_activity_at` column (or computed field) on `app_settings` for efficient cross-module activity tracking, with a Drift migration step.
4. **Cross-module last-activity query** — A `LastActivityRepository` or helper that queries the most recent write timestamp across `water_logs`, `medicine_doses`, and `prayer_records` tables. This is new infrastructure shared with any future cross-module analytics.

## Dependencies & prerequisites

- The notification planner and its existing scheduling/cap/diff logic.
- A queryable "last activity across all modules" signal — needs a lightweight cross-module timestamp query, likely a new small helper rather than a per-module concept.
- The notification ledger, to dedupe so the nudge doesn't refire every day once the threshold is crossed.
- Copy that matches the existing reminder tone (no new localization system, just new strings in the existing en/bn arb files).
- **Cross-cutting gap:** `installDate` field for first-use grace period (see Resolved Dependencies #1).
- **Cross-cutting gap:** `ModuleDayStatusKind.paused` variant so paused days do not count as inactivity (see Resolved Dependencies #2).
- **Cross-cutting gap:** Drift schema migration for `last_activity_at` column (see Resolved Dependencies #3).
- **Cross-cutting gap:** New `LastActivityRepository` for cross-module last-write query (see Resolved Dependencies #4).
- **Cross-cutting gap:** `planAndApplyNotifications()` currently only accepts candidates from module `pendingNotifications()` and must be extended to accept system-level candidates (e.g. the re-engagement nudge) without coupling to a specific module.

## Edge Cases & 3–4 Year Considerations

- **All modules paused:** A user who pauses all modules for a month should NOT receive a re-engagement nudge — they made a deliberate choice. The last-activity query must exclude paused-status days.
- **User returns on day 6:** If the user logs anything on day 6 (before the 7-day threshold), the inactivity timer resets. The check must run on each app foreground, not just on a cron.
- **Multiple modules, staggered activity:** A user logs water daily but hasn't opened Medicine in 2 weeks. Per the spec's scope (whole-app nudge, not per-module), this should NOT trigger — only total cross-module silence counts.
- **Notification permission revoked:** If notifications are disabled, the nudge is a no-op. Add a Dashboard banner as fallback (same pattern as the existing notification-permission explainer screens).
- **Year 2–3 user who regularly takes breaks:** The nudge resets after every activity, so it can fire multiple times across the app's lifetime. This is intentional — each lapse gets exactly one nudge, and returning resets the counter.
- **First 7 days of app usage:** Never nudge during the first 7 days after `installDate` — the user is still learning the app.
- **Schema migration for `last_activity_at`:** Seed to `DateTime.now()` for existing installs so the timer starts fresh post-migration, avoiding a false nudge on first launch after update.

## Acceptance Criteria

- [ ] Exactly one re-engagement notification fires after 7 consecutive days with no logged activity across any module.
- [ ] The nudge does NOT fire if any module was `paused` during the 7-day window (paused days excluded from inactivity calculation).
- [ ] The nudge does NOT fire within the first 7 days after `installDate` (grace period).
- [ ] Once the user logs any activity, the inactivity timer resets and the nudge can fire again after a future 7-day lapse.
- [ ] The notification ledger records "nudge sent" with a timestamp to prevent duplicate nudges within one inactivity period.
- [ ] If notifications are disabled, a Dashboard banner替代通知 (fallback banner) is shown instead.
- [ ] en/bn localization strings added for the nudge notification text and Dashboard fallback banner.
- [ ] `last_activity_at` column exists in `app_settings` (or equivalent) with Drift migration.
- [ ] Cross-module last-activity query correctly returns the most recent write across `water_logs`, `medicine_doses`, and `prayer_records`.
- [ ] The feature is toggleable via a settings switch (default: on), separate from per-module notification toggles.

## Open questions for the implementation round

- ~~Exactly what counts as "activity"~~ → **Resolved:** Only logged entries (water log, medicine dose, prayer record) count. Opening the app alone does NOT count — the signal must be a deliberate user action of logging something.
- ~~Should the threshold be fixed 7 days or configurable~~ → **Resolved:** Fixed 7 days in v1. Configurability adds settings UI complexity for minimal retention gain — revisit if user feedback requests it.
- ~~Does the nudge need per-module content~~ → **Resolved:** Single generic "We missed you — pick back up where you left off?" message for v1. Per-module content ("you haven't logged water") is a fast-follow if needed, but adds localization burden for marginal benefit.
- ~~How does this interact with disabled notifications~~ → **Resolved:** If notifications are disabled system-wide, fall back to a Dashboard banner on next app open. The nudge respects per-module notification toggles (if a user disabled Water reminders, that doesn't suppress the whole-app nudge — it's a separate opt-out).

## Effort & sequencing notes
Complexity S — small, self-contained addition to existing notification infrastructure, no new domain concepts. High retention impact for low effort makes this a strong early candidate within this category, largely independent of the others. **Must be sequenced after** `installDate` infrastructure (Resolved Dependencies #1) and `paused` variant (Resolved Dependencies #2) are in place.

# Habit-Stacking Suggestions

**Category:** Delightful · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Atomic Habits' central technique — anchoring a new habit to an existing
one ("after I do X, I will do Y") — is currently only present in this app
as a design inspiration, not a feature. This app already has the raw
ingredient no benchmarked competitor across TickTick/Habitica/Streaks/Loop
uses this way: real cross-module timestamp data, entirely local, from
users who track multiple habits (Rafiq logs medicine, water, and prayer
in the same app). A one-tap, low-pressure surfaced suggestion ("you
usually log water right after your morning dose — want a stacked
reminder?") turns passive data the app already has into an active,
personalized nudge — without becoming the kind of prescriptive coaching
voice the personas explicitly react against.

## Goals

- Detect a real, recurring temporal correlation between two logged
  events across modules (e.g., water logged shortly after a medicine dose
  is marked done, on multiple distinct days).
- Surface this as a single, dismissible, opt-in suggestion — never an
  automatically-applied change.
- If accepted, create or adjust a reminder so the second habit's
  reminder is nudged to follow the first habit's typical action time.
- Keep the suggestion infrequent enough that it reads as a genuine
  insight, not a recurring nag.

## Non-goals / out of scope

- No general-purpose "smart reminder" ML/prediction system — this is a
  simple, explainable correlation over a bounded local window, not a
  model.
- No cross-device or cloud analytics — all correlation happens against
  data already on-device.
- No stacking suggestions that span more than two habits at once in v1.
- No modification of existing reminders without explicit user
  acceptance of the specific suggestion.

## Proposed approach (high-level)

The building block is a lightweight, local analysis over each module's
already-persisted log timestamps — no new data collection, since Water's
entries, Medicine's dose-done timestamps, and Prayer's records already
carry the timestamps needed. A periodic (not real-time) check looks for a
consistent short time gap between one module's completed action and
another's, across enough distinct days to be a real pattern rather than
coincidence, and if found, produces a single suggestion surfaced
somewhere low-friction — plausibly the dashboard, alongside the existing
quick-actions or upcoming strip, since that's already the app's spot for
"one more small thing you could do." Accepting the suggestion should
translate into an adjustment the existing reminder-planning system
already knows how to express (a new or retimed reminder slot for the
second habit), rather than inventing a new kind of reminder object.
Declining or ignoring the suggestion should suppress it for a cooldown
period so it doesn't reappear pushily.

## Dependencies & prerequisites

- Read access to each module's own logged-event timestamps (Water entries,
  Medicine dose-done times, Prayer record completion times) — all already
  persisted, no new tables needed for the raw data itself.
- Some new small piece of state to track "suggestion shown/accepted/
  dismissed" so it doesn't repeat endlessly.
- The reminder-planning system's existing mechanism for scheduling a
  module's reminders, to actually apply an accepted suggestion.
- The dashboard's existing quick-actions/upcoming surface, if that's
  where the suggestion is shown.

## Open questions for the implementation round

- What correlation threshold (how many days, how tight a time window)
  counts as "a real pattern" versus noise — needs a concrete, testable
  rule, not just "usually."
- Where does the suggestion live — dashboard card, a dedicated
  notification, or both?
- How is "accepted" actually applied — does it create a brand-new
  reminder, or retime an existing one, and which module's reminder-
  scheduling code owns that decision?
- Should this run only for users with 2+ modules enabled (a single-module
  user like Nusrat has nothing to stack against)?
- How is the underlying analysis job triggered — app-resume, a periodic
  background check, or on-demand only?

## Effort & sequencing notes

Complexity M — the correlation logic itself can be simple, but it spans
three modules' data and needs a new small suggestion/dismissal state plus
a UI surface. No hard dependency on other atlas items, but naturally
follows once the dashboard's quick-actions/upcoming surface (already
built in Run 15) is confirmed to be the right home for this kind of
one-off suggestion card.

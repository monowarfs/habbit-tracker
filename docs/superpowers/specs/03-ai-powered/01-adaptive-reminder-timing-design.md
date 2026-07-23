# Adaptive Reminder Timing

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Every module today schedules reminders at fixed, user-chosen times, but real
adherence data (when a user actually taps Done vs. lets a notification sit
until Snooze or Skip) already exists in the notification ledger and goes
unused. Users who habitually respond an hour later than their configured
time are effectively being reminded at the wrong moment every single day,
which is exactly the kind of silent friction that erodes streaks and, over
weeks, causes disengagement. No competitor benchmarked in the atlas does
this well, so it's a genuine differentiator for this app's "just works"
positioning rather than a catch-up feature.

## Goals
- Detect, per reminder slot, a consistent gap between scheduled time and
  actual Done-action timestamp over a rolling window of history.
- Suggest (or, if the user opts in to auto-adjust, silently apply) a nudged
  reminder time that better matches observed behavior.
- Work identically across Water, Medicine, and Prayer reminder slots since
  all three already write to the same notification ledger shape.

## Non-goals / out of scope
- No cross-device sync of learned timing (there is no account/cloud layer).
- No machine-learning model, embeddings, or training pipeline of any kind.
- Not a replacement for user-set schedules — always a suggestion/nudge on
  top of, never a silent override without some visible signal (exact UX,
  e.g. a one-time prompt vs. a settings toggle, is left to the
  implementation round).
- Does not touch Snooze/Skip semantics themselves, only future scheduling.

## Proposed approach (high-level)
The mechanism is pure on-device arithmetic over existing history, not a
model: read recent entries from the notification ledger for a given
module/slot, compute the median (or similar robust statistic) offset
between each notification's scheduled time and the timestamp of the
Done action that eventually closed it out, and if that offset is
consistently large and stable across enough samples, treat it as a signal
worth surfacing. The notification planner already owns the "what time do
we schedule next" logic (the 3-day/64-cap materialization window), so this
becomes an additional input alongside the user's configured time — e.g. a
`suggestedOffsetMinutes` value the planner can fold in, gated behind
whatever consent/opt-in mechanism the implementation round designs. Each
module's own reminder-slot definition (Water's quick-add reminders,
Medicine's dose reminders, Prayer's per-prayer reminders) would need to
expose enough identity for the ledger query to group history correctly.

## Dependencies & prerequisites
- Sufficient notification ledger history to compute a meaningful signal
  (a brand-new install has nothing to learn from).
- A decision on UX for surfacing/confirming the adjustment (silent
  auto-shift vs. an explicit "we noticed you usually respond around X,
  want to move this reminder?" prompt).
- No new packages — this is arithmetic over data already being persisted.

## Open questions for the implementation round
- What's the minimum sample size and window length before a suggestion is
  considered statistically meaningful enough to act on?
- Should this be per-slot (e.g. one Medicine dose time) or per-module
  (an overall shift applied to all of a module's reminders)?
- How does this interact with a user who deliberately keeps irregular
  hours (e.g. shift workers) — is there a way to detect "too noisy to
  learn from" and simply not suggest anything?
- Does the suggestion get its own row/flag in the notification ledger or
  a new lightweight table for storing the learned offset?

## Effort & sequencing notes
Complexity M — the arithmetic itself is simple, but wiring a new input
into the existing notification planner touches a well-tested pure
function and needs care not to regress its existing window/cap/diff
logic. Reasonable to sequence after any other notification-planner
changes settle, so this isn't competing with unrelated edits to the same
file.

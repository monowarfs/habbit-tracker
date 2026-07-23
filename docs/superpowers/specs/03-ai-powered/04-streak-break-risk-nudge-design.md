# Streak-Break Risk Nudge

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Streaks are one of this app's core retention mechanics (per the existing
`day_status_streaks` reporting logic and each module's own streak
calculators), but today a user only finds out they broke a streak after
midnight, when it's too late to do anything about it. Duolingo's
streak-freeze nudge pattern shows that a single, well-timed late-day
reminder — "you haven't logged today, and yesterday you had by this
time" — meaningfully reduces accidental streak breaks caused by simply
forgetting, as opposed to a deliberate lapse. This is a targeted,
low-noise addition: one extra nudge, only when genuinely at risk.

## Goals
- Detect, for a given user/module/day, that historical behavior suggests
  a log/action should have already happened by this point in the day but
  hasn't yet.
- Send at most one additional, gentle nudge per day per module when that
  condition is met, distinct from the module's regular scheduled
  reminders.
- Avoid nagging: only fire when an active streak is actually at risk, not
  every day regardless of streak state.

## Non-goals / out of scope
- No prediction model — this is a same-time-yesterday (or same-time-median-
  of-recent-days) comparison, not a trained classifier.
- Does not modify the existing streak calculation logic itself, only adds
  a notification trigger informed by it.
- Not a per-module bespoke feature — the goal is one shared mechanism all
  three modules can plug into via their own log-history data, though each
  module's "did the relevant thing happen today" check is necessarily
  module-specific (a Water log vs. a Medicine dose vs. a Prayer record).

## Proposed approach (high-level)
Pure local pattern detection, no model: for each module, look at the
current local day, find the typical time-of-day by which the user has
historically already logged/completed today's expected action (e.g. the
median completion time over recent days with an active streak), and if
that time has passed today with no corresponding action yet, and an
active streak would break if the day ends without one, schedule a single
extra local notification before midnight. This reuses each module's own
existing streak-calculation use case (Water's `CalculateWaterStreakUseCase`
and its Medicine/Prayer equivalents) to determine "is a streak actually at
risk", and rides the same `core/notifications` scheduling/ledger
infrastructure every other reminder already uses — this is a new
*trigger condition* for the existing engine, not a new engine.

## Dependencies & prerequisites
- Each module's existing streak calculators and log/dose/record history.
- The existing notification scheduling and ledger infrastructure (this
  nudge is just another notification content type flowing through it).
- A decision on how "historically logs by roughly this time" is defined
  robustly enough to avoid false positives for irregular users.

## Open questions for the implementation round
- Where does the "is it late enough in the day to worry" check run —
  piggybacking on the existing app-resume/WorkManager top-up triggers, or
  does it need its own scheduled check point?
- How many days of history are needed before the app trusts a "typical
  time" pattern enough to nudge on it (a brand-new streak has nothing to
  compare against)?
- Should the user be able to opt out of this nudge type specifically,
  separate from disabling a module's reminders entirely?
- Does this apply per-module independently, or is there value in a single
  combined "you're at risk of breaking N streaks today" nudge?

## Effort & sequencing notes
Complexity M — the detection logic is straightforward arithmetic over
existing streak/history data, but getting the "at risk" threshold right
without becoming an annoying false-positive machine needs real tuning and
probably a period of dogfooding before it's trustworthy. Reasonable to
sequence after adaptive reminder timing (item 01), since both read from
similar historical-behavior data and might share some groundwork.

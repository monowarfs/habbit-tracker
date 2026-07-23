# Streak Freeze / Grace Token

**Category:** Gamification · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Streaks are the app's core motivational hook across Water, Medicine, and
Prayer, but an all-or-nothing streak resets to zero on a single missed day —
exactly the anxiety pattern Duolingo's own users complained about before it
shipped a forgiveness mechanic. For a health-adjacent, offline-first app
whose users are already managing enough (illness, travel, bad days), one
punitive miss undoing weeks of real adherence risks driving people to quit
the app rather than resume the habit. A once-a-month "freeze" that preserves
the streak counter through a single miss softens that cliff without
pretending the miss didn't happen.

## Goals

- Let a user consume one grace token per rolling month to protect a streak
  from resetting after a single missed day, per module.
- Make the grace clearly visible as "used" in history/stats so it doesn't
  quietly inflate the user's sense of adherence.
- Keep the mechanic opt-in-by-default but transparent — no hidden magic that
  makes the streak number untrustworthy.

## Non-goals / out of scope

- Earning additional freezes through in-app currency or purchases (that's a
  point-shop concern, tracked separately).
- Retroactively repairing streaks broken before this feature ships.
- Cross-module shared freeze pools (each module's streak is protected
  independently, at least for v1).

## Proposed approach (high-level)

The existing per-module streak calculators already determine whether a given
day counts as a streak-continuing day. Extend that calculation with a
"protected miss" concept: when a day would otherwise break the streak and a
grace token is available for the current month, the calculator treats that
day as neutral (streak preserved, but not incremented) rather than a break,
and marks the token as spent. The dashboard's day-completion indicator and
the history calendar would need a distinct visual state (e.g. a shield icon)
for a grace-protected day, distinguishing it from a genuinely completed day.
Token availability/consumption is small persistent state, likely modeled
alongside existing streak/achievement data rather than a new subsystem.

## Dependencies & prerequisites

- Existing streak calculators per module (Water/Medicine/Prayer).
- Dashboard day-completion indicator and history calendar (for the visual
  "protected" state).
- Achievements engine, if freeze usage should itself surface as a
  notable event (optional).

## Open questions for the implementation round

- Is the grace token per-module or a single shared token across all three
  modules per month?
- Does "one per month" reset on the calendar month or a rolling 30-day
  window?
- Should the user get to choose which missed day to protect after the fact,
  or is it applied automatically to the first miss?
- How does this interact with Medicine's dose-level statuses (missed doses
  vs. missed days) versus Water/Prayer's simpler daily completion model?
- Does a used grace token need to be visible in exported data/backups?

## Effort & sequencing notes

Medium complexity — the core logic is a targeted extension of existing
streak calculators, but touches three modules' definitions of "day
completed" plus two UI surfaces (dashboard indicator, history calendar).
Reasonable to schedule early since it directly strengthens the existing
streak system rather than depending on anything new.

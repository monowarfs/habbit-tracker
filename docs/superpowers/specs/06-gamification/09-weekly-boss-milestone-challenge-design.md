# Weekly "Boss" Milestone Challenge

**Category:** Gamification · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Daily routine and open-ended streaks are the app's steady-state loop, but
there's currently no periodic moment that feels bigger than an ordinary
day — Habitica's boss battles give players a recurring, higher-stakes
event on top of daily quests, pacing excitement in a way pure daily habit-
tracking doesn't. A single harder-than-usual weekly target (e.g. a longer
prayer streak goal, a stretch water-consistency target) gives users a
periodic "big moment" to look forward to and rally toward, distinct from
the steady grind of daily completion.

## Goals

- Define one distinctly harder weekly challenge (the "boss") per week,
  scoped to a stretch goal beyond routine daily completion.
- Grant a noticeably bigger reward than a normal daily/weekly quest for
  clearing it.
- Make the boss challenge feel like a special event, not just another
  entry in an ever-growing quest list.

## Non-goals / out of scope

- Multiple simultaneous boss challenges — one per week, app-wide, to keep
  it feeling like a distinct event rather than more routine tracking.
- User-configurable boss difficulty — a curated, fixed set of challenge
  templates for v1.
- Any social/competitive framing (e.g. "raid" mechanics with other users)
  — this is a solo challenge, consistent with the app's offline-first,
  no-account design.

## Proposed approach (high-level)

This sits directly on top of the weekly quest chains feature and the
achievements engine's evaluation approach — the boss challenge is
mechanically a weekly quest, just with a higher threshold, a distinct
presentation (bigger visual treatment, a countdown framing), and a bigger
reward. Progress evaluation reuses the same event-driven data each module
already produces; the differentiator is presentation and stakes, not new
tracking logic. Because the reward should feel "bigger," this pairs
naturally with the XP system existing first (a bigger XP payout being the
easiest way to make a boss feel more significant than a routine quest).

## Dependencies & prerequisites

- Weekly quest chains (the boss challenge is best modeled as a variant of
  that same mechanism rather than a parallel system).
- The achievements engine's event-driven evaluation, as the underlying
  progress source.
- The cross-module XP/level system, for a reward that can scale up
  meaningfully relative to routine quests.

## Open questions for the implementation round

- Is the boss challenge module-specific (a different module gets the
  spotlight each week) or does the user pick which module's stretch goal
  to attempt?
- What determines the difficulty curve — fixed thresholds, or does it
  scale with the user's own historical performance?
- Does failing a boss challenge carry any negative framing, or does it
  simply expire without penalty like a missed weekly quest?
- Should there be a distinct "boss cleared" badge/certificate, tying into
  the milestone-certificate feature?

## Effort & sequencing notes

Medium — mechanically an extension of weekly quest chains with a
presentation and reward-scaling difference, not new tracking
infrastructure. Sequence after both weekly quest chains and the XP system
exist, since it borrows structure from the former and stakes from the
latter.

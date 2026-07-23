# Cross-Module XP / Level System

**Category:** Gamification · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

The app currently gives users three separate module streaks (Water,
Medicine, Prayer) and a per-module achievement gallery, but nothing that
aggregates "how am I doing overall" into one number. Habitica's enduring
pull is a single level that rises from any kind of progress — it gives
users one satisfying line going up regardless of which habit they engaged
with today. For a user juggling three unrelated modules, a unified level
reframes "I only did my water goal today" from a fragmented partial win
into visible overall progress, which is a stronger daily-return hook than
three separate, easily-ignored streak counters.

## Goals

- Award XP for meaningful completions across all three modules (and future
  modules) into one cross-module total.
- Convert accumulated XP into a level with a simple, predictable curve the
  user can see progress toward.
- Surface current level/XP progress prominently on the dashboard.

## Non-goals / out of scope

- Any spendable currency or shop (that's the point-shop feature, which
  explicitly depends on this one existing first).
- Rebalancing or replacing the existing per-module streaks — XP is
  additive, not a replacement for streak displays.
- Competitive or social use of level (leaderboards are a separate,
  later-dependent feature).

## Proposed approach (high-level)

The achievements engine already listens to each module's own write path as
the event source for unlocking achievements, rather than a periodic sweep.
The same event stream is the natural place to also award XP — each
qualifying completion event (a water log, a dose marked done, a prayer
checked off, a day fully completed) emits an XP amount, accumulated into a
single running total. A simple deterministic level curve (e.g. increasing
XP thresholds per level) derives the displayed level from the total. The
dashboard gains a compact level/XP-progress element near the existing
day-completion indicator; a dedicated screen or the existing achievements
gallery could show the fuller history of how XP was earned.

## Dependencies & prerequisites

- Achievements engine's event stream (the mechanism that already reacts to
  each module's write path).
- Dashboard, for the level/XP display surface.
- A decision on XP values per action type across three modules with very
  different completion granularities (single daily prayer times vs.
  multiple water logs vs. per-dose medicine).

## Open questions for the implementation round

- Should XP awards be visible per-action (a toast/animation) or only
  reflected passively in the aggregate?
- How do we normalize XP value across modules so no single module
  dominates leveling (e.g. Medicine's multiple daily doses vs. Prayer's
  five fixed daily prayers)?
- Does leveling up itself trigger a celebratory moment, and does that
  overlap with the achievements engine's existing unlock notifications?
- Is XP retroactively backfilled from existing historical data, or does
  the count start from zero at feature launch?

## Effort & sequencing notes

Medium complexity — mechanically it's an additive listener on an event
stream that already exists, plus one new dashboard element and a level
curve. Sequence this before the point-shop and boss-challenge features,
both of which explicitly depend on XP as their currency/pacing input.

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

## Database schema

New `xp_ledger` table:

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | UUID v7 |
| module_id | TEXT | which module earned the XP |
| event_type | TEXT | `'action'` \| `'day_complete'` \| `'streak_milestone'` |
| xp_amount | INTEGER | positive value earned |
| source_id | TEXT NULL | e.g. dose_id, prayer_record_id for audit |
| created_at | INTEGER | UTC |

New `xp_balance` singleton table:

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | always `'singleton'` |
| total_xp | INTEGER | cumulative XP earned (never decreases) |
| current_level | INTEGER | derived from `total_xp` via level curve |
| created_at, updated_at | INTEGER | |

Level is computed from `total_xp` at read time using the curve formula,
not persisted — this avoids level-rollback edge cases.

## Localization

New ARB keys (en/bn):
- `xpGainToast` — "+{amount} XP" toast on action.
- `levelUpTitle` / `levelUpBody` — celebration on level-up.
- `levelDisplay` — "Level {level}" dashboard label.
- `xpProgress` — "{current}/{next} XP to next level" progress text.

## Edge cases & error handling

- **XP normalization across modules:** Medicine earns less per-dose XP
  than Water per-log XP since Medicine has more daily actions. Calibrate
  so all three modules contribute roughly equally over a typical week.
- **Retroactivity:** XP starts from zero at feature launch. Historical
  data is NOT backfilled — this avoids a jarring "you're already level
  47" moment and keeps the system feel fresh.
- **Negative XP:** not supported. Missed days simply don't earn XP
  (zero, not negative). This keeps the system encouraging, not punitive.
- **Overflow:** `total_xp` is a 64-bit integer — no practical overflow
  risk.

## Cross-references

- Achievements engine event stream: `lib/core/achievements/achievement_engine.dart`
  (`AchievementEvent` broadcast stream).
- Dashboard display: `lib/features/dashboard/presentation/`.
- Related: Spec 06-gamification/08 (point shop) and Spec 06-gamification/09
  (boss challenge) both consume XP as currency.

## Test strategy

- Unit test: XP accumulation from mock events.
- Unit test: level curve formula (boundary values, level transitions).
- Unit test: XP normalization across modules.
- Widget test: dashboard level/XP display.

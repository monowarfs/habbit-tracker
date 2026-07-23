# Adaptive Quest Difficulty (Gamification Tie-In)

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
The achievements engine added in Run 15 evaluates fixed achievement
definitions per module (streak milestones, adherence thresholds, etc.),
which works well for one-time badges but doesn't yet cover recurring
weekly quests that scale to a user's own pace. A fixed weekly target is
either trivially easy for a consistent user (no motivational value) or
discouraging for someone still building the habit (feels punitive rather
than encouraging). Habitica's difficulty-scaling pattern — quests that
track your own recent baseline rather than an arbitrary fixed number —
is the direct inspiration, and ties naturally into gamification as a
retention lever this app doesn't yet have.

## Goals
- Introduce weekly quests whose target scales to each user's own recent
  rolling-average pace per module, rather than a fixed number for
  everyone.
- Let a quest feel achievable-but-not-trivial regardless of whether a
  user is just starting out or already highly consistent.
- Plug into the achievements engine's existing evaluation model (each
  module's own write path triggers evaluation, not a periodic sweep) so
  quest completion detection follows the same pattern as existing
  achievements.

## Non-goals / out of scope
- No difficulty model beyond a simple rolling-average-based target
  calculation — no machine learning, no per-user profiling beyond their
  own recent activity counts.
- Not a full RPG-style gamification layer (avatars, currencies, pets) —
  scoped strictly to the quest-difficulty-scaling mechanic itself.
- Does not change how the existing fixed achievement definitions
  (streaks, adherence badges) work — this is a new, separate quest type
  alongside them, not a replacement.

## Proposed approach (high-level)
Pure local arithmetic on top of the existing achievements engine and
each module's own log/completion history: for a given module, compute a
rolling average of recent activity (e.g. average Water logs per week
over the last several weeks, or Medicine adherence rate), and generate a
weekly quest target modestly above that baseline (a small percentage
stretch, not a fixed jump) so it's calibrated to that specific user.
Quest definitions become a new category alongside each module's existing
`achievementDefinitions`, evaluated the same way — from each module's own
write path when a qualifying action happens, not a periodic background
sweep — reusing the achievements repository's existing read/write access
to the `achievements` table (or a small sibling table for
quest-specific state, e.g. current week's target and progress, if the
existing schema doesn't naturally fit weekly-rolling quests).

## Dependencies & prerequisites
- The existing achievements engine and repository (Run 15).
- Each module's log/completion history as the input to the rolling
  average.
- A design decision on how quests are surfaced in the UI (a dedicated
  quests section vs. folded into the existing achievements/dashboard
  surfaces).

## Open questions for the implementation round
- Does quest state need its own table, or can it be modeled as a
  specialized row/type within the existing `achievements` schema?
- What stretch percentage above baseline feels motivating without
  feeling arbitrary or unfair — likely needs some manual tuning/testing
  rather than a single obviously-correct formula.
- How does a quest handle a user whose baseline is zero (never done the
  habit) — some minimum floor target is presumably needed.
- Do quests reset every week regardless of completion, or roll over
  partial progress?

## Effort & sequencing notes
Complexity M — leans heavily on infrastructure that already exists
(achievements engine, per-module history), so the net-new work is mostly
the rolling-average calculation and the quest-specific UI surface, not a
new subsystem. Reasonable to sequence after core achievements work has
had time to stabilize, since quests are additive to that system.

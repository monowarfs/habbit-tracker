# Weekly Quest Chains

**Category:** Gamification · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Today the app's only forward-looking goal structures are open-ended
streaks and one-off achievement badges. Habitica's weekly quests show that
a bounded, scoped objective ("hit your water goal 5 of 7 days this week")
gives users a different kind of target than an indefinite streak — one
with a clear finish line and its own reward, refreshing every week rather
than accumulating pressure indefinitely. This suits users who've broken a
long streak and feel there's nothing left to aim for until they rebuild it
from scratch; a weekly quest resets the clock far sooner.

## Goals

- Define a small set of recurring weekly objectives per module (e.g.
  "5/7 days," "no missed doses this week," "all five prayers 4/7 days").
- Track progress against the current week's quest(s) and reward completion
  distinctly from streaks/achievements.
- Refresh quests automatically at the start of each week with no user setup
  required.

## Non-goals / out of scope

- User-authored custom quests — a fixed, curated set per module for v1.
- Quest difficulty scaling/personalization based on the user's history
  (static thresholds for v1).
- Cross-module combined quests (that overlaps with the same-day combo
  bonus feature, tracked separately).

## Proposed approach (high-level)

Each module already exposes its own achievement definitions to the
achievements engine; weekly quests are a natural sibling extension of that
same per-module definitions list, distinguished by a weekly reset window
rather than a one-time unlock. The engine (or a close extension of it)
would evaluate quest progress from each module's existing completion data
on the same write-path-triggered basis it already uses for achievements,
rather than a new periodic sweep. A dashboard or achievements-gallery
surface would show the current week's quest(s) and progress toward them,
resetting visibly at each week boundary.

## Dependencies & prerequisites

- Each module's achievement_definitions extension point (the same
  mechanism modules already use to declare achievements).
- The achievements engine's event-driven evaluation approach, extended to
  understand a recurring/resettable objective in addition to one-time
  unlocks.
- A UI surface for "this week's quest" separate from the permanent badge
  gallery.

## Open questions for the implementation round

- Does a missed quest carry any penalty, or does it simply expire quietly
  and a new one begins?
- Are quests the same every week (fixed rotation) or randomly selected
  from a pool per module?
- What reward do they grant — XP (if that system exists by then), a
  distinct quest-badge, or something else?
- Should a quest ever span multiple modules, or is that explicitly
  reserved for the combo-bonus feature to avoid overlap?
- How is "week" defined relative to the app's existing DST-safe day-
  bucketing (`localDayKey`) — does a week boundary need the same care?

## Effort & sequencing notes

Medium — reuses the achievements engine's evaluation pattern but needs a
new "resets weekly" concept the current one-time-unlock model doesn't
have. No hard dependency on the XP system, though pairing the reward with
XP (once it exists) would be a natural follow-up rather than a
prerequisite.

## Database schema

New `weekly_quests` table:

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | UUID v7 |
| quest_key | TEXT | e.g. `'water_goal_5_of_7'` |
| module_id | TEXT | which module this quest belongs to |
| week_key | TEXT | `'YYYY-Www'` ISO week format |
| progress_current | INTEGER | current progress toward target |
| progress_target | INTEGER | goal (e.g. 5) |
| completed_at | INTEGER NULL | UTC; null = not yet completed |
| reward_claimed | INTEGER (bool) | whether XP/reward has been claimed |
| created_at, updated_at | INTEGER | |

Week boundaries use ISO 8601 week numbering (Monday start). The
`week_key` is computed from `localDayKey()` to maintain DST safety.

## Localization

New ARB keys (en/bn):
- `weeklyQuestTitle` — "This Week's Quests" section header.
- `weeklyQuestProgress` — "{current}/{target} days" progress label.
- `weeklyQuestComplete` — "Quest complete! Claim your reward."
- `weeklyQuestReset` — "New quests available every Monday."
- Per-quest description keys (e.g. `questWater5of7`).

## Edge cases & error handling

- **Week boundary DST:** ISO 8601 weeks are timezone-agnostic (Monday
  00:00 UTC). Use `localDayKey()` to determine the user's local
  Monday, then convert to UTC for the `week_key`.
- **Quest completion timing:** if the user completes the last required
  action on Sunday at 23:59, the quest is marked complete. If they
  complete it on Monday after midnight, it counts toward the new week.
- **Missed week:** if the user doesn't open the app all week, the quests
  simply expire — no penalty, no carryover.
- **Multiple modules:** each module gets 1-2 quests per week. Cross-module
  quests (e.g. "complete all modules 3 days") are deferred to Spec
  06-gamification/06 (combo bonus).

## Cross-references

- Achievements engine: `lib/core/achievements/achievement_engine.dart`.
- Related: Spec 06-gamification/02 (XP) — quests award XP.
- Related: Spec 06-gamification/09 (boss challenge) — harder variant.
- Related: Spec 06-gamification/06 (combo bonus) — cross-module variant.

## Test strategy

- Unit test: quest generation for each module.
- Unit test: week boundary computation (DST edge cases).
- Unit test: progress tracking and completion detection.
- Widget test: quest list UI with progress bars.

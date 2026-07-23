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

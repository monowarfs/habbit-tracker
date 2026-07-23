# Household Leaderboard (Post Multi-Profile)

**Category:** Gamification · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Habitica's party mechanic shows that friendly comparison against people
you actually know is a distinct motivator from solo streaks and badges —
but this app has no concept of other users at all today, only a single
local profile. Once multi-profile support ships (tracked as a Premium-
category feature), the same device could hold several household members'
data (e.g. a family sharing one phone/tablet), and a lightweight same-
device leaderboard turns that into a playful, low-stakes ranking rather
than pure isolated tracking — as much a play mechanic as a community one,
which is why it's listed here alongside the other gamification features
even though it is entirely gated on Premium's multi-profile work landing
first.

## Goals

- Rank household members (multiple local profiles on the same device) by
  a simple, understandable metric (e.g. current streaks, weekly
  completion rate, or level if the XP system exists).
- Keep the comparison friendly and low-stakes, appropriate for family
  members of varying ages/health needs rather than a competitive scoreboard.
- Make the leaderboard purely local/offline, consistent with the app's
  no-account design — no server-side ranking or data leaving the device.

## Non-goals / out of scope

- Any leaderboard across devices/households — strictly same-device,
  multi-profile only, since the app has no accounts or networking.
- Forcing comparison — this should be an opt-in view, not a default
  surface every profile is pushed toward.
- Any reward or penalty tied to rank — purely informational/social framing.

## Proposed approach (high-level)

This feature is entirely downstream of multi-profile support, which does
not exist yet. Once each local profile has its own independently-tracked
data (streaks, achievements, and possibly XP/level), a household
leaderboard is a read-only aggregation screen that queries each profile's
existing stats and ranks them by a chosen metric, reusing whatever
streak/report calculators and (if it exists by then) the XP/level system
already compute per profile. No new tracking is needed — only a
cross-profile read and a ranked display, most naturally reached from
wherever multi-profile switching lives in the app.

## Dependencies & prerequisites

- Multi-profile support itself (hard prerequisite — this feature has no
  meaning without multiple profiles existing on one device).
- Existing streak/report calculators per module, as the ranking data
  source.
- The cross-module XP/level system, if level is chosen as the ranking
  metric rather than raw streak length.

## Open questions for the implementation round

- What's the ranking metric — current longest streak, a weekly completion
  percentage, or XP/level — and does the user get to choose?
- Does the leaderboard update live as household members use the app, or
  is it a manually-refreshed/opened view?
- Are there privacy considerations within a household (e.g. a teenager's
  Medicine adherence being visible to a parent) that need a per-profile
  opt-out from appearing on the leaderboard?
- Does this belong in the Premium tier alongside multi-profile itself, or
  is it a free feature that simply requires Premium's multi-profile to
  exist?

## Effort & sequencing notes

Medium, but effectively unlockable only after multi-profile ships —
almost all the real cost lives in that prerequisite, not in this feature's
own read-only aggregation logic. Do not schedule this before multi-profile
support is planned and scoped.

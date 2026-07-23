# Same-Day Multi-Module Combo Bonus

**Category:** Gamification · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

The dashboard's whole premise is showing the user's status across Water,
Medicine, and Prayer together, but nothing currently rewards actually
completing all three on the same day beyond the day-completion indicator
simply turning "complete." Habitica's dailies give a small combo bonus for
clearing everything in a day, which reinforces exactly the cross-module
behavior this app's dashboard is designed to encourage. A modest same-day
combo bonus turns the dashboard's aggregate view from a passive status
display into an active incentive to close out every module, not just the
user's favorite one.

## Goals

- Detect when all of a user's active modules are completed for the same
  day and grant a small, distinct bonus (visual celebration and/or XP if
  that system exists).
- Make the combo feel like a bonus on top of individual module completion,
  not a replacement for module-level rewards.
- Work correctly for users who have not enabled all three modules (a combo
  should only require the modules the user actually uses).

## Non-goals / out of scope

- A separate combo streak (e.g. "N days of combos in a row") — that's a
  bigger feature than this one; v1 is a single-day bonus only.
- Partial-credit combos (e.g. 2 of 3 modules) — the combo is all-or-nothing
  for the day, matching Habitica's own framing.
- Retroactive combo detection for past days before this feature ships.

## Proposed approach (high-level)

The dashboard's day-completion indicator already determines, per module,
whether that module counts as complete for a given day, and aggregates
that into the overall day status. A combo bonus is a thin rule layered on
top of that same aggregate: when every active module's completion flag is
true for the day, fire a one-time combo event for that day. This event can
plug into the achievements engine's existing event-driven evaluation (or
the XP system's event stream, if that exists) rather than introducing a
separate detection mechanism — it is a derived condition on data the
dashboard already computes.

## Dependencies & prerequisites

- The dashboard's day-completion indicator and its per-module aggregation
  logic.
- Some reward mechanism to grant (XP system, if sequenced first, or a
  simple standalone celebratory acknowledgment if not).

## Open questions for the implementation round

- Does the combo require the day to be fully "closed" (e.g. end of day) or
  does it fire the moment the last module reaches completion, whichever
  happens first?
- What is the actual reward if the XP system doesn't exist yet — a purely
  visual celebration, or is this feature blocked until XP ships?
- Should combo completions count toward a distinct achievement (e.g. "10
  combo days") for extra motivation, or stay a same-day-only bonus?
- How does a user who only uses one module (e.g. just Water) experience
  this — does the combo bonus even apply, or is it hidden for single-
  module users?

## Effort & sequencing notes

Small — the completion data already exists; this is a rule and a reward
hookup, not new tracking infrastructure. Works best once the XP system
exists to give the bonus a tangible reward, but the detection logic itself
has no hard technical dependency on it.

# Smart Qadha Payoff Pace Planner

**Category:** AI-Powered · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Prayer's Qadha screen today shows a raw counter of missed prayers owed as
make-up, with a −1 control to record progress. A raw, possibly large
counter with no sense of trajectory is a classic guilt-without-a-path
problem: it tells the user how far behind they are but nothing about how
long it would realistically take to catch up, which can make the number
feel permanent and discouraging rather than actionable. This is a
novel, Islamic-app-specific feature with no direct competitor precedent
in the atlas — turning a static debt counter into a pace-based plan is a
small computation with an outsized effect on how the feature feels to use.

## Goals
- Given the current Qadha counter and the user's own recent make-up pace
  (prayers cleared per week, observed from their own history), project a
  rough "clear by" date or duration ("at this pace, ~6 months").
- Present this as an encouraging, non-judgmental framing — a plan, not
  another guilt signal.
- Update the projection naturally as the counter and pace change over
  time, with no separate configuration step required from the user.

## Non-goals / out of scope
- No prescriptive goal-setting or forced pace targets — the user isn't
  told they must clear N per week, only shown what their own actual pace
  implies.
- No religious/scholarly guidance on Qadha obligations themselves — this
  is purely a pacing calculation on top of the existing counter mechanic,
  not a feature that interprets fiqh.
- No model or external data — a simple rate calculation over local
  history.

## Proposed approach (high-level)
Pure arithmetic over the existing `prayer_qadha_counters` table and the
user's own make-up log history: compute a recent rate (make-ups recorded
per week over, say, the last several weeks), and if the rate is
non-zero, divide the current outstanding counter by that rate to get a
projected number of weeks/months to clear it. If the user has never
recorded a make-up yet, there's no pace to project from, so the feature
simply doesn't show a projection until there's at least a little history
to compute one from — this is a strictly additive, read-only annotation
on the existing Qadha screen, not a change to how the counter itself is
recorded or decremented.

## Dependencies & prerequisites
- Existing `prayer_qadha_counters` table and its make-up recording flow.
- A little make-up history before the projection can compute anything
  meaningful (first-use empty state needs its own simple copy, e.g. "log
  a few make-ups to see your pace").

## Open questions for the implementation round
- What window of history defines "recent pace" — last 4 weeks, last 8,
  all-time average? Recent-weighted seems right for encouragement but
  needs a concrete window chosen.
- How does the projection handle a pace of zero or near-zero (user logged
  Qadha counters but hasn't made any up in a while) without feeling like a
  scolding message?
- Does this projection appear only on the Qadha screen, or also as a
  small note elsewhere (e.g. Prayer's stats screen)?
- Should there be a lightweight, optional "target pace" the user can set
  for themselves, distinct from the passive observed-pace projection, or
  is that scope creep for this pass?

## Effort & sequencing notes
Complexity S — a small, self-contained arithmetic feature on top of a
table and screen that already exist. Effort is almost entirely in getting
the tone/copy right for an encouraging rather than guilt-inducing framing,
not the calculation. Independent of the other items in this category and
safe to sequence any time.

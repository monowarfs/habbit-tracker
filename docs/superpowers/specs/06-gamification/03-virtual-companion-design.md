# Virtual Companion Tied to Day-Completion

**Category:** Gamification · **Atlas complexity:** L · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Finch's signature mechanic — a small creature that visibly thrives or
droops based on the user's daily behavior — turns an abstract "did I
complete my day" signal into something emotionally legible at a glance, and
is one of the strongest documented retention mechanics among habit apps.
This app's dashboard already computes a day-completion state; a companion
that reacts to that same state gives users a reason to check in even on
days they don't have anything scheduled, purely to see how their companion
is doing, which is a different and complementary hook from streak-driven
return visits.

## Goals

- Give users a visual companion (creature, plant, or similar) whose mood/
  state visibly reflects recent day-completion history.
- Make the companion's state legible without requiring the user to read
  numbers — a glance should convey "things are going well" or "needs
  attention."
- Keep the companion emotionally warm but not guilt-inducing on a bad day.

## Non-goals / out of scope

- Deep simulation mechanics (feeding, multiple needs, mini-games) — this is
  a mood mirror on existing data, not a standalone virtual-pet game.
- Monetization of companion cosmetics in v1 (a future point-shop/premium
  tie-in is plausible later, not scoped here).
- Multiple simultaneous companions or per-module companions — one
  companion reflecting overall status, consistent with the cross-module
  framing the dashboard already uses.

## Proposed approach (high-level)

The dashboard's existing day-completion indicator already computes, per
day, whether the user's scheduled habits were completed. A companion state
machine can be derived from a short rolling window of that same data (e.g.
recent days' completion ratio) rather than inventing a new tracking
concept — thriving on a good recent run, drooping after several
incomplete days, neutral otherwise. The companion would likely live as a
small animated element on the dashboard, with a handful of discrete visual
states (not continuous animation) driven by that derived mood value. This
is the one feature in this batch that also requires new art/animation
assets, which is the dominant cost driver relative to its logic.

## Dependencies & prerequisites

- The dashboard's day-completion indicator and the underlying streak/report
  aggregation logic it's built on, as the mood-state input.
- A new art/animation asset pipeline (illustrations or a small sprite/
  animation set for each mood state) — this is new production work, not
  reuse of anything existing.
- A decision on how many mood states are worth illustrating for v1.

## Open questions for the implementation round

- How many discrete mood states justify the art investment (e.g. 3-5)
  versus how finely completion data could theoretically be sliced?
- Does the companion look the same for every user, or is there any
  customization (ties into avatar customization, a separate feature)?
- Should the companion have a name/identity the user sets, or stay generic?
- Static illustrations vs. lightweight animation — what does the existing
  app's asset/build setup make cheapest?
- Does a very bad stretch (companion visibly unwell) need a design review
  to ensure it reads as encouraging rather than shaming, given the
  health-adjacent audience?

## Effort & sequencing notes

Large — the logic reuses already-computed data cheaply, but the new art/
animation pipeline is real production work outside the codebase itself.
Reasonable to sequence after the XP system (companion mood could
eventually factor in XP trends) but does not strictly require it; the
dashboard's day-completion indicator alone is sufficient input for v1.

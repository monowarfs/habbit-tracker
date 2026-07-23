# Smart Default Goal Suggestion

**Category:** AI-Powered · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Water's onboarding today presumably starts a new user with a bare
default daily goal number, which is either arbitrary or requires the
user to already know a reasonable target for themselves. Generic
hydration-app formulas (weight/age/climate-based estimates) are
well-established and give a much better starting point than a flat
default, reducing the chance a new user's very first experience with
Water is a goal that's obviously wrong for them (too easy or
discouragingly high). This is a small, static-formula feature — no
model, no learning, just a better-informed default at the moment a
`WaterGoal` is first created.

## Goals
- At onboarding (or first Water setup), ask for a small number of simple
  inputs (e.g. age, weight, general climate) and compute a suggested
  starting daily water goal from a standard hydration formula.
- Present the suggestion as an editable default, not a locked value —
  the user can always adjust it immediately or later through the
  existing goal-setting flow.
- Keep the formula and its inputs simple enough to ask for in a single
  onboarding step without feeling like a medical intake form.

## Non-goals / out of scope
- No personalized/adaptive model — a fixed, well-known formula
  (e.g. weight-based ml/kg with a climate adjustment factor), not
  anything that learns or updates from usage over time.
- Not a replacement for the existing goal-editing flow — this only
  affects the initial suggested value at first setup.
- No health-conditions-aware tailoring (e.g. medical conditions
  affecting fluid intake) — scoped to the same general-population
  formula generic hydration apps already use, with the same caveats
  those apps carry (not medical advice).

## Proposed approach (high-level)
A static, well-established hydration formula (no model, purely arithmetic
— e.g. a baseline ml/kg-of-bodyweight figure with a fixed adjustment for a
selected climate/activity bucket) computes a suggested daily total from a
few onboarding inputs. That suggested number simply becomes the initial
value pre-filled into the existing `WaterGoal` entity/goal-setting form
at first setup — no new entity or storage mechanism needed, since a
`WaterGoal` already exists and already supports being edited later
through Water's existing goal-history flow. The onboarding step itself
(where age/weight/climate inputs are collected) is the only genuinely new
surface; everything downstream of "here's a suggested number" reuses
existing goal-setting and goal-history machinery unchanged.

## Dependencies & prerequisites
- An onboarding flow/step to collect the small set of inputs (age,
  weight, climate) — if onboarding doesn't yet have a dedicated
  multi-step flow, this may be the first feature to introduce one, or it
  could be folded into Water's existing first-time setup if one exists.
- The existing `WaterGoal` entity and goal-setting form as the
  integration point — no schema changes anticipated.
- Clear copy noting this is a general estimate, not medical guidance,
  given it touches age/weight inputs.

## Open questions for the implementation round
- Which specific formula/constants to use, and does it need unit
  conversion given the existing `WaterUnit` settings enum (ml vs. other
  units already supported)?
- Are age/weight/climate all necessary, or does a simpler two-input
  version (e.g. weight + climate only) capture most of the value with
  less onboarding friction?
- Does this run only at first-ever Water setup, or is it also offered
  later as a "recalculate my suggested goal" option in Settings for an
  existing user whose weight/climate has changed?
- Should the climate input be a manual picker, or could it default from
  the device's locale/region as a starting guess the user can override?

## Effort & sequencing notes
Complexity S — the formula itself is trivial; the only real work is the
onboarding UI for collecting the few inputs, and deciding whether that
onboarding step already exists or needs to be introduced. Retention
impact is Low since it's a one-time first-impression improvement rather
than an ongoing engagement driver, so it's reasonable to sequence
whenever onboarding work is otherwise being touched rather than as a
standalone push.

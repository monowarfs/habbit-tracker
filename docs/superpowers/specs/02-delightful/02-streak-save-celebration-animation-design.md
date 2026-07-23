# Streak-Save Celebration Animation

**Category:** Delightful · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Habitica and Duolingo both lean hard on a moment of visual celebration when
a user hits a streak milestone — it's a cheap dopamine hit that meaningfully
boosts return-next-day rates. Run 15 already gave this app an achievement
engine and established a house style for celebration (badge unlocks show a
snackbar, deliberately not a modal, per the exit criteria in
`docs/product/roadmap.md`). Right now a streak milestone (7-day, 30-day,
etc.) likely triggers the same understated snackbar as any other
achievement, which under-sells a genuinely special moment without going as
far as an intrusive full-screen takeover the app has explicitly chosen not
to do elsewhere.

## Goals

- Give streak milestones (not just badge unlocks generally) a distinct,
  brief celebratory animation — something more than a snackbar, less than
  a blocking modal.
- Make it fully skippable/dismissible with a single tap or automatically
  after a short duration.
- Keep it consistent with the existing achievement engine's trigger
  points so it doesn't need its own parallel detection logic.
- Respect the app's low-key, non-nagging tone — celebratory, not loud.

## Non-goals / out of scope

- No sound by itself (that's a separate optional feature, see item 10).
- No changes to what counts as a streak or how streaks are calculated —
  this is purely the presentation layer on an existing event.
- No new achievement types or thresholds — reuses whatever milestones the
  achievement engine already defines.
- No per-module custom animation variants in v1 of this feature (a single
  shared animation, possibly recolored per module accent, is enough to
  start).

## Proposed approach (high-level)

The achievement engine already evaluates and fires from each module's own
write path (not a periodic sweep), so the natural hook is the same trigger
point that currently produces a snackbar — this feature adds a richer
presentation for a specific subset of achievements (streak milestones)
rather than introducing a new detection mechanism. A short, lightweight
animation (confetti burst, a growing streak-flame icon, or similar) plays
over the current screen for roughly one to two seconds, auto-dismisses,
and can be tapped away early. It should be able to use the module's own
accent color (already defined via the theme extension) so a Water streak
feels different from a Prayer streak without needing bespoke art per
module. Because it's non-blocking and brief, it fits the same "don't
interrupt the user's flow" philosophy the snackbar-not-modal precedent
established.

## Dependencies & prerequisites

- The achievement engine's existing trigger points (module write paths
  that already fire achievement evaluation).
- A distinction, in whatever data the achievement engine emits, between
  "streak milestone" achievements and other achievement types, so this
  feature can target only the former.
- The per-module accent color theme extension, if color-coding the
  animation.
- An animation approach that's cheap on lower-end devices (Nusrat's
  persona is on a budget Android phone) — nothing GPU-heavy.

## Open questions for the implementation round

- Confetti/particle animation vs. a simpler icon-scale/glow effect —
  which is cheap enough on budget hardware while still feeling special?
- Does this need a new Flutter animation package, or can existing Flutter
  animation primitives (already available, no new dependency) cover it?
- Should the animation be suppressible entirely via a settings toggle for
  users who find any extra motion distracting (accessibility angle)?
- Does every streak milestone (7, 14, 30, 100 days...) get the same
  animation, or does intensity scale with the milestone size?

## Effort & sequencing notes

Complexity S — almost entirely presentation-layer work riding on an
existing trigger system. No blocking dependency on other atlas items;
could ship independently and early since it reuses infrastructure that
already exists (Run 15's achievement engine), unlike most of the other
items in this category.

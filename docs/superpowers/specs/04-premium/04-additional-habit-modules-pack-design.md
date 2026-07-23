# Additional Habit Modules Pack (Sleep, Blood Pressure, Mood, Exercise)

**Category:** Premium · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
This is roadmap.md's #5 v1.1+ candidate. `future-expansion.md` has already
proven, on paper, that the `HabitModule` contract cleanly supports both a
checklist/scheduled habit (Sleep, worked through as a paper example) and a
free-log/measurement habit with a new domain concern (Blood Pressure,
also worked through). That means adding modules beyond the free core
three is now a comparatively cheap, well-understood exercise rather than
a research problem — which is exactly what makes bundling several of
them into a paid pack an efficient way to widen the app's health-tracking
breadth (closer to Apple Health's) without inflating the always-free core.

## What stays free vs. what's paywalled
The three existing modules — Water, Medicine, Prayer — stay free forever,
along with any future module the team later decides belongs in the free
core. What's paywalled here is a specific *additional pack* of modules
(Sleep, Blood Pressure, Mood, Exercise are the four named candidates)
bundled together as a premium unlock — not a per-module micro-purchase,
and not a cap that makes any of today's three modules feel incomplete.

## Goals
- Ship Sleep, Blood Pressure, Mood, and Exercise as additional
  `HabitModule` implementations, reusing the recipe future-expansion.md
  already documents step by step.
- Gate the pack behind a single premium unlock, not per-module purchases
  — keep the purchase decision simple.
- Prove the `HabitModule` contract holds for a fourth, fifth, sixth, and
  seventh module with zero changes required to the contract itself or to
  Water/Medicine/Prayer's own code.

## Non-goals / out of scope
- Not designing each module's full domain/data/presentation slice in this
  pass — future-expansion.md's Sleep and Blood Pressure paper examples
  are a strong head start, but Mood and Exercise still need their own
  domain sketches at implementation time.
- Not deciding per-module pricing or a la carte unlocks — scoped here as
  one bundled pack.
- Not building cross-module correlation features (e.g. "sleep affects
  mood") — each module stays independent per the existing architecture.

## Proposed approach (high-level)
Follow future-expansion.md's recipe once per module: a
`lib/features/<name>/` slice with the standard domain/data/presentation
shape, new Drift tables added to the central table manifest, a
`<name>_module.dart` implementing `HabitModule`, registration in the
module registry, and bilingual ARB keys from day one. Sleep and Blood
Pressure already have worked-through paper designs to start from (Sleep
as checklist/scheduled reusing Medicine/Prayer's shared Done/Snooze/Skip
notification component; Blood Pressure as free-log with its own
classification use case, no materialization, no natural streak). Mood
and Exercise would need equivalent shape decisions (Mood likely
free-log/checklist-hybrid; Exercise likely free-log like Water/Blood
Pressure). The premium gate itself is a purchase-state check controlling
whether these four modules' entries even appear in the module registry
or dashboard/settings — not a change to how any module works internally.

## Dependencies & prerequisites
- The `HabitModule` contract as it exists today, already proven against
  two of these four modules on paper.
- IAP/purchase-state plumbing shared with other premium features (whoever
  builds the first premium gate, likely icon packs or lifetime pricing,
  establishes this).
- A decision on where premium-gating logic lives relative to
  `module_registry.dart` — likely the cleanest single checkpoint, since
  that's already the single shared touchpoint for "which modules exist."

## Open questions for the implementation round
- Does the premium gate hide these modules entirely from a non-premium
  user, or show them as a locked/preview state (better discoverability,
  more purchase-intent surface)?
- Are Mood and Exercise's domain shapes settled before implementation
  starts, or does this round need its own mini design pass for those two
  (Sleep/Blood Pressure already have one)?
- Does purchasing the pack unlock all four modules simultaneously, or can
  the pack grow over time (a 5th module added later to the same
  purchase)?
- How do achievements/reports treat pack modules — do they count toward
  cross-module reports and the achievement gallery on the same terms as
  the free three?

## Effort & sequencing notes
M complexity per future-expansion.md's own framing — "each is cheap to
build" given the proven recipe — though bundling four modules multiplies
that cost roughly four-fold even if each is individually cheap. Sequenced
last among the roadmap's top candidates since there's no urgency to add a
fourth module before the core three are proven with real users.

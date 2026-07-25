# Achievement "Almost There" Progress Bars

**Category:** Gamification · **Atlas complexity:** S · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

The current badge gallery only reveals an achievement's meaning once it's
already unlocked, giving the user no sense of how close they are to the
next one. Xbox and Steam's achievement systems prove the opposite approach
— showing an unearned achievement at, say, 80% progress — is a proven
completionist pull precisely because it turns "someday" into "almost."
Since the achievements engine already has to compute progress toward each
achievement's criteria internally in order to know when to unlock it, this
is largely a matter of surfacing a number the system already knows,
rather than building new tracking.

## Goals

- Show unearned achievements in the gallery with a visible progress
  indicator toward their unlock criteria, not just a locked/greyed icon.
- Make the "closest" unearned achievements easy to spot (e.g. sorted or
  highlighted) so users see what's genuinely within reach.
- Keep the criteria description honest — a progress bar should reflect
  real progress, not a vague estimate.

## Non-goals / out of scope

- Progress bars for achievements whose criteria are inherently binary and
  have no meaningful partial state (these simply stay locked/unlocked).
- Hints or spoilers about hidden/surprise achievements, if any exist or
  are added later — this feature is for achievements whose criteria are
  already visible to the user.
- Any change to how/when an achievement actually unlocks — purely a
  richer display of existing progress.

## Proposed approach (high-level)

The achievements engine already evaluates each achievement's criteria
against live data from each module's write path in order to decide when to
unlock it — which means a "how close" figure is usually a natural
byproduct of that same evaluation, not a new computation. The badge
gallery screen is extended to render a progress bar (or percentage) on
each unearned achievement card, sourced from that existing evaluation
logic, alongside the existing locked-badge treatment. Achievements whose
criteria don't reduce to a clean percentage (e.g. compound or one-off
conditions) can simply omit the bar and stay as they are today.

## Dependencies & prerequisites

- The achievements engine and the achievements table's existing criteria/
  progress evaluation.
- The badge gallery UI, for the new progress-bar rendering on unearned
  badges.

## Open questions for the implementation round

- Do all existing achievement definitions across the three modules
  already expose a "current progress vs. target" value, or does each
  definition need to be revisited to add one?
- Should the gallery default-sort by proximity to unlocking, or keep its
  current ordering with progress as an added detail rather than a resort?
- Does showing exact progress ever spoil a "surprise" achievement's
  criteria in a way that's undesirable (e.g. revealing an obscure
  condition before the user would otherwise discover it)?
- Should this pair with the badge rarity tiers feature so progress bars
  and rarity treatment render together on the same card redesign?

## Effort & sequencing notes

Small — this is primarily a gallery UI addition surfacing data the
achievements engine already computes internally for its own unlock
decisions. No dependency on other features in this batch, though it
naturally shares a gallery-card redesign with badge rarity tiers.

## Database schema

No new tables. The progress data comes from the existing `achievements`
table's `progress_current` and `progress_target` columns, plus the
`currentProgress` closure on each `AchievementDefinition`.

## Localization

New ARB keys (en/bn):
- `achievementProgress` — "{current}/{target}" progress label.
- `achievementAlmostThere` — "Almost there!" label for near-completion.
- `achievementProgressPercent` — "{percent}%" for screen readers.

## Edge cases & error handling

- **Binary achievements:** some achievements have no meaningful progress
  (e.g. "Log your first entry" — it's 0 or 1). Show the progress bar
  only when `target > 1`. For binary achievements, show nothing or a
  simple "Not yet / Unlocked" indicator.
- **Progress accuracy:** the `currentProgress` closure is called on
  every gallery render. Cache the result for 60 seconds to avoid
  repeated DB queries during scrolling.
- **Sorting:** default-sort unearned achievements by proximity to
  unlocking (closest first). Earned achievements stay in their
  original order at the bottom.

## Cross-references

- Achievements engine: `lib/core/achievements/achievement_engine.dart`.
- Achievement definitions: `lib/core/achievements/achievement_definitions.dart`.
- Badge gallery: `lib/features/achievements/presentation/`.
- Related: Spec 06-gamification/05 (rarity) — same gallery card.

## Test strategy

- Unit test: progress calculation from achievement definitions.
- Widget test: progress bar rendering for various progress values.
- Widget test: binary achievement shows no progress bar.
- Widget test: sorting by proximity to unlocking.

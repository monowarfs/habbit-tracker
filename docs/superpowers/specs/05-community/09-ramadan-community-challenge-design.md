# Ramadan Community Challenge (Opt-In)

**Category:** Community · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Ramadan is a natural seasonal moment for shared observance — fasting, extra prayers, communal habit reinforcement — and Ramadan-specific apps lean hard into this with time-boxed group challenges. Prayer and, to a lesser extent, Water and Medicine are all relevant during Ramadan (adjusted schedules, fasting-aware water goals). This feature pairs naturally with a "Ramadan mode" (tracked separately in the Delightful category) but its actual group mechanic — people sharing progress toward a seasonal goal together — is a Community feature, and it inherits the exact same infrastructure problem as item 06: it needs some form of group/sharing mechanic to mean anything beyond a solo checklist.

## Infrastructure implication
Depends entirely on item 06 (Cloud Accountability Groups) existing first. Without any group mechanic, a "Ramadan community challenge" degrades to a solo seasonal checklist with no actual community component — which may still have standalone value (see Non-goals), but is a different, much smaller feature than what's being described here. This spec assumes the accountability-groups infrastructure decision (accounts + backend, per item 06) has already been made and built; it does not re-litigate that decision.

## Goals (once item 06 exists)
- Let users opt into a time-boxed, seasonal shared challenge scoped to Ramadan (e.g. a shared fasting-and-prayer completion goal visible to an accountability group).
- Tie into a "Ramadan mode" if/when that Delightful-category feature exists, so schedule adjustments (Suhoor/Iftar-aware water goals, Taraweeh prayer tracking) and the challenge mechanic reinforce each other rather than being built as unrelated features.
- Make the challenge genuinely time-boxed — it should start and end with Ramadan, not linger as a permanent group fixture.

## Non-goals / out of scope
- Not building the underlying group/accountability mechanic here — that's entirely item 06's scope, a hard prerequisite, not re-planned in this document.
- Not building "Ramadan mode" itself (schedule adjustments, fasting-aware UI) — that's a separate Delightful-category feature this spec assumes exists or is being planned independently.
- No solo, non-social version of a "Ramadan checklist" is being specified here — if that's wanted without the group dependency, it should be scoped as a distinct, smaller Delightful-category feature, not this one.
- No monetary or physical prizes/rewards tied to challenge completion.

## Proposed approach (high-level)
Once item 06's accountability-group infrastructure exists, add a seasonal variant: a group (or a special Ramadan-flavored group type) with a defined start/end date matching the Ramadan calendar, tracking a coarse shared goal (e.g. days fasted/prayed-on-time within the group) using the same coarse-signal-only sharing principle item 06 establishes — never raw prayer times or personal details, just completion signals. If "Ramadan mode" exists by this point, the challenge's tracked goal should read from whatever day-status/streak data that mode already produces (via the existing `core/reports` day-status/streak calculators), rather than defining a separate parallel tracking mechanism.

## Dependencies & prerequisites
- Item 06 (Cloud Accountability Groups) — hard prerequisite; this feature cannot exist in any meaningful community form without it.
- "Ramadan mode" (Delightful category, separate spec) — soft prerequisite; the feature can technically exist without it (tracking generic day-completion) but is much stronger paired with it.
- Accurate Ramadan calendar dates, likely already needed by Ramadan mode and reusable here rather than computed twice.

## Open questions for the implementation round
- If item 06 never ships (given how large a decision it is), is there still a smaller, non-social "Ramadan checklist" worth specifying separately, or does this feature simply not exist without the group mechanic?
- Does the challenge need its own group type/UI distinct from a regular accountability group, or is it just a regular group with a preset start/end date and a Ramadan theme?
- How does the challenge interact with existing per-module streaks — does a missed fast/prayer during Ramadan affect the user's regular Prayer streak, the challenge's shared count, or both independently?

## Effort & sequencing notes
Medium (M) complexity for the challenge mechanic itself, but it cannot be scheduled ahead of item 06 — treat this as blocked, not merely "medium priority," until the accountability-groups account/backend decision is resolved one way or the other.

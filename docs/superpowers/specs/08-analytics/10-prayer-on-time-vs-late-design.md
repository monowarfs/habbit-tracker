# Prayer On-Time vs. Late-but-Completed Split

**Category:** Analytics · **Kind:** Personal analytics (on-device only) · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Prayer's stats screen already tracks an on-time percentage internally as
part of its adherence calculation, but "prayed" and "prayed on time" are
different, both-meaningful facts that today get blended into whatever
single completion figure is shown — a user who prays every single prayer,
just consistently late, looks statistically similar to one who's missing
prayers outright, when in practice those are very different situations a
user would want to know about and address differently. This is a
Prayer-specific, novel addition (no direct competitor precedent named),
made possible entirely by data the module already computes.

## Goals

- Surface on-time completion and late-but-completed as two distinct,
  clearly labeled figures, rather than one blended "completed" percentage.
- Make the split visible directly on Prayer's stats screen as its own
  stat block, not just an internal input to a combined number.
- Keep the existing overall completion percentage too — this is additive
  detail, not a replacement metric.

## Non-goals / out of scope

- Not changing prayer-status derivation itself — `effectivePrayerStatus`
  already distinguishes these states; this is a presentation change, not
  new domain logic.
- Not extending this same distinction to Water or Medicine — "on time vs.
  late" is meaningful specifically because prayer times are fixed windows
  with clear boundaries; Water has no equivalent timing concept, and
  Medicine's dose-timing nuance (grace windows) is arguably already its
  own separate concern.
- Not attempting to define new categories beyond on-time/late/missed —
  reusing whatever status set `effectivePrayerStatus` already defines.

## Proposed approach (high-level)

`effectivePrayerStatus` already derives per-prayer status in a way that
presumably distinguishes on-time completion from a late-but-still-
completed one (that's the basis for the on-time percentage the stats
screen already computes) — this feature is mostly about pulling that
existing distinction forward into its own explicit stat block rather than
letting it stay folded into a single blended completion number. The
Prayer stats screen already has an on-time %; this adds its natural
complement (a late-but-completed % and, implicitly, a missed %) displayed
together as a small breakdown, likely a simple three-segment split (on
time / late / missed) rather than a new chart type.

## Dependencies & prerequisites

- `effectivePrayerStatus`'s existing status derivation as the sole data
  source — need to confirm it already exposes enough granularity to
  distinguish "late but completed" from "on time" as separate states
  (rather than that distinction only existing implicitly inside the
  on-time-percentage calculation).
- Prayer's existing stats screen as the presentation surface.
- Prayer's Qadha/missed-prayer tracking, to make sure "missed" in this
  breakdown lines up consistently with however Qadha counters already
  define a missed prayer.

## Open questions for the implementation round

- Does `effectivePrayerStatus` need any change at all, or does the stats
  screen already have access to the on-time/late distinction and simply
  isn't displaying it as a separate figure yet?
- Should this be a single combined three-way split (on time/late/missed)
  or two separate stats (on-time % of completed, and completed % of
  total)?
- Does this belong per-prayer-name (e.g. "Fajr is your latest prayer") in
  addition to an overall split, or is an overall split sufficient for a
  first pass?

## Effort & sequencing notes

Atlas complexity: S. Likely a smaller lift than most items in this batch
if the underlying status distinction already exists in
`effectivePrayerStatus` and just needs surfacing — largely a Prayer stats
screen presentation change. Independent of every other item in this
batch; Prayer-specific so no cross-module coordination needed.

# Extended Stats Range / Multi-Year Trends

**Category:** Premium · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
The Reports module (Run 15) already covers week/month/year views and
longest-streak records — a genuinely generous free tier. Long-term users
(the kind most likely to stick with a habit tracker for years) eventually
want to see multi-year trend lines: "how has my Water streak changed
year over year," or "my Prayer on-time percentage across three years."
This is depth for power users, matching Apple Health's own approach of
keeping recent history free and unlocking longer trend views as a
premium depth feature, not an access restriction.

## What stays free vs. what's paywalled
The existing Reports module's week/month/year views and longest-streak
records stay free, covering a generous window (e.g. the trailing year)
for every user regardless of tier — nothing about today's Reports screen
changes or gets newly restricted. What's paywalled is viewing trend
lines and aggregates *beyond* that generous free window — genuinely
long-term, multi-year, all-time trend charts for users with enough
history to make them meaningful.

## Goals
- Let premium users select an "all-time" or custom multi-year range on
  the existing Reports screen's charts, beyond the free window.
- Reuse the Reports module's existing aggregation use cases unchanged —
  this is a date-range parameter extension, not new calculation logic.
- Make the free window generous enough (e.g. 1 year) that this never
  feels like an artificial cap on a fairly new user — it only matters
  once someone has genuinely multi-year history.

## Non-goals / out of scope
- Not building new chart types or new aggregation dimensions — the same
  charts, just over a longer date range.
- Not retroactively restricting anything the Reports module already
  shows today (week/month/year, longest-streak records) — those stay
  free regardless of how this feature is scoped.
- Not solving performance concerns for arbitrarily large date ranges in
  this pass — flagged as an open question below.

## Proposed approach (high-level)
Extend the Reports module's existing date-range selection (which already
supports week/month/year) with an additional "all-time"/custom-range
option, gated by a purchase check at the point the user selects a range
beyond the free window. The underlying aggregate calculations (day-
status-streaks, aggregate-report use case) should already be generic
over an arbitrary date range internally — this is primarily a UI-level
range-picker addition plus a paywall gate, not new domain logic, assuming
the Reports module's use cases don't hardcode their range handling to the
three current presets.

## Dependencies & prerequisites
- The Reports module's existing aggregate use cases and date-range
  handling — this is additive to that, not a rebuild.
- IAP/purchase-gating plumbing shared with other premium features.

## Open questions for the implementation round
- Do the Reports module's aggregate use cases already accept an arbitrary
  date range internally, or are they currently hardcoded to
  week/month/year presets — this determines whether the underlying logic
  needs any change at all versus purely a UI/gating addition.
- What exactly counts as "generous" for the free window — a fixed 1 year,
  or something tied to how long the user has had the app installed?
- Are there performance implications for aggregating multi-year data on
  lower-end devices (this app's persona set skews toward budget devices)
  that need caching or pre-aggregation consideration?
- Does this interact with item #5 (PDF/CSV export) — should exported
  reports also respect the same free/premium range split?

## Effort & sequencing notes
S complexity — assuming the Reports module's aggregation logic is
already range-generic, this is close to a pure UI + paywall-gating
change. Pairs naturally with item #5 (exportable reports) since both
extend the same Reports module's date-range handling.

# Predictive Stock-Out Date

**Category:** AI-Powered · **Atlas complexity:** S · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Medicine already has a one-shot low-stock crossing detector that fires
once stock drops below a threshold, but that's a reactive alert — it
tells the caregiver persona a problem exists right when it's already
close, not far enough ahead to act. The atlas explicitly calls out
"running out unexpectedly" as a stated failure mode for caregivers
managing someone else's medication, and a forward-looking projection
("At this pace, out of Amlodipine in ~5 days") turns a threshold alert
into a plannable heads-up, giving enough lead time to actually refill
before hitting zero.

## Goals
- Compute a projected stock-out date/day-count from recent consumption
  rate, derived entirely from existing stock ledger entries.
- Surface the projection somewhere a caregiver naturally looks (the
  medicine detail/stats screen, and optionally as an earlier, separate
  notification tier ahead of the existing low-stock crossing).
- Keep the existing one-shot low-stock crossing detector untouched —
  this is an additive, earlier-warning layer, not a replacement.

## Non-goals / out of scope
- No forecasting model, no seasonality/trend detection — a simple
  average-consumption-rate projection is the target, explicitly not a
  more sophisticated statistical model.
- Does not attempt to account for irregular real-world events (e.g. a
  dose being skipped due to travel) beyond what naturally falls out of
  using recent actual consumption rather than the nominal schedule.
- Not a refill-ordering or pharmacy-integration feature — purely an
  informational projection.

## Proposed approach (high-level)
The mechanism is arithmetic over MedicineModule's existing stock ledger:
take a recent window of stock-consuming events (dose-taken deductions),
compute an average consumption-per-day rate, and divide current
remaining stock by that rate to get a projected days-remaining and
calendar date. This sits naturally alongside the existing one-shot
low-stock crossing detector — that detector already watches the stock
ledger for a threshold crossing, so the projection can be computed at
the same read points (e.g. whenever `MedicineModule.pendingNotifications()`
already touches stock state, or whenever the stock ledger changes) without
introducing a new polling mechanism. The projected date is a derived,
non-persisted value recomputed on read, following the same "derive, don't
persist ephemeral status" pattern the module already uses for lazy dose
status (upcoming/due/missed are derived, not stored).

## Dependencies & prerequisites
- Existing stock ledger and MedicineModule's low-stock detector — no new
  tables needed if this stays a derived read-time calculation.
- A decision on whether the projection also drives an earlier notification
  tier (e.g. "2 weeks out" vs. today's single low-stock threshold) or
  stays purely a passive on-screen figure.

## Open questions for the implementation round
- What window of consumption history is used for the rate — all-time
  average, last-N-doses, last-N-days? Each has different sensitivity to
  a recent irregular stretch (e.g. a vacation where doses were skipped).
- Does a schedule change (dose frequency edited) reset or blend into the
  projection, given the rate is empirical rather than schedule-derived?
- Should the projection appear only when stock is already getting low, or
  always (so a caregiver builds trust in the number before it matters)?
- Is a new notification tier in scope for this pass, or is "show it on
  screen only" the right-sized first cut?

## Effort & sequencing notes
Complexity S — this is a small arithmetic addition riding on data and
detection logic that already exists; the bulk of the effort is UI
placement and deciding the notification-tier question above, not the
calculation itself. A good candidate for an early, low-risk win in this
category.

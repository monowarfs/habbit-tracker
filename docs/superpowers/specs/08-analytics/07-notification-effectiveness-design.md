# Notification-Effectiveness Self-Metric

**Category:** Analytics · **Kind:** Personal analytics (on-device only) · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

The notification ledger already records every reminder that was
scheduled and how the user acted on it (Done/Snooze/Skip, or no action at
all), but that history is currently write-only audit data — nothing reads
it back to tell the user anything useful. Surfacing a simple derived
stat ("Reminders led to a logged action 68% of the time") turns existing
audit data into an actionable, entirely local insight that helps a user
notice their own reminders aren't landing at a useful time and adjust
them — with zero new data collection and nothing leaving the device,
since the ledger already exists purely for on-device notification
scheduling and diffing.

## Goals

- Compute, from the existing notification ledger, the rate at which a
  scheduled reminder was followed by an actual logged action (Done, or an
  equivalent module-specific completion) versus ignored, snoozed
  repeatedly, or skipped.
- Break this down per module and, ideally, per reminder time-of-day, so
  the user gets a specific, actionable signal ("your 9pm Water reminder
  rarely gets acted on") rather than one blended number.
- Present it somewhere reasonable — likely Settings' notification area or
  each module's own stats screen — as a small, honest self-diagnostic.

## Non-goals / out of scope

- Not product telemetry — nothing here is sent anywhere; it's the user
  reading back their own local ledger, the same trust boundary the ledger
  already operates inside (`notification_ledger_repository`).
- Not a recommendation/auto-tuning engine (e.g. auto-moving reminder
  times) — this pass only surfaces the stat; acting on it is left to the
  user.
- Not a real-time live metric — a periodic/on-demand computation over
  existing ledger rows is sufficient, no need for it to update instantly
  as actions happen.

## Proposed approach (high-level)

The notification ledger already stores, per scheduled notification, its
outcome (the Done/Snooze/Skip action-handling logic already writes to it)
— this feature is a read-side aggregation over that existing table, no
change to what gets written. The computation groups ledger rows by module
(and optionally by time-of-day bucket) and calculates the proportion that
resulted in a "positive" outcome (Done, or the module's equivalent) versus
Snooze/Skip/no-action, then presents that as a percentage. This is
conceptually the same shape of pure aggregation-over-existing-data as the
Reports module's own use cases, just sourced from the notification ledger
repository (`notification_ledger_repository`) instead of a module's own
domain tables.

## Dependencies & prerequisites

- `notification_ledger_repository`'s existing recorded outcomes as the
  sole data source — need to confirm the ledger's schema already
  distinguishes "acted on" from "ignored/snoozed/skipped" cleanly enough
  to compute this without ambiguity.
- Enough notification history for the stat to be meaningful — a fresh
  install has no ledger data yet, which needs a sensible empty state.
- A presentation surface — likely Settings' notification-reliability area
  (which already exists per the reliability-stub screens) or a small
  addition to each module's stats screen.

## Open questions for the implementation round

- Does "led to a logged action" need to be scoped to a time window after
  the notification fired (e.g. within the same day) to avoid crediting an
  unrelated later action to an old reminder?
- Should Snooze count as a partial-positive outcome (the user engaged,
  just deferred) or a negative one for this metric?
- Per-time-of-day breakdown — is that in scope for a first pass, or is an
  overall per-module percentage enough to start?
- Where does this live — Settings' reliability screen, each module's stats
  screen, or both?

## Effort & sequencing notes

Atlas complexity: S. Purely a read-side aggregation over an existing,
already-populated table — no new write paths, no new domain logic beyond
a grouping/percentage calculation. Low-risk, independent of every other
item in this batch.

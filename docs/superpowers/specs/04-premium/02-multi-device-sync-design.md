# Multi-Device Sync

**Category:** Premium · **Atlas complexity:** L · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
This is roadmap.md's #3 v1.1+ candidate, deliberately sequenced after
Google Drive backup validates real demand for going beyond a
single-device app. Users who own multiple devices (phone + tablet, or
who upgrade phones) currently have no way to keep habit data current
across them short of manual export/import each time. Real-time or
near-real-time sync is the point at which this stops being a backup
feature and becomes a genuine ongoing-value subscription tier — it is
the clearest candidate in this whole atlas category for recurring
billing rather than a one-time purchase.

## What stays free vs. what's paywalled
Single-device use of every habit module (Water/Medicine/Prayer and any
future modules) stays entirely free — nothing about core tracking
requires sync. Multi-device sync itself — keeping two or more devices'
data continuously consistent, including conflict resolution when both
were used offline — is the paywalled feature, priced as an ongoing
subscription since it implies ongoing backend cost (unlike the one-time
nature of a Drive backup).

## Goals
- Let a subscribed user use the app on two or more devices with data
  that reconciles automatically, without the user manually
  exporting/importing.
- Handle the offline-first reality: both devices can log data while
  disconnected from each other, and must reconcile without silent data
  loss when they reconnect.
- Keep every module's domain logic untouched — sync should be a
  cross-cutting layer beneath the existing repositories, not something
  each module's own code has to know about individually.

## Non-goals / out of scope
- Not designing the actual backend/sync-target infrastructure in this
  pass — that decision (serverless function, managed backend, or reusing
  the Drive-backup channel as a poor-man's sync) is deferred to the
  implementation round.
- Not solving real-time collaborative editing (two people editing the
  same profile simultaneously) — this is about one person's own data
  across their own devices.
- Not building the family/multi-profile sharing model — that's a
  separate, later item (#3 in this spec set) that depends on this one
  existing first.

## Proposed approach (high-level)
Introduce a sync layer that sits below the existing repository
interfaces (Water/Medicine/Prayer/Settings repositories), most likely by
extending each table's existing `created_at`/`updated_at`/`deleted_at`
convention (already a database-design.md rule) into the basis for a
last-write-wins or vector-clock conflict resolution strategy, so no
module's domain/use-case code needs to change — only the data layer
gains a sync-aware repository implementation alongside the existing
Drift-only one. The `HabitModule` contract's existing `exportData`/
`importData` pair is a natural reuse point for serializing a module's
state into whatever the sync transport needs, the same way it will
already be reused for Drive backup. A background sync process
(comparable in spirit to the existing WorkManager-driven notification
top-up, though a separate mechanism) would periodically reconcile local
state with the sync target when connectivity is available.

## Dependencies & prerequisites
- Google Drive backup/restore (this spec set's item #1) should ship and
  prove demand first, per roadmap.md's explicit sequencing.
- A conflict-resolution strategy decision (last-write-wins is the
  cheapest starting point given every table already has `updated_at`).
- A sync backend or target (own serverless backend vs. reusing a
  Drive-based store vs. a third-party sync-as-a-service) — a major open
  question, not assumed here.
- Subscription/IAP infrastructure shared with other premium features.

## Open questions for the implementation round
- What's the sync backend — self-hosted, serverless, or a existing
  BaaS/sync-as-a-service product? This materially changes L→XL effort.
- Does sync cover every module uniformly, or can a module opt out (e.g.
  a hypothetical module with genuinely device-local-only data)?
- How aggressively does conflict resolution need to reason about
  deletes vs. edits (tombstones) given every table already carries
  `deleted_at`?
- What happens to Prayer's location/GPS-derived settings on a second
  device with a different location — does location sync at all, or stay
  per-device?

## Effort & sequencing notes
L complexity — the largest item in this batch, both in backend surface
area and in the conflict-resolution logic. Deliberately sequenced after
Drive backup (#1) validates real demand for anything beyond single-device
use before committing to ongoing backend cost and complexity.

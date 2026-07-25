# Multi-Device Sync

**Category:** Premium · **Atlas complexity:** L · **Retention impact:** High
**Date:** 2026-07-23 · **Revised:** 2026-07-25
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
- Preserve the app's privacy posture: sync data is encrypted
  end-to-end; the backend never sees plaintext habit data.

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

### Sync architecture layers

```
┌─────────────────────────────────────────┐
│  Module domain/use-case code            │  ← UNCHANGED
├─────────────────────────────────────────┤
│  Sync-aware repository wrapper          │  ← NEW: intercepts reads/writes,
│  (last-write-wins / vector clock)       │     adds sync metadata
├─────────────────────────────────────────┤
│  Local Drift repository (existing)      │  ← UNCHANGED
├─────────────────────────────────────────┤
│  Sync transport (encrypted, periodic)   │  ← NEW: backend communication
├─────────────────────────────────────────┤
│  Backend (serverless / BaaS)            │  ← DEFERRED to implementation
└─────────────────────────────────────────┘
```

### Conflict resolution strategy
Last-write-wins (LWW) based on `updated_at` is the starting point,
since every table already carries this column. This is sufficient for
the common case (user edits on one device at a time). Edge cases:
- **Simultaneous edits to the same row on both devices:** LWW picks the
  newer `updated_at`. The losing edit is lost — acceptable for habit
  tracking where most edits are simple appends (new log, status change).
- **Delete vs. edit:** a `deleted_at` set on one device wins over an
  edit on another — tombstone semantics, already supported by the
  `deleted_at` column pattern.
- **Future upgrade path:** the schema can evolve to vector clocks by
  adding a `sync_version INTEGER` column per table if LWW proves too
  lossy in practice.

### Sync metadata table
A new `sync_state` singleton table tracks sync progress per device:

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | always `'singleton'` |
| device_id | TEXT | UUID generated on first sync, stored in secure storage |
| last_sync_at | INTEGER NULL | UTC epoch millis of last successful sync |
| sync_backend | TEXT | `'drive_channel'` \| `'server'` (future) |
| pending_changes_count | INTEGER | for UI display of sync status |
| created_at, updated_at | INTEGER | |

### First-sync migration
When a user enables sync on a second device for the first time:
1. The second device uploads its entire local state (via each module's
   `exportData()`).
2. The first device's existing state is treated as the baseline.
3. A merge pass runs: for each row, compare `updated_at`; keep the
   newer version on both devices.
4. Post-merge, both devices enter normal periodic sync.

This is functionally identical to Drive restore, reusing the same
`importData()` pathway — no new merge logic for the initial case.

## Database changes
- New `sync_state` table (see above) added to `AppDatabase`.
- No changes to existing module tables in this pass — the `updated_at`
  convention already provides sufficient sync metadata for LWW.
- If vector clocks are chosen instead of LWW, each module table would
  gain a `sync_version INTEGER` column — flagged as a future migration,
  not part of this initial design.

## Dependencies & prerequisites
- Google Drive backup/restore (this spec set's item #1) should ship and
  prove demand first, per roadmap.md's explicit sequencing.
- A conflict-resolution strategy decision (last-write-wins is the
  cheapest starting point given every table already has `updated_at`).
- A sync backend or target (own serverless backend vs. reusing a
  Drive-based store vs. a third-party sync-as-a-service) — a major open
  question, not assumed here.
- Entitlement/IAP infrastructure (spec 07) for subscription gating.
- Device identity: a stable per-device UUID stored in
  `flutter_secure_storage`, needed to distinguish "my own devices" from
  "someone else's device" in a future multi-device trust model.

## Localization
- Sync status indicators ("Synced 2 min ago", "Syncing...", "Sync
  failed") need en/bn ARB keys.
- Error messages for sync conflicts or failures need bilingual support.

## Edge cases & error handling
- **Device goes offline mid-sync:** the `sync_state.last_sync_at` stays
  stale; on reconnect, the next sync cycle picks up all pending changes.
- **Sync while app is in background:** use WorkManager (Android) and
  background fetch (iOS) — same pattern as notification top-up.
- **Data wipe on one device:** the wiped device syncs its empty state;
  the other device's data is not deleted (wipe is device-local unless
  explicitly confirmed as a "wipe all devices" action).
- **App version mismatch across devices:** sync should be forward-
  compatible (newer app on one device can sync with older app on
  another) — the `exportData()`/`importData()` contract handles this.
- **Prayer location settings:** location/GPS-derived settings are
  per-device by nature (a user traveling has different prayer times).
  Sync should NOT sync `prayer_settings.location_mode` or GPS coords —
  these stay device-local. Only manually-entered location settings sync.

## Open questions for the implementation round
- What's the sync backend — self-hosted, serverless, or an existing
  BaaS/sync-as-a-service product? This materially changes L→XL effort.
- Does sync cover every module uniformly, or can a module opt out (e.g.
  a hypothetical module with genuinely device-local-only data)?
- How aggressively does conflict resolution need to reason about
  deletes vs. edits (tombstones) given every table already carries
  `deleted_at`?
- What happens to Prayer's location/GPS-derived settings on a second
  device with a different location — does location sync at all, or stay
  per-device? (Answered above: per-device.)
- What's the maximum number of devices per account?

## Effort & sequencing notes
L complexity — the largest item in this batch, both in backend surface
area and in the conflict-resolution logic. Deliberately sequenced after
Drive backup (#1) validates real demand for anything beyond single-device
use before committing to ongoing backend cost and complexity.

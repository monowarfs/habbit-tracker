# Google Drive Backup/Restore

**Category:** Premium · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
This is roadmap.md's #2 v1.1+ candidate. The app is offline-first with no
account system, which is a deliberate trust-building choice for
privacy-conscious personas — but it leaves users with only local file
export as a safety net, which most people never remember to run manually.
A one-tap Drive backup gives real disaster protection (lost/broken/
replaced phone) without introducing an account requirement or an
always-on sync relationship with a server the team runs.

## What stays free vs. what's paywalled
Local file export/import (roadmap's #1 candidate) stays free forever —
it's the baseline safety net every user gets, no account needed. Google
Drive backup/restore itself is the premium feature: automatic/one-tap
upload to the user's own Drive, scheduled/reminder-driven backups, and
restore-from-Drive on a new device. The user's data still belongs
entirely to them in their own Drive folder — this is not the app's cloud,
it's a convenience wrapper over the user's existing storage, which is why
it can be revoked (disconnect Drive access) without any data loss since
the local export format underneath is unchanged and still free.

## Goals
- Reuse the existing local export format as the payload shipped to Drive
  — no new serialization format to design or maintain.
- One-tap backup and one-tap restore, each clearly showing last-backup
  timestamp and what will be overwritten before a restore.
- Fully revocable: disconnecting Drive access must not affect local data
  or the free local-export path.
- Works within the app's offline-first posture — Drive is opportunistic
  (used when signed in and online), never required for core app function.

## Non-goals / out of scope
- Not building general cloud sync (that's item #2, deliberately sequenced
  after this one per roadmap.md).
- Not requiring a Google account to use the app at all — this stays an
  optional add-on entry point.
- Not supporting other cloud providers (iCloud, Dropbox) in this pass —
  single-provider scope keeps this at M complexity.
- Not handling multi-device conflict resolution — this is backup/restore
  (last-write-wins, user-initiated), not continuous sync.

## Proposed approach (high-level)
Layer a Drive-backed backup path on top of whatever export/import
mechanism the free local-export feature establishes first. The app
requests narrow Drive scope (app-data folder or user-selected folder,
not full Drive access) purely for reading/writing the app's own backup
file. A settings screen surfaces connect/disconnect, last-backup time,
and manual "back up now"/"restore" actions. Restore reuses the same
import path local file-restore already uses, just sourcing bytes from
Drive instead of a file picker. Because this sits behind the existing
settings feature slice and reuses the export/import contract rather than
inventing a new one, it should not require changes to any habit module —
Water/Medicine/Prayer's `exportData`/`importData` implementations feed
this the same way they'd feed local export.

## Dependencies & prerequisites
- Local file export/import (roadmap's #1 candidate) should land first —
  this feature is explicitly "where that groundwork gets used," per
  roadmap.md.
- A Google API client for Drive scope (e.g. `googleapis`/Google Sign-In
  package) and IAP/purchase-gating plumbing to mark this premium.
- Decide where purchase-state lives (likely a new settings-adjacent
  concern, not a habit module) before wiring the paywall gate.

## Open questions for the implementation round
- Does Drive backup gate at "connect account" time or only at "restore on
  a new device" time — i.e. can a non-premium user still connect Drive
  but not restore, or is the whole flow behind the paywall?
- What's the retry/backoff story for a failed background backup (device
  offline, token expired) — does it fail silently or surface a nudge?
- Should backup be triggered automatically (e.g. daily, on app background)
  once connected, or purely manual — automatic raises battery/quota
  concerns worth scoping explicitly later.
- How is the free local-export format versioned so a future schema change
  doesn't break restores of older backups?

## Effort & sequencing notes
M complexity — bounded by reusing the local-export payload format and the
existing settings slice; the actual new surface area is Drive
auth/upload/download plumbing, not new domain logic. Sequenced directly
after local export/import validates the export format and demand for a
safety net at all.

# Google Drive Backup/Restore

**Category:** Premium · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23 · **Revised:** 2026-07-25
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
- Reuse the existing local export format (`core/backup/` — the
  `ModuleExport` JSON payload each `HabitModule.exportData()` returns)
  as the payload shipped to Drive — no new serialization format to design
  or maintain.
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

### Drive backup file format
The backup file is a single ZIP archive containing:
- `manifest.json` — schema version, creation timestamp, device info,
  app version. Enables forward-compatible restores (a newer app version
  can restore an older backup; an older app version gracefully degrades
  when encountering a newer schema version).
- One `*.json` file per module (`water.json`, `medicine.json`,
  `prayer.json`, `settings.json`) — each the raw `ModuleExport.payload`
  from `HabitModule.exportData()`.
- `achievements.json` — the achievements table contents (key, progress,
  unlocked_at) since achievements are cross-module and not owned by any
  single module's `exportData()`.

### Backup metadata tracking
Add a `drive_backups` table to Drift for tracking Drive backup state:

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | UUID v7 |
| backup_file_name | TEXT | Drive file name, e.g. `habit-tracker-backup-2026-07-25.zip` |
| backed_up_at | INTEGER | UTC epoch millis |
| schema_version | INTEGER | backup format version |
| file_size_bytes | INTEGER | for UI display and quota awareness |
| status | TEXT | `'success'` \| `'failed'` \| `'in_progress'` |
| created_at, updated_at | INTEGER | |

This table is the source of truth for "last backup time" displayed in
Settings and for the backup-reminder scheduler.

### Restore safety
Before restoring, the app must:
1. Show a confirmation dialog listing what will be overwritten (all
   module data, settings, achievements) and the backup's creation date.
2. Snapshot the current local state as a pre-restore backup (uploaded to
   Drive as `habit-tracker-pre-restore-{timestamp}.zip`) before applying
   the restore — this is a safety net against accidental restores.
3. Execute the restore in a transaction: wipe all module data via each
   module's `wipeData()` (already on the `HabitModule` contract), then
   import each module's payload via `importData()`.

### Schedule-driven backups
Once connected, offer an optional daily backup reminder (local
notification, not a background service) nudging the user to back up.
Automatic silent backups are deferred to a later pass — the battery/
quota tradeoff needs real-world data first. The reminder is scheduled
through the existing `NotificationService` infrastructure.

## Database changes
- New `drive_backups` table (see above) added to `AppDatabase`'s table
  manifest.
- No changes to existing module tables — backup/restore reuses
  `exportData()`/`importData()` as-is.

## Dependencies & prerequisites
- Local file export/import (roadmap's #1 candidate) should land first —
  this feature is explicitly "where that groundwork gets used," per
  roadmap.md.
- A Google API client for Drive scope (e.g. `googleapis`/Google Sign-In
  package).
- Entitlement/IAP infrastructure (spec 07) to gate this as premium.
  The `core/premium/entitlement_service.dart` and
  `premium_gate_widget.dart` from spec 07 provide the purchase-state
  check this feature wires into.

## Localization
- All new strings (backup/restore button labels, confirmation dialogs,
  error messages, schedule settings) need en/bn ARB keys from day one.
- The backup file manifest's human-readable fields (backup name) are
  locale-agnostic since they're not displayed to the user.

## Edge cases & error handling
- **Drive quota exceeded:** surface a clear error message suggesting
  manual local export as fallback; do not silently fail.
- **Token expired/revoked:** detect on next backup attempt, prompt
  re-authentication; do not cache stale tokens.
- **Partial upload (network loss):** the `drive_backups` row stays
  `in_progress`; on next app launch, check for orphaned in-progress
  backups and either resume or mark failed.
- **Restore of a backup from a different app version:** the manifest's
  schema version enables forward-compatible restores; a version mismatch
  shows a warning dialog but proceeds if the user confirms.
- **Restore on a device with existing data:** handled by the safety
  snapshot described above.

## Open questions for the implementation round
- Does Drive backup gate at "connect account" time or only at "restore on
  a new device" time — i.e. can a non-premium user still connect Drive
  but not restore, or is the whole flow behind the paywall?
- Should backup be triggered automatically (e.g. daily, on app background)
  once connected, or purely manual — automatic raises battery/quota
  concerns worth scoping explicitly later.
- How many pre-restore safety backups to keep on Drive before pruning
  old ones (storage management)?

## Effort & sequencing notes
M complexity — bounded by reusing the local-export payload format and the
existing settings slice; the actual new surface area is Drive
auth/upload/download plumbing, not new domain logic. Sequenced directly
after local export/import validates the export format and demand for a
safety net at all.

# Implementation Plan: Google Drive Backup/Restore

**Spec:** `01-google-drive-backup-restore-design.md`
**Complexity:** M · **Estimated effort:** 3-4 days
**Depends on:** Local file export/import (roadmap #1), spec 07 (entitlements)

---

## Task 1: Add `drive_backups` Drift table

**File:** `lib/core/database/app_database.dart`

Add the `drive_backups` table to the `@DriftDatabase` annotation's table
list. Create the table class in `lib/core/backup/drive_backup_table.dart`:

```dart
class DriveBackups extends Table {
  TextColumn get id => text()();
  TextColumn get backupFileName => text()();
  IntColumn get backedUpAt => integer()();
  IntColumn get schemaVersion => integer()();
  IntColumn get fileSizeBytes => integer()();
  TextColumn get status => text()(); // 'success' | 'failed' | 'in_progress'
  @override
  Set<Column> get primaryKey => {id};
}
```

Add one line to `AppDatabase`'s `tables:` list.

**Test:** `flutter test test/core/database/app_database_test.dart` — verify
the table exists and migrations pass.

---

## Task 2: Create `DriveBackupRepository`

**File:** `lib/core/backup/drive_backup_repository.dart`

A Drift repository for the `drive_backups` table with methods:
- `upsertBackup(DriveBackupCompanion)` — insert or update a backup record.
- `latestBackup()` → `DriveBackup?` — returns the most recent successful
  backup for "last backup time" display.
- `markInProgress(String backupId)` — sets status to `'in_progress'`.
- `markComplete(String backupId, int fileSizeBytes)` — sets status to
  `'success'` with file size.
- `markFailed(String backupId)` — sets status to `'failed'`.

**Test:** `test/core/backup/drive_backup_repository_test.dart` — CRUD tests
using an in-memory database.

---

## Task 3: Create backup file format utilities

**File:** `lib/core/backup/backup_file_format.dart`

Functions for creating and parsing the ZIP backup archive:
- `Future<List<int>> createBackupArchive(AppDatabase db)` — calls each
  module's `exportData()`, adds `manifest.json` and per-module JSON
  files to a ZIP archive using the `archive` package.
- `Future<BackupManifest> parseBackupArchive(List<int> bytes)` — parses
  a ZIP archive, reads `manifest.json`, validates schema version.

**File:** `lib/core/backup/backup_manifest.dart`

The `BackupManifest` class with fields: `schemaVersion`,
`createdAt`, `deviceInfo`, `appVersion`, `moduleNames`.

**Test:** `test/core/backup/backup_file_format_test.dart` — round-trip
create/parse tests.

---

## Task 4: Create `DriveBackupService` (Google Drive API)

**File:** `lib/core/backup/drive_backup_service.dart`

Wraps the Google Drive API for upload/download:
- `Future<void> connectDrive()` — initiates Google Sign-In with Drive
  scope, stores auth token securely.
- `Future<void> disconnectDrive()` — revokes access, clears stored token.
- `Future<bool> isDriveConnected()` — checks if a valid token exists.
- `Future<String?> uploadBackup(List<int> bytes, String fileName)` —
  uploads the ZIP to the user's Drive app-data folder, returns the
  Drive file ID.
- `Future<List<int>?> downloadBackup(String fileId)` — downloads a
  backup file from Drive.
- `Future<DateTime?> getLastBackupTime()` — queries Drive for the most
  recent backup file's modification time.

Uses `googleapis` and `google_sign_in` packages.

**Test:** Unit tests with mocked Drive API (mockito).

---

## Task 5: Create backup/restore use cases

**File:** `lib/core/backup/backup_use_case.dart`

- `Future<Result<void>> performBackup(AppDatabase db)` — orchestrates:
  1. Check entitlement (spec 07).
  2. Create backup archive via `backup_file_format.dart`.
  3. Upload to Drive via `DriveBackupService`.
  4. Record in `drive_backups` table.
  5. Return `Result.success()` or `Result.failure()`.

**File:** `lib/core/backup/restore_use_case.dart`

- `Future<Result<void>> performRestore(AppDatabase db, String fileId)` —
  orchestrates:
  1. Check entitlement.
  2. Show confirmation dialog data (what will be overwritten).
  3. Create pre-restore safety backup.
  4. Download backup from Drive.
  5. Parse archive.
  6. Wipe all module data via each module's `wipeData()`.
  7. Import each module's payload via `importData()`.
  8. Return result.

**Test:** `test/core/backup/backup_use_case_test.dart` — integration tests
with mocked Drive service.

---

## Task 6: Add backup settings screen

**File:** `lib/features/settings/presentation/screens/backup_settings_screen.dart`

A new settings screen showing:
- Connect/Disconnect Drive button.
- Last backup timestamp.
- "Back Up Now" button with progress indicator.
- "Restore" button with confirmation dialog.
- Backup reminder toggle (daily local notification).

Add route to `app_router.dart` under `/settings/backup`.

**Test:** Widget tests for the screen's key states (connected,
disconnected, backup in progress).

---

## Task 7: Add backup settings entry to Settings screen

**File:** `lib/features/settings/presentation/screens/settings_home_screen.dart`

Add a "Backup & Restore" `ListTile` in the Data section, navigating to
`/settings/backup`. Gated behind premium check from spec 07.

**Test:** Verify the tile appears and navigates correctly.

---

## Task 8: Add localization strings

**File:** `lib/core/l10n/app_en.arb` and `lib/core/l10n/app_bn.arb`

Add ARB keys for:
- Backup screen title, button labels, status messages.
- Confirmation dialog text (restore warning).
- Error messages (Drive connection failed, quota exceeded, etc.)
- Backup reminder notification text.

Run `flutter gen-l10n` to regenerate.

---

## Task 9: Wire backup reminder notification

**File:** `lib/core/backup/backup_reminder_scheduler.dart`

Uses the existing `NotificationService` to schedule a daily backup
reminder (local notification at a configurable time). The reminder is
a local-only notification, not tied to any module's
`pendingNotifications()`.

---

## Task 10: Add entitlement gate

Wire the premium check from spec 07's `entitlement_service.dart` into
the backup settings screen. Non-premium users see a "Unlock Premium"
CTA instead of the backup controls.

---

## Review checklist

- [ ] All new code follows `very_good_analysis` lint rules.
- [ ] All new strings have en/bn ARB keys.
- [ ] Drift table is added to `AppDatabase`'s table manifest.
- [ ] Backup/restore round-trips correctly (create → upload → download
  → parse → import).
- [ ] Pre-restore safety backup is created before restore.
- [ ] Disconnecting Drive does not affect local data.
- [ ] Entitlement gate works for non-premium users.
- [ ] Error handling covers network failure, quota exceeded, token
  expiry.

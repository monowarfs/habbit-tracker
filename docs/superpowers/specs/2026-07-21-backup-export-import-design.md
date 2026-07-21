# Backup Export/Import: Harden the Already-Built Flow

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

A "Feature Atlas" gap-analysis artifact flagged **local file export/import
(backup)** as a "Must Have" v1.1 candidate, citing `roadmap.md`'s #1
v1.1+ item and assuming it needed to be designed and built from scratch.

It doesn't. An audit of `lib/core/backup/` and
`lib/features/settings/presentation/screens/data_settings_screen.dart`
found the feature is **already fully implemented and wired end-to-end**,
matching `docs/strategies/backup-import-export.md`'s design almost
exactly:

- **Envelope** (`backup_envelope.dart`): versioned JSON
  (`schemaVersion`/`exportedAt`/`appVersion`/`modules`/`common`), with an
  empty-but-present migration-chain seam (`import_orchestrator.dart`'s
  `_migrations` map) ready for a future `1: migrateV1ToV2`.
- **Export** (`export_orchestrator.dart`): iterates the live
  `habitModulesProvider` list calling each module's `exportData()` —
  Water, Medicine, and Prayer all implement `exportData`/`importData`/
  `wipeData` on the shared `HabitModule` contract — plus `appSettings`
  and `achievements` under `common`. PIN hash/salt correctly never
  included (they live outside the DB entirely).
- **Import** (`import_orchestrator.dart`): `validateImport` does the
  full ordered validation from the strategy doc (JSON shape → schema
  version, rejecting newer-than-supported → required top-level fields)
  and returns a row-count-per-module `ImportPreview`; `applyImport` wipes
  every table (`wipe_all_data.dart`, shared with the PIN "forgot PIN"
  reset) and restores everything inside one DB transaction, so a failure
  anywhere rolls back and leaves existing data untouched.
- **UI** (`data_settings_screen.dart`, reachable from Settings → Data,
  routed at `/settings/data`): three real buttons — Export (builds the
  envelope, writes it to a temp file, opens the OS share sheet via
  `LocalFileBackupTarget.upload`, which covers both "share" and
  "save to Files/device"), Import (file-picker → `validateImport` →
  a confirm dialog showing the exact per-module row counts and a replace
  warning → `applyImport` → success/failure snackbar), and Share
  diagnostic logs.
- **Dependencies**: `file_picker`, `share_plus`, and `path_provider` are
  already in `pubspec.yaml` and already used by exactly this code — no
  new dependency needed.
- **Tests**: `test/core/backup/{backup_envelope,export_orchestrator,
  import_orchestrator}_test.dart` cover malformed JSON, a newer schema
  version, truncated fields, and a full export→wipe→import round trip
  across all three modules with content-equality checks.
- **Localization**: every string on the Data screen (`dataSettingsExport`,
  `dataImportPreviewTitle`, `dataImportPreviewWarning`,
  `dataImportPreviewCount`, `dataImportSuccess`, `dataImportFailed`, …)
  exists in both `app_en.arb` and `app_bn.arb`.

**So the actual gap is not "build export/import."** It's two narrow
hardening holes an audit turned up, plus a coverage gap:

1. **`_export()` has no error handling.** `PackageInfo.fromPlatform()`,
   `file.writeAsString(...)`, and `LocalFileBackupTarget().upload(...)`
   (the share-sheet call) all run inside a bare `try { ... } finally { ...
   }` with no `catch`. If any of them throws — disk full, share sheet
   dismissed with a platform error, `PackageInfo` unavailable — the
   exception is unhandled: no snackbar, no log entry, `_busy` resets via
   `finally` so the UI doesn't hang, but the user gets zero feedback that
   the export they just tapped silently failed. Compare to `_import()`,
   which already routes `validateImport`/`applyImport` failures through
   `_showFailure` — `_export()` has no equivalent path at all.
2. **`_import()`'s `file.readAsString()` call is unguarded.** It runs
   *before* `validateImport` (which does have its own internal
   `try`/`on FormatException` for JSON parsing) — so a file that can't be
   read as text at all (permission revoked between picking and reading,
   file moved/deleted, or a genuinely binary file the `.json`-extension
   filter didn't catch) throws an unhandled `FileSystemException` or
   `FormatException` (invalid UTF-8) with no user-facing message.
3. **No widget test exercises `DataSettingsScreen`.** The three
   orchestrator test files are solid unit coverage of the pure logic, but
   nothing drives the actual screen — the confirm-dialog wiring, the
   busy-state spinner, or the snackbar paths are untested.

Two additional items came up during the audit and are explicitly **not**
gaps worth building against right now (see Out of scope): the strategy
doc's example envelope includes a `common.modules` (enable/disable state)
block, but no per-module enable/disable feature exists anywhere in the
codebase yet, so there's nothing to export there — the current envelope
already exports everything that exists. And the strategy doc's forward-
looking `BackupTarget` interface sketch includes `lastBackupAt()`; the
actual shipped `BackupTarget` abstract class correctly does not have it,
since nothing persists a "last backup" timestamp — that's a real, but
separate, small feature (see Out of scope).

## Design

This is a hardening patch on an already-complete feature, not a new
build. Three changes, in `data_settings_screen.dart` and one new test
file.

**1. Wrap `_export()` in a `catch`, matching `_import()`'s existing
error-surfacing pattern.**

```dart
Future<void> _export() async {
  setState(() => _busy = true);
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final envelope = await buildExport(...);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'habit_tracker_backup.json'));
    await file.writeAsString(...);
    await LocalFileBackupTarget().upload(file);
  } on Object catch (e, st) {
    appLogger.e('export failed', error: e, stackTrace: st);
    if (mounted) _showFailure(e.toString());
  } finally {
    if (mounted) setState(() => _busy = false);
  }
}
```

Reuses the existing `_showFailure`/`dataImportFailed`-style snackbar path
— no new l10n string needed for the export side since `dataImportFailed`
is generically named "reason", but it's import-specific copy
(`"Import failed: {reason}"`). Add one sibling string,
`dataExportFailed` (`"Export failed: {reason}"`), to both `app_en.arb`
and `app_bn.arb`, following the exact same `{description}` metadata
pattern as `dataImportFailed`.

**2. Wrap the `file.readAsString()` call in `_import()`** with the same
`on Object catch` treatment, reusing `_showFailure` and
`dataImportFailed` (already generic enough — "Import failed: {reason}"
reads fine whether the failure was a parse error or a read error):

```dart
Future<void> _import() async {
  final file = await LocalFileBackupTarget().download();
  if (file == null) return;
  final String rawJson;
  try {
    rawJson = await file.readAsString();
  } on Object catch (e, st) {
    appLogger.e('import file read failed', error: e, stackTrace: st);
    if (mounted) _showFailure(e.toString());
    return;
  }
  final validation = await validateImport(rawJson);
  // ... unchanged from here
}
```

**3. New `test/features/settings/presentation/screens/
data_settings_screen_test.dart`.** `file_picker`/`share_plus` both talk
to platform channels, so the widget test doesn't drive the real
`LocalFileBackupTarget` — it covers what's actually reachable without a
platform-channel mock:

- Pumping `DataSettingsScreen` renders the three list tiles with their
  correct localized labels.
- A `validateImport` failure path (feed `applyImport`/`validateImport`
  a bad envelope through the same seam the orchestrator tests already
  use) shows the `dataImportFailed` snackbar text — this exercises
  `_showFailure` and the `Result`-branch wiring already in `_import()`,
  independent of the file-picker step.
- The confirm dialog (`_confirmImport`) renders the right per-module
  counts and warning text given a fixed `ImportPreview`, and tapping
  Cancel vs. Restore returns the right bool — this can be tested by
  pumping the dialog builder directly (same technique other confirm-
  dialog tests in this codebase likely already use for the PIN reset
  confirm dialog).

Full end-to-end coverage of the actual file-pick/share-sheet steps stays
a manual-QA item (device file pickers aren't testable in `flutter test`
without deeper platform-channel mocking than this hardening pass
justifies) — no different from how `LocalFileBackupTarget` itself has no
unit test today.

**Error handling for malformed/foreign import files — already correct,
confirmed by reading `validateImport`, no change needed:**

| Input | Current behavior |
|---|---|
| Not valid JSON at all | `on FormatException` inside `validateImport` → `"File is not valid JSON"` |
| Valid JSON, not an object (e.g. a bare array) | `"File is not a valid backup envelope"` |
| Valid object, missing/wrong-typed `schemaVersion` | `"Missing or invalid schema version"` |
| `schemaVersion` newer than `BackupEnvelope.currentSchemaVersion` | `"This backup was made with a newer version of the app — update the app first"` |
| `schemaVersion` older, no migration step registered for it | `"Unsupported backup schema version"` |
| Missing `modules`/`common`/`exportedAt`/`appVersion` keys, or wrong types | `"Backup file is missing required fields"` |
| A completely foreign JSON file (e.g. another app's export) that happens to have those five top-level keys with plausible types but garbage nested content | Caught at `applyImport` time — a thrown exception during the transaction (e.g. a module's `importData` failing to parse a row) is caught by the outer `on Object catch (e)` and surfaced as `AppException.storage('apply_import', e)`, and the whole transaction rolls back per Drift's transaction semantics, so partial-garbage data never lands |

The one gap in this table is items 1-2 above (I/O-level exceptions
*outside* `validateImport`'s own try/catch — reading the file at all,
or writing/sharing during export) — which this design closes.

## Out of scope

- **"Last backup at" timestamp / reminder to back up periodically.** No
  persistence for this exists today (the strategy doc's forward-looking
  `BackupTarget.lastBackupAt()` sketch was never implemented, correctly —
  YAGNI until Google Drive backup, which needs it for real, actually
  ships). Adding it now for local-file backup would mean inventing a
  "when did the user last tap Export" concept the OS share sheet can't
  actually confirm (the user can dismiss the share sheet without saving
  anywhere) — not a real signal worth persisting for v1.
- **`common.modules` enable/disable export**, per the strategy doc's
  original envelope sketch. No per-module enable/disable feature exists
  in the app at all yet — nothing to export. Revisit if/when that
  feature ships.
- **Migration chain implementation** (`migrateV1ToV2` etc.) — the seam
  exists and is correctly empty; there's only ever been schema version 1
  so far.
- **Google Drive / cloud backup target** — `roadmap.md`'s #2 candidate,
  explicitly sequenced after local file backup; `BackupTarget`'s
  interface already anticipates it with zero changes needed to the
  orchestrator/envelope/validation code, per the strategy doc.
- **Cleaning up the temp export file** after the share sheet closes
  (`getTemporaryDirectory()`'s `habit_tracker_backup.json` is left behind
  and overwritten next export, not deleted). Cosmetic — OS temp
  directories are already reclaimed by the platform, and this isn't a
  data-loss or correctness issue.

## Global Constraints

- No new dependencies — `file_picker`, `share_plus`, `path_provider`
  already present.
- No DB schema change, no envelope shape change, no change to any
  module's `exportData`/`importData`/`wipeData`.
- New l10n key: `dataExportFailed` (`"Export failed: {reason}"`) in both
  `app_en.arb` and `app_bn.arb`, same `{reason}` placeholder pattern as
  `dataImportFailed`.
- Both new `catch` blocks log via the existing `appLogger` singleton
  (`core/logging/app_logger.dart`) before surfacing the user-facing
  snackbar — consistent with how `applyImport`'s own internal catch
  already wraps failures in `AppException.storage`.

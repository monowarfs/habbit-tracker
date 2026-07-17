# Backup / Import / Export

Not a committed v1.0 feature (`../product/feature-breakdown.md` lists local
export/import as the first v1.1+ candidate) — this document designs the
shape now because `offline-strategy.md`'s `updated_at`/`deleted_at`
groundwork exists specifically to make this cheap later, and the plugin
architecture needs this seam defined before any module ships so
`HabitModule.exportData()`/`importData()` (`architecture.md`) aren't
retrofitted.

## JSON export envelope

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-07-17T12:00:00Z",
  "appVersion": "1.0.0",
  "modules": {
    "water": { "goals": [ /* WaterGoal rows */ ], "logs": [ /* WaterEntry rows */ ] },
    "medicine": { "medicines": [], "schedules": [], "doses": [], "stockEvents": [] },
    "prayer": { "settings": {}, "records": [], "qadhaCounters": [] }
  },
  "common": {
    "appSettings": {},
    "modules": [ /* ModuleState rows, enable/disable per module */ ],
    "achievements": []
  }
}
```

Row shapes inside each module's block match `../technical/data-models.md`'s
JSON export column for that entity exactly — soft-deleted rows
(`deletedAt != null`) are included, per `offline-strategy.md`'s reasoning
(a future merge/restore needs to know a row was deleted, not just see it
missing). `pin_hash`/salt are never included (`security.md`) — a restored
install always requires the user to re-enter/re-set their PIN.

**Per-module export handlers, via the existing plugin contract:** the
top-level export orchestrator (in `core/`, not any single module) builds
this envelope by iterating `habitModules` (`architecture.md`'s registration
list) and calling each module's own `exportData()`, nesting the result
under `modules[moduleId]`. This is the same "one shared list, zero
per-module branching in core code" pattern the dashboard and router already
use — a future `SleepModule` automatically gets an entry in this envelope
the moment it's added to `habitModules`, with no change to the export
orchestrator itself.

## Import

**Validation, in order:**
1. Parse JSON, confirm the top-level envelope shape (`schemaVersion`,
   `exportedAt`, `appVersion`, `modules`, `common` keys present).
2. Check `schemaVersion` against the app's current supported version.
   - If the file's version is **older**, run it through a migration chain —
     one pure function per version step (`migrateV1ToV2`, `migrateV2ToV3`,
     ...), each transforming the JSON structure forward one step, the same
     "one small step at a time" shape as a normal DB schema migration.
   - If the file's version is **newer** than the app supports, reject with
     a clear "this backup was made with a newer version of the app, please
     update the app first" error — there is no forward-compatible
     downgrade path, and inventing one for a hypothetical future version
     this document can't see would be pure speculation.
3. Per-module schema spot-check (right fields present, right types) before
   any write begins — fail the whole import with a clear message rather
   than partially importing a corrupt file.

**Merge vs. replace — recommendation: replace, with an explicit
confirmation screen, for v1.**

**Why merge is deferred, not just "not built yet":** a real merge (import
file + existing local data, reconciling rows that exist in both, by
`updatedAt`, per `offline-strategy.md`) is conflict-resolution logic —
exactly the piece `offline-strategy.md` explicitly defers as out of scope
until real multi-device sync is prioritized. Building merge logic for
import now would mean building sync's hardest problem early, for a feature
whose primary real-world use case (restoring a backup after a data-loss
event, or onto a fresh install) has an *empty* local database to begin
with anyway — where "replace" and "merge" produce an identical result. A
plain replace (wipe local tables inside a single transaction, then insert
every row from the file) is smaller, simpler, and correct-by-construction
for that primary use case; the confirmation screen ("this will replace all
current data on this device — continue?") is what protects the one
secondary case (importing over data the user actually wanted to keep)
without building conflict resolution to handle it silently.

## Future Google Drive backup — the seam, not the implementation

**Design, not built:**

```dart
abstract class BackupTarget {
  String get id;                       // 'local_file' (v1.1) | 'google_drive' (future)
  Future<void> upload(File exportFile);
  Future<File> download();
  Future<DateTime?> lastBackupAt();
}
```

The export/import pipeline above (envelope shape, validation, migration
chain, replace-with-confirmation) is **entirely target-agnostic** — it
produces/consumes a single `File`. `BackupTarget` is the one seam a future
Google Drive integration plugs into: a `LocalFileBackupTarget`
(`upload` = share-sheet/file-picker save, `download` = file-picker open)
ships as the v1.1 candidate; a `GoogleDriveBackupTarget` (`upload`/
`download` via the Drive API, `lastBackupAt` from Drive file metadata)
is a pure addition later — no change to the envelope format, the
validation logic, or any module's `exportData()`/`importData()`. This
mirrors `HabitModule`'s plugin shape exactly: one small interface, one
registration point, zero edits to existing code when a new implementation
is added — the same architectural pattern applied to a second axis
(backup destinations) instead of habit modules.

# Implementation Plan: Multi-Device Sync

**Spec:** `02-multi-device-sync-design.md`
**Complexity:** L · **Estimated effort:** 8-10 days
**Depends on:** Spec 01 (Drive backup), spec 07 (entitlements)

---

## Task 1: Add `sync_state` Drift table

**File:** `lib/core/database/app_database.dart`

Create `lib/core/sync/sync_state_table.dart`:

```dart
class SyncState extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text()();
  IntColumn get lastSyncAt => integer().nullable()();
  TextColumn get syncBackend => text()();
  IntColumn get pendingChangesCount => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}
```

Add to `AppDatabase`'s table list.

**Test:** Migration test.

---

## Task 2: Create device identity service

**File:** `lib/core/sync/device_identity.dart`

- `Future<String> getOrCreateDeviceId()` — generates a UUID v7 on first
  run, stores in `flutter_secure_storage`, returns on subsequent calls.
- `String get currentDeviceId` — synchronous getter for the cached ID.

**Test:** Unit test for generation and persistence.

---

## Task 3: Create `SyncStateRepository`

**File:** `lib/core/sync/sync_state_repository.dart`

- `upsertSyncState(SyncStateCompanion)` — insert/update.
- `getSyncState()` → `SyncState?` — current device's sync state.
- `updateLastSyncAt(DateTime)` — update timestamp.
- `updatePendingCount(int)` — update pending changes count.

**Test:** CRUD tests.

---

## Task 4: Design sync transport abstraction

**File:** `lib/core/sync/sync_transport.dart`

Abstract interface for the sync backend:

```dart
abstract class SyncTransport {
  Future<SyncSnapshot> pullChanges(DateTime since, String deviceId);
  Future<void> pushChanges(SyncDelta delta, String deviceId);
  Future<void> fullSync(SyncSnapshot snapshot, String deviceId);
}
```

**File:** `lib/core/sync/sync_models.dart`

Data models for sync:
- `SyncSnapshot` — full state for a module (rows + metadata).
- `SyncDelta` — changed rows since last sync (created/updated/deleted).
- `SyncRow` — a single row with table name, id, payload, `updated_at`,
  `deleted_at`.

---

## Task 5: Implement LWW conflict resolution

**File:** `lib/core/sync/conflict_resolver.dart`

Last-write-wins resolution:
- `SyncRow resolve(SyncRow local, SyncRow remote)` — compare
  `updated_at`, return the newer one.
- `List<SyncRow> resolveBatch(List<SyncRow> local, List<SyncRow> remote)` —
  batch resolution.

**Test:** Unit tests for conflict resolution edge cases (same timestamp,
delete vs edit, etc.).

---

## Task 6: Create sync-aware repository wrapper

**File:** `lib/core/sync/sync_repository_wrapper.dart`

Wraps the existing Drift repositories to intercept writes and queue
them for sync:

```dart
class SyncRepositoryWrapper {
  final SyncTransport transport;
  final SyncStateRepository stateRepo;

  Future<void> onRowWritten(String tableName, String rowId);
  Future<void> syncPendingChanges();
}
```

- `onRowWritten` — called after any module write, increments pending
  count.
- `syncPendingChanges` — pulls remote changes, resolves conflicts,
  pushes local changes.

---

## Task 7: Integrate sync into module repositories

For each module (Water, Medicine, Prayer), add sync hooks:
- After any write in the repository, call `SyncRepositoryWrapper.onRowWritten()`.
- The module's `exportData()`/`importData()` are reused for full sync.

**Files:** Modify `water_repository_impl.dart`, `medicine_repository_impl.dart`,
`prayer_repository_impl.dart`.

---

## Task 8: Create background sync process

**File:** `lib/core/sync/background_sync_service.dart`

Uses WorkManager (Android) and background fetch (iOS) for periodic sync:
- `registerBackgroundSync()` — schedule periodic sync tasks.
- `@pragma('vm:entry-point')` callback for WorkManager.
- Sync frequency: every 15 minutes when online, with exponential backoff
  on failure.

---

## Task 9: Create sync settings screen

**File:** `lib/features/settings/presentation/screens/sync_settings_screen.dart`

UI for:
- Enable/disable sync toggle.
- Sync status (last synced, pending changes).
- "Sync Now" manual trigger.
- Device list (showing connected devices).
- "Sign Out" to disconnect sync.

---

## Task 10: Add sync status to dashboard

Show sync status indicator on the dashboard:
- Green dot: synced recently.
- Yellow dot: syncing in progress.
- Red dot: sync failed.
- Gray dot: sync disabled.

---

## Task 11: Add entitlement gate

Wire spec 07's entitlement check. Subscription required (not lifetime).

---

## Task 12: Add localization strings

en/bn ARB keys for all sync-related UI text.

---

## Task 13: Handle first-sync migration

**File:** `lib/core/sync/first_sync_handler.dart`

Orchestrates the first-sync flow:
1. Export all module data.
2. Upload to sync backend.
3. Mark sync as enabled.

---

## Review checklist

- [ ] Sync preserves data integrity across devices.
- [ ] LWW conflict resolution handles edge cases.
- [ ] Background sync doesn't drain battery excessively.
- [ ] First-sync migration works correctly.
- [ ] Offline changes sync when reconnected.
- [ ] Prayer location settings stay per-device.
- [ ] Entitlement gate works for non-subscribers.

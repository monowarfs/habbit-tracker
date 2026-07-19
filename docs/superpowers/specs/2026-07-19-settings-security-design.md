# Settings, PIN lock, export/import — design

Run: implements FR-C-04/05/06 (`docs/product/functional-requirements.md`),
D-15 (`docs/product/decisions.md`), `docs/strategies/security.md`,
`docs/strategies/backup-import-export.md`, and
`docs/habit-tracker-prompts/12-impl-settings-security.md`'s scope. One run,
full slice: core security services, core backup orchestration, Settings
presentation, notification-troubleshooting-adjacent Share Logs action,
localization — the same "whole thing in one pass" shape Medicine and Prayer
took (`docs/superpowers/specs/2026-07-18-medicine-module-design.md`,
`2026-07-19-prayer-module-design.md`).

## Scope decisions (resolved during brainstorming)

- **Lockout backoff — conflict resolved in favor of `security.md`.**
  `docs/product/app-flow.md`'s PIN Unlock Flow section (step 3) states "no
  lockout counter in v1.0" — an older product doc.
  `docs/strategies/security.md` (written later, cites D-15, cross-referenced
  by this run's own prompt scope item 2) fully designs a failed-attempt
  backoff table. This spec follows `security.md`/the prompt, the same
  precedent Prayer's spec used when an earlier brief line conflicted with
  the committed status model. `app-flow.md` step 3 is stale and should be
  corrected to match this document when this run lands.
- **New route `/settings/data`.** `docs/product/navigation-map.md`'s
  Settings route table has `/settings/pin`, `/settings/language`,
  `/settings/theme`, `/settings/notifications`, `/settings/about` but no
  home for export/import/share-logs. Adding `/settings/data` as the natural
  fourth section — `navigation-map.md` should gain this row when this run
  lands.
- **Import wizard is one screen with internal step state** (pick file →
  validate → preview counts → confirm → progress → result), not a route per
  step — simpler back-button handling, no wizard-state-in-the-URL problem
  to solve for a single-use, rarely-navigated-away-from flow.
- **Biometric and screen-privacy toggles live on `/settings/pin`**, not
  their own routes — both are gated on "PIN already enabled"
  (`security.md`), so co-locating avoids a toggle screen that's
  disabled/hidden most of the time.
- **Screen privacy via `screen_protector`**, one plugin covering both
  Android `FLAG_SECURE` and iOS resign-active blur — matches
  `security.md`'s exact two asks in one dependency instead of a
  hand-rolled platform channel. Not pub.dev-freshness-verified as part of
  this spec (unlike the deps `security.md` already vetted) — verify at
  implementation time per this project's standing convention.
- **Import's "leave existing data untouched on failure" is satisfied by a
  single Drift `db.transaction()`**, not a separate staging-table swap —
  Drift auto-rolls-back on any exception inside the transaction, and all
  validation (schema/version/spot-check) runs *before* the transaction
  opens, so a malformed file never reaches the DB layer at all. This is
  the "per DB capability" the prompt's DoD leaves open, resolved to the
  simpler of the two options since it fully satisfies the requirement.

## New dependencies (`pubspec.yaml`)

Already vetted in `security.md`/`error-handling-logging.md` (reused as-is):
- `flutter_secure_storage` (^10.3.1) — PIN hash/salt/lockout state.
- `pointycastle` (^4.0.0) — PBKDF2-HMAC-SHA256.
- `local_auth` (^3.0.2) — biometric unlock.
- `share_plus` (^13.2.1) — export share/save, log sharing (already used by
  the existing `logFilesForSharing()` groundwork).

New, not yet freshness-checked — verify on pub.dev at implementation time:
- `screen_protector` — `FLAG_SECURE` (Android) + resign-active blur (iOS).
- `file_picker` — import's "pick a JSON file" step.
- `package_info_plus` — About screen's app version display.

## Domain / core additions

### `lib/core/security/` (new — parallel to `lib/core/notifications/`)

App-wide, not module-owned — PIN gating is a router/app-shell concern, not
a `HabitModule`.

- **`pin_hash.dart`** — pure, no I/O:
  ```dart
  ({String salt, String hash}) hashPin(String pin);
  bool verifyPin(String pin, {required String salt, required String hash});
  ```
  PBKDF2-HMAC-SHA256 via `pointycastle`, random salt per `hashPin` call,
  ≥100,000 iterations (`security.md`'s floor — tuned at implementation time
  against the reference device classes in `non-functional-requirements.md`
  so verification stays under ~100ms; lower only if that budget is missed,
  never below what keeps brute-force-by-hand infeasible).
- **`backoff.dart`** — pure:
  ```dart
  Duration calculateBackoffDelay(int consecutiveFailedAttempts);
  ```
  Exact table from `security.md`: 1-3 → `Duration.zero`, 4 → 5s, 5 → 30s,
  6+ → doubles each additional attempt, capped at 5 minutes.
- **`pin_lock_service.dart`** — the sole `flutter_secure_storage` importer
  (mirrors `notification_service.dart`'s "one file owns the plugin" shape).
  Stores: salt, hash, `failedAttemptCount`, `lastFailedAttemptAt`,
  `lastBackgroundedAt`. Exposes read/write for each, plus `clearAll()` (the
  Forgot-PIN reset's secure-storage half).
- **`pin_lock_controller.dart`** (Riverpod, `lib/core/security/`) — the
  locked/unlocked state machine:
  ```dart
  bool get isLocked; // derived from pinEnabled + elapsed-since-backgrounded
                      // vs pinLockTimeoutSeconds, using clock.now()
  Future<bool> verify(String pin);      // hash-check + backoff bookkeeping
  Future<void> setPin(String pin);      // first-time set
  Future<void> changePin(String oldPin, String newPin);
  Future<void> disablePin(String pin);  // requires re-entry, not a bare toggle
  Future<void> resetAllData();          // Forgot-PIN: wipe DB file + clearAll()
  Duration? get currentBackoff;         // for the countdown UI
  ```
  Consumes `package:clock`'s `clock.now()` (never `DateTime.now()`, per this
  project's existing convention) so timeout/backoff logic is unit-testable
  with an injected fixed clock, same as `localDayKey()`.
- **`biometric_service.dart`** — thin wrap over `local_auth`:
  `isAvailable()`, `authenticate()` → bool. A failed/unavailable check is
  the caller's cue to fall back to PIN entry, never a degraded no-lock
  state (`security.md`).
- **`screen_privacy_service.dart`** — thin wrap over `screen_protector`:
  `enable()`/`disable()`, called from the PIN settings screen's toggle and
  once at app start if the setting is already on.

### `lib/core/backup/` (new)

- **`backup_envelope.dart`** — the JSON shape from
  `backup-import-export.md`, as a plain (not Freezed — this is a
  serialization boundary type, not a domain entity) class:
  ```dart
  class BackupEnvelope {
    const BackupEnvelope({
      required this.schemaVersion,
      required this.exportedAt,
      required this.appVersion,
      required this.modules, // Map<String, Map<String, Object?>>
      required this.common,  // {appSettings, modules, achievements}
    });
  }
  static const currentSchemaVersion = 1;
  ```
- **`export_orchestrator.dart`** —
  `Future<BackupEnvelope> buildExport(List<HabitModule> modules, AppDatabase db)`:
  iterates `modules`, calls each `exportData()`, nests under
  `envelope.modules[module.id]`; builds `common` from `AppSettings` (via
  `SettingsRepository`, `pinEnabled`/`pinLockTimeoutSeconds` included,
  hash/salt never — those aren't in `AppSettings` at all per D-15), the
  `modules` enable/position table, and `achievements`. Pretty-print is a
  `JsonEncoder.withIndent`/compact toggle at the point of writing the file,
  not a separate code path.
- **`import_orchestrator.dart`** —
  ```dart
  Future<Result<ImportPreview>> validateImport(String rawJson);
  Future<Result<void>> applyImport(BackupEnvelope envelope, List<HabitModule> modules, AppDatabase db);
  ```
  `validateImport`: parse → envelope-shape check → `schemaVersion` check
  (newer than `currentSchemaVersion` → reject with the "update the app
  first" message; older → run the migration chain, currently empty since
  only v1 exists — the chain's function signature
  (`Map<String, Object?> Function(Map<String, Object?>)` per version step)
  is defined now so a future v2 slots in without touching this orchestrator)
  → per-module spot-check. Returns an `ImportPreview` (counts per module)
  on success, `AppException.validation` on any failure — no DB touched yet.
  `applyImport`: `db.transaction()` wrapping a wipe of every table each
  module owns (via a new `HabitModule.wipeData()` — see contract change
  below) followed by every module's `importData(envelope.modules[id])`,
  plus the `common` block's own repositories. Any thrown exception inside
  rolls the whole transaction back; caller reports `AppException.storage`.
- **`backup_target.dart`** — the seam from `backup-import-export.md`:
  ```dart
  abstract class BackupTarget {
    String get id;
    Future<void> upload(File exportFile);
    Future<File> download();
  }
  ```
  `local_file_backup_target.dart` — the only implementation this run ships:
  `upload` = `share_plus`'s share sheet (covers both "share" and "save to
  Files/Downloads" since that's already in the OS sheet); `download` =
  `file_picker`'s single-file JSON pick. A future `GoogleDriveBackupTarget`
  is a pure addition later per the strategy doc, no change here.

### `HabitModule` contract change

One addition beyond the existing `exportData`/`importData` (already
declared, unused until now):
```dart
/// Deletes every row this module owns, inside the caller's transaction —
/// the wipe half of import's replace semantics. Never called standalone
/// outside `import_orchestrator.dart`.
Future<void> wipeData();
```
Implemented by Water/Medicine/Prayer this run (each already knows its own
table list from `data/repositories/*_repository_impl.dart`). `exportData`/
`importData` get their first real bodies this run too — each module
serializes/deserializes its own tables per `data-models.md`'s JSON-column
mapping (ISO-8601 timestamps, soft-deleted rows included, `RepeatRule`'s
flat DB shape for Medicine per that doc's existing note).

## Presentation (`lib/features/settings/presentation/`)

Existing `settings_home_screen.dart`'s flat `ListView` (theme + language +
notification-reliability banner) is restructured into a sectioned home
screen — Appearance, Language, Notifications, Security, Data, About — each
row pushing its `navigation-map.md` route. Theme/language segmented
controls move to their own `/settings/theme`/`/settings/language` screens
(currently inline on the home screen); the exact-alarm reliability banner
and its `/settings/notifications` link stay as-is.

- **`/settings/pin`** — enable/disable toggle (enabling pushes
  `/settings/pin/set`; disabling requires PIN re-entry first — no bare
  flip), timeout dropdown (immediately/1min/5min/30min → `0`/`60`/`300`/
  `1800` seconds, matching the existing `pinLockTimeoutSeconds` column),
  biometric toggle (hidden if `biometric_service.isAvailable()` is false;
  disabled/hidden entirely if PIN isn't enabled), screen-privacy toggle
  (same PIN-enabled gate).
- **`/settings/pin/set`** — custom 10-key numeric keypad widget (no
  package — a `GridView` of digit buttons), enter → confirm (must match,
  mismatch shakes and restarts confirm step) → `pin_lock_controller
  .setPin()`/`changePin()`. Shown once during first enable, and again when
  the user taps "change PIN".
- **`/lock`** (top-level `GoRouter` redirect target, replacing the current
  `redirect: (context, state) => null` stub) — PIN entry keypad, shake +
  error message on wrong PIN, backoff countdown replacing the keypad with a
  "try again in Ns" message when `currentBackoff > Duration.zero`,
  biometric prompt offered up front if enabled and available. "Forgot PIN"
  link → `/lock/reset`.
- **`/lock/reset`** — confirmation screen restating FR-C-04's up-front
  warning, a single confirm action calling
  `pin_lock_controller.resetAllData()`, then routing to
  `/onboarding/language` (fresh start, matching a first-ever launch).
- **`/settings/data`** — three actions: **Export** (builds the envelope,
  shows a brief progress indicator, opens the share sheet via
  `LocalFileBackupTarget.upload`; a pretty-print toggle before export),
  **Import** (the single wizard screen described above), **Share
  diagnostic logs** (reuses `logFilesForSharing()`, shares via
  `share_plus` — this was already scaffolded in `app_logger.dart` with a
  comment pointing at this run).
- **`/settings/about`** — app version (`package_info_plus`), licenses via
  Flutter's built-in `showLicensePage`/`LicenseRegistry` (no package
  needed — auto-collects from bundled packages' `LICENSE` files),
  privacy-policy text (a static localized string screen — no external
  fetch, matching the offline-first requirement).

## Router integration (`lib/core/router/app_router.dart`)

The `redirect` stub becomes a real check against
`pinLockControllerProvider`'s `isLocked`, redirecting to `/lock` (preserving
the originally-requested location via GoRouter's `state.uri` so unlock
returns there — the FR-C-09 "deep link through the lock guard" behavior).
`HabitTrackerApp`'s existing `WidgetsBindingObserver` (already re-plans
notifications on resume) gains one more line on `AppLifecycleState.paused`:
record `lastBackgroundedAt` via `pin_lock_service`. No new observer.

## Error handling

No new `AppException` variants. Import failures map to the existing
taxonomy: malformed JSON / wrong envelope shape / unsupported
`schemaVersion` / failed per-module spot-check → `AppException.validation`
(field = the offending key, message = the specific reason — "malformed
JSON" and "unsupported schema version" get distinct messages per the DoD's
requirement for each rejection to be individually clear); a transaction
failure during `applyImport` → `AppException.storage`. PIN verification
failure is not an exception — `verify()` returns `false` and the UI reads
`currentBackoff` for the countdown; there's nothing exceptional about
entering the wrong PIN.

## Testing / Definition of Done

- `pin_hash_test.dart` — hash/verify round-trip, wrong PIN rejected, salt
  uniqueness across calls (never stores plaintext — grep-style assertion
  the stored value never equals the raw PIN).
- `backoff_test.dart` — exact delay table from `security.md`, boundary
  values (3→0, 4→5s, 5→30s, 6→60s, 7→120s, capped at 300s).
- `pin_lock_controller_test.dart` — resume-timeout via injected `clock`
  (locked exactly at/after timeout, not before), lockout state machine
  (failed-count increments/reset-on-success), `resetAllData` clears both
  secure storage and triggers a DB wipe.
- `backup_envelope_test.dart` + one round-trip test seeding all three
  modules (`water`/`medicine`/`prayer`) + common data → `buildExport` →
  wipe every table → `applyImport` → assert full equality against the
  seeded fixtures. Doubles as each module's `exportData`/`importData`/
  `wipeData` contract-compliance check, per the DoD.
- Import-rejection tests: malformed JSON, wrong `schemaVersion` (both
  older-unsupported and newer-than-app), truncated file — each asserts a
  distinct, specific error message and that the DB is provably unchanged
  (row counts before/after).
- Manual: biometric unlock on a real device (can't automate an OS
  biometric prompt), screen-privacy check (recent-apps thumbnail on
  Android, app-switcher blur on iOS — both need real OS chrome, not a
  widget test), full Bangla pass on every new screen.
- `flutter analyze` clean, `flutter test` green.
- Commit: `feat(settings): settings, pin lock, export/import`.

## Localization

Full en/bn for every new string: PIN setup/change/disable copy, lockout
countdown messages, Forgot-PIN warning and reset confirmation, export/
import wizard steps and error messages, About screen's privacy-policy
text, Settings home's new section headers.

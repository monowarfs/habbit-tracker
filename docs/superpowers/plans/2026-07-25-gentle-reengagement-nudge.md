# Gentle Re-Engagement Nudge After Inactivity — Implementation Plan

**Spec:** `docs/superpowers/specs/09-retention/02-gentle-reengagement-nudge-design.md`
**Date:** 2026-07-25
**Status:** Ready for implementation

---

## Architecture overview

```
┌──────────────────────────────────────────────────────────┐
│  main.dart / HabitTrackerApp.didChangeAppLifecycle       │
│  → checkReEngagementNudge(db)                            │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  core/nudges/reengagement_trigger.dart                   │
│  reads lastActivityAt, installDate, nudgeSentAfter       │
│  computes daysSinceActivity, daysSinceInstall            │
│  returns ReEngagementAction { none | showNudge | banner }│
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  core/nudges/reengagement_nudge.dart                     │
│  builds a system-level PendingNotification               │
│  injects into notification planner as extra candidate    │
│  records nudgeSentAfter in notification_ledger           │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  core/nudges/last_activity_repository.dart               │
│  cross-module query: most recent write across            │
│  water_logs, medicine_doses, prayer_records              │
│  excludes paused-status days                             │
└──────────────────────────────────────────────────────────┘
```

---

## Resolved dependencies

All from Spec 01 (yearly recap) — assumed already built:

| Dep | Status |
|-----|--------|
| `installDate` on `AppSettings` | Spec 01 T1-T2 |
| `ModuleDayStatusKind.paused` | Spec 01 T3 |
| Schema migration v10 | Spec 01 T1 |

---

## Implementation tasks

### T1: `last_activity_at` + `nudge_sent_after` on `AppSettings`

**Files:**
- `lib/core/database/tables/app_settings_table.dart` — add two columns
- `lib/features/settings/domain/entities/app_settings.dart` — no domain exposure needed (implementation detail)
- `lib/features/settings/data/repositories/settings_repository_impl.dart` — add `updateLastActivityAt`, `updateNudgeSentAfter`

**Table columns:**
```dart
IntColumn get lastActivityAt => integer().nullable()();
IntColumn get nudgeSentAfter => integer().nullable()();  // epoch millis of last activity when nudge was sent
```

**Migration (from < 11):**
```dart
if (from < 11) {
  await m.addColumn(appSettingsTable, appSettingsTable.lastActivityAt);
  await m.addColumn(appSettingsTable, appSettingsTable.nudgeSentAfter);
  // Seed lastActivityAt to now so timer starts fresh post-migration
  await customUpdate(
    'UPDATE app_settings SET last_activity_at = ${DateTime.now().toUtc().millisecondsSinceEpoch} '
    'WHERE last_activity_at IS NULL',
  );
}
```

**Tests:** Migration test, repository update methods.

---

### T2: `LastActivityRepository` — cross-module last-write query

**Files:**
- `lib/core/nudges/last_activity_repository.dart` — **new file**

```dart
class LastActivityRepository {
  const LastActivityRepository(this._db);
  final AppDatabase _db;

  /// Most recent write timestamp across water_logs, medicine_doses,
  /// prayer_records. Excludes rows where the module was paused on that day.
  Future<DateTime?> mostRecentActivity();
}
```

**Query strategy:** Run three `SELECT MAX(created_at)` queries (one per table), take the max of the three. This is O(1) per table (indexed on `created_at`), not a full table scan.

**Tests:** `test/core/nudges/last_activity_repository_test.dart` — verify correct max across tables, empty tables, paused-day exclusion.

---

### T3: Re-engagement trigger logic (pure)

**Files:**
- `lib/core/nudges/reengagement_trigger.dart` — **new file**, pure logic

```dart
enum ReEngagementAction {
  none,
  showNotification,
  showDashboardBanner,
}

ReEngagementAction checkReEngagement({
  required DateTime? lastActivityAt,
  required DateTime? installDate,
  required DateTime? nudgeSentAfter,
  required bool notificationsEnabled,
  required DateTime now,
});
```

**Logic:**
1. If `lastActivityAt == null` or `installDate == null`, return `none`.
2. `daysSinceInstall = now.difference(installDate).inDays`. If `< 7`, return `none` (grace period).
3. `daysSinceActivity = now.difference(lastActivityAt).inDays`. If `< 7`, return `none`.
4. `daysSinceNudge = nudgeSentAfter != null ? now.difference(nudgeSentAfter).inDays : 999`. If `daysSinceActivity < daysSinceNudge`, return `none` (nudge already sent for this lapse — user hasn't returned yet).
5. If `!notificationsEnabled`, return `showDashboardBanner`.
6. Return `showNotification`.

**Tests:** `test/core/nudges/reengagement_trigger_test.dart` — pure unit tests covering all branches.

---

### T4: System-level notification candidate builder

**Files:**
- `lib/core/nudges/reengagement_nudge.dart` — **new file**

```dart
/// Builds a system-level PendingNotification for the re-engagement nudge,
/// or null if no nudge is due. This is a candidate the planner adds
/// alongside module-sourced candidates.
PendingNotification? buildReEngagementNudge({
  required DateTime lastActivityAt,
});
```

**Nudge content:**
- Title: localized "We missed you!" / "আমরা আপনাকে মিস করেছি!"
- Body: localized "Pick back up where you left off?" / "যেখানে ছেড়ে গেছেন সেখান থেকে শুরু করুন?"
- Source type: `'reengagement_nudge'`
- Deep link: `'/'` (dashboard)
- Quiet hours suppressible: `true`

---

### T5: Wire trigger into app lifecycle + notification planner

**Files:**
- `lib/core/nudges/reengagement_check.dart` — **new file**, top-level wiring function
- `lib/main.dart` — add `unawaited(checkReEngagementNudge(db))` in `didChangeAppLifecycleState(resumed)`
- `lib/core/notifications/notification_planner.dart` — extend `planNotifications` to accept `extraCandidates: List<ModulePendingNotification>` parameter

**`checkReEngagementNudge` flow:**
1. Read `lastActivityAt`, `installDate`, `nudgeSentAfter` from settings.
2. Call `checkReEngagement(...)`.
3. If `showNotification`: build nudge via `buildReEngagementNudge`, inject into planner, record `nudgeSentAfter` in ledger.
4. If `showDashboardBanner`: set a Riverpod state that the Dashboard reads to show a banner.

**Dashboard banner fallback:**
- `lib/features/dashboard/presentation/widgets/reengagement_banner.dart` — **new file**, simple `MaterialBanner` shown when re-engagement state is active.
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` — conditionally show banner at top.

**Tests:**
- `test/core/nudges/reengagement_check_test.dart` — integration test
- `test/features/dashboard/presentation/screens/dashboard_screen_test.dart` — banner visibility test

---

### T6: Settings toggle + activity tracking on writes

**Files:**
- `lib/features/settings/domain/entities/app_settings.dart` — add `@Default(true) bool reengagementNudgeEnabled`
- `lib/features/settings/domain/repositories/settings_repository.dart` — add `updateReengagementNudgeEnabled`
- `lib/features/settings/data/repositories/settings_repository_impl.dart` — implement
- `lib/features/water/presentation/providers/water_controller.dart` — call `updateLastActivityAt` after every log
- `lib/features/medicine/presentation/controllers/medicine_controller.dart` — call `updateLastActivityAt` after every dose log
- `lib/features/prayer/presentation/providers/prayer_providers.dart` — call `updateLastActivityAt` after every prayer log

**Activity tracking strategy:** Each module's write path already calls its repository. Add a `notifyActivity()` call that updates `last_activity_at` in settings. This is a one-liner per module, not a cross-module event bus.

**Tests:** Settings toggle test, activity tracking integration test.

---

### T7: Localization

**Files:**
- `lib/core/l10n/app_en.arb` — ~8 new keys
- `lib/core/l10n/app_bn.arb` — Bangla translations

**Keys:**
- `reengagementNudgeTitle` — "We missed you!"
- `reengagementNudgeBody` — "Pick back up where you left off?"
- `reengagementBannerTitle` — "Welcome back!"
- `reengagementBannerBody` — "It's been a while. Tap to get started."
- `reengagementBannerDismiss` — "Dismiss"
- `reengagementSettingsLabel` — "Re-engagement reminders"
- `reengagementSettingsDescription` — "Get a gentle reminder after a week of inactivity"

---

## Task sequencing

```
T1 (schema) ──→ T2 (last activity repo) ──→ T3 (trigger logic)
                                               │
T6 (activity tracking) ────────────────────────┘
                                               │
T4 (nudge builder) ──→ T5 (wiring) ──→ T7 (i18n)
```

---

## Commit plan

| Commit | Tasks | Message |
|--------|-------|---------|
| 1 | T1 | `feat(db): add last_activity_at and nudge_sent_after to app_settings (migration 11)` |
| 2 | T2 | `feat(nudges): add LastActivityRepository for cross-module activity query` |
| 3 | T3 | `feat(nudges): add re-engagement trigger logic (pure)` |
| 4 | T4 | `feat(nudges): add system-level re-engagement notification builder` |
| 5 | T5 | `feat(nudges): wire re-engagement check into app lifecycle and planner` |
| 6 | T6 | `feat(nudges): add settings toggle and activity tracking on module writes` |
| 7 | T7 | `feat(i18n): add en/bn strings for re-engagement nudge` |

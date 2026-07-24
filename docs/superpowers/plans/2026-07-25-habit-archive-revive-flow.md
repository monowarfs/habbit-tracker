# Habit Archive with "Revive" Flow — Implementation Plan

**Spec:** `docs/superpowers/specs/09-retention/03-habit-archive-revive-flow-design.md`
**Date:** 2026-07-25
**Status:** Ready for implementation

---

## Architecture overview

```
┌──────────────────────────────────────────────────────────┐
│  Water goal detail / Medicine schedule detail            │
│  → "Archive" button → confirmation dialog                │
│  → archiveSchedule() / archiveGoal()                     │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  Module repository (Water/Medicine)                      │
│  sets archived_at = now                                  │
│  cancels pending notifications via NotificationService   │
│  marks in-flight doses as skipped (Medicine only)        │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  dayStatus() returns ModuleDayStatusKind.paused          │
│  for days where ALL active items are archived            │
│  streak calculators skip paused days                     │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  Archived items screen (Settings)                        │
│  lists items with archived_at set                        │
│  "Revive" button → re-activates, re-registers notifs     │
└──────────────────────────────────────────────────────────┘
```

---

## Resolved dependencies

| Dep | Source |
|-----|--------|
| `ModuleDayStatusKind.paused` | Spec 01 T3 |
| Pause-aware streak calculators | Spec 01 T3 |
| Schema migration v10 (installDate) | Spec 01 T1 |

---

## Implementation tasks

### T1: Schema migration — `archived_at` columns

**Files:**
- `lib/features/water/data/tables/water_goals_table.dart` — add `IntColumn get archivedAt => integer().nullable()();`
- `lib/features/medicine/data/tables/medicine_schedules_table.dart` — add `IntColumn get archivedAt => integer().nullable()();`
- `lib/core/database/app_database.dart` — bump `schemaVersion` to 12, add `if (from < 12)` block

**Migration (from < 12):**
```dart
if (from < 12) {
  await m.addColumn(waterGoalsTable, waterGoalsTable.archivedAt);
  await m.addColumn(medicineSchedulesTable, medicineSchedulesTable.archivedAt);
}
```

**Tests:** Migration test verifying new columns exist and existing data is untouched.

---

### T2: Water — archive/revive logic

**Files:**
- `lib/features/water/domain/entities/water_goal.dart` — add `DateTime? archivedAt` to Freezed class
- `lib/features/water/data/repositories/water_repository_impl.dart` — add `archiveGoal(String goalId)`, `reviveGoal(String goalId)`, `archivedGoals()`
- `lib/features/water/domain/usecases/resolve_goal_for_date.dart` — exclude archived goals from active resolution

**`archiveGoal` logic:**
1. Set `archived_at` to `clock.now().toUtc().millisecondsSinceEpoch`.
2. Cancel all pending notifications for this goal via `NotificationService.cancel()`.
3. No dose reconciliation needed (Water has no in-flight "doses").

**`reviveGoal` logic:**
1. Set `archived_at` to `null`.
2. Re-register notifications (trigger planner on next app resume).
3. Fresh streak starts from revive date.

**Tests:** `test/features/water/data/repositories/water_repository_impl_test.dart` — archive, revive, archivedGoals list, streak exclusion.

---

### T3: Medicine — archive/revive logic

**Files:**
- `lib/features/medicine/domain/entities/medicine.dart` — add `DateTime? archivedAt` to `MedicineSchedule` Freezed class
- `lib/features/medicine/data/repositories/medicine_repository_impl.dart` — add `archiveSchedule(String scheduleId)`, `reviveSchedule(String scheduleId)`, `archivedSchedules()`
- `lib/features/medicine/domain/usecases/dose_status.dart` — no changes needed (already handles `due`/`upcoming` correctly)

**`archiveSchedule` logic:**
1. Set `archived_at` to `clock.now().toUtc().millisecondsSinceEpoch`.
2. Cancel all pending notifications for this schedule via `NotificationService.cancel()`.
3. Mark all `due`/`upcoming` doses for today (and within grace window) as `skipped`.

**`reviveSchedule` logic:**
1. Set `archived_at` to `null`.
2. Re-enter into notification pipeline.
3. Fresh streak starts from revive date.

**Tests:** `test/features/medicine/data/repositories/medicine_repository_impl_test.dart` — archive with in-flight dose cancellation, revive, archived list.

---

### T4: `dayStatus()` returns `paused` for archived items

**Files:**
- `lib/features/water/water_module.dart` — in `dayStatus()`, if all active goals are archived on a given day, return `ModuleDayStatusKind.paused`
- `lib/features/medicine/medicine_module.dart` — in `dayStatus()`, if all active schedules are archived on a given day, return `ModuleDayStatusKind.paused`

**Logic:** Each module's `dayStatus(DateRange range)` already walks each day. For each day, check if any non-archived goal/schedule was active. If none were, return `paused` instead of `none`.

**Tests:** Verify `dayStatus` returns `paused` for days where all items were archived.

---

### T5: "Archived Items" screen + revive UI

**Files:**
- `lib/features/water/presentation/screens/archived_goals_screen.dart` — **new file**
- `lib/features/medicine/presentation/screens/archived_schedules_screen.dart` — **new file**
- `lib/features/water/presentation/screens/water_settings_screen.dart` — add "Archived Goals" link
- `lib/features/medicine/presentation/screens/medicine_home_screen.dart` — add "Archived Schedules" link (via settings)

**Archived items screen:**
- `ListView` of archived items with name, archive date, and "Revive" button.
- Tap "Revive" → confirmation dialog → calls `reviveGoal()`/`reviveSchedule()`.
- Empty state: "No archived items yet."

**Archive action (on item detail screen):**
- Water: in goal detail/settings, add "Archive" button with confirmation dialog.
- Medicine: in schedule detail, add "Archive" button with confirmation dialog.
- Dialog: "Archive [item name]? You can revive it later."

**Tests:** Widget tests for archived list screen, archive button, revive flow.

---

### T6: Historical reports — "(Archived)" label

**Files:**
- `lib/core/reports/aggregate_report_usecase.dart` — no changes needed (reports read `dayStatus` which already handles archived days as `paused`)
- `lib/features/reports/presentation/screens/reports_screen.dart` — if a module has `paused` days, show "(Archived)" note

**Tests:** Verify reports correctly display archived periods.

---

### T7: Localization

**Files:**
- `lib/core/l10n/app_en.arb` — ~15 new keys
- `lib/core/l10n/app_bn.arb` — Bangla translations

**Keys:**
- `archiveAction` — "Archive"
- `archiveConfirmTitle` — "Archive {name}?"
- `archiveConfirmBody` — "You can revive it later."
- `archiveConfirmButton` — "Archive"
- `reviveAction` — "Revive"
- `reviveConfirmTitle` — "Revive {name}?"
- `reviveConfirmBody` — "This will restore your previous settings."
- `reviveConfirmButton` — "Revive"
- `archivedGoalsTitle` — "Archived Goals"
- `archivedSchedulesTitle` — "Archived Schedules"
- `archivedEmptyState` — "No archived items yet."
- `archivedLabel` — "(Archived)"

---

## Task sequencing

```
T1 (schema) ──→ T2 (water archive) ──→ T4 (dayStatus paused)
               ──→ T3 (medicine archive) ──→ T4
T2 + T3 ──→ T5 (UI)
T4 ──→ T6 (reports label)
T5 + T6 ──→ T7 (i18n)
```

---

## Commit plan

| Commit | Tasks | Message |
|--------|-------|---------|
| 1 | T1 | `feat(db): add archived_at columns to water_goals and medicine_schedules (migration 12)` |
| 2 | T2 | `feat(water): add archive/revive logic for water goals` |
| 3 | T3 | `feat(medicine): add archive/revive logic for medicine schedules` |
| 4 | T4 | `feat: dayStatus returns paused for days where all items are archived` |
| 5 | T5 | `feat: add archived items screens and revive UI for water/medicine` |
| 6 | T6 | `feat(reports): show (Archived) label for archived periods` |
| 7 | T7 | `feat(i18n): add en/bn strings for archive/revive flow` |

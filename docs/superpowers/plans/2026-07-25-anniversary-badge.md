# Anniversary Badge ("1 Year With the App") — Implementation Plan

**Spec:** `docs/superpowers/specs/09-retention/06-anniversary-badge-design.md`
**Date:** 2026-07-25
**Status:** Ready for implementation

---

## Architecture overview

```
┌──────────────────────────────────────────────────────────┐
│  main.dart / HabitTrackerApp.didChangeAppLifecycle       │
│  → evaluateAnniversaryBadges(db)                         │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  core/achievements/tenure_evaluator.dart                 │
│  reads installDate from settings                         │
│  evaluates N-year milestones (1yr, 2yr)                  │
│  awards via AchievementRepository.upsertProgress         │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│  achievements table (existing)                           │
│  milestone_value column (new) for N-year granularity     │
│  moduleId = 'core' for cross-module achievements         │
└──────────────────────────────────────────────────────────┘
```

---

## Resolved dependencies

| Dep | Source |
|-----|--------|
| `installDate` on `AppSettings` | Spec 01 T1-T2 |
| Schema migration v10 | Spec 01 T1 |

---

## Implementation tasks

### T1: Schema migration — `milestone_value` column on achievements

**Files:**
- `lib/core/database/tables/achievements_table.dart` — add `IntColumn get milestoneValue => integer().nullable()();`
- `lib/core/database/app_database.dart` — bump `schemaVersion` to 15, add `if (from < 15)` block

**Migration (from < 15):**
```dart
if (from < 15) {
  await m.addColumn(achievementsTable, achievementsTable.milestoneValue);
}
```

**Purpose:** `milestoneValue` stores the number of days for the milestone (365, 730, etc.). Existing streak achievements get `null` (not tenure-based). This avoids a separate `tenure_achievements` table.

**Tests:** Migration test.

---

### T2: Tenure evaluator (pure logic + repository integration)

**Files:**
- `lib/core/achievements/tenure_evaluator.dart` — **new file**

```dart
/// Milestone definitions for tenure-based achievements.
const tenureMilestones = [
  TenureMilestone(key: 'tenure_1_year', days: 365),
  TenureMilestone(key: 'tenure_2_year', days: 730),
];

class TenureMilestone {
  const TenureMilestone({required this.key, required this.days});
  final String key;
  final int days;
}

/// Evaluates tenure milestones against [installDate].
/// Awards any un-awarded milestones where (now - installDate) >= milestone.days.
/// Cross-module: moduleId = 'core'.
Future<void> evaluateTenureMilestones({
  required DateTime installDate,
  required AchievementRepository repository,
  required DateTime now,
});
```

**Logic:**
1. For each milestone in `tenureMilestones`:
   a. `daysSinceInstall = now.difference(installDate).inDays`.
   b. If `daysSinceInstall < milestone.days`, skip.
   c. Check `repository.byKey(milestone.key)`. If already exists (even if not unlocked), skip — don't re-evaluate.
   d. If not exists, call `repository.upsertProgress(moduleId: 'core', key: milestone.key, current: milestone.days, target: milestone.days, now: now)`.
2. This awards the badge immediately (current == target).

**Tests:** `test/core/achievements/tenure_evaluator_test.dart` — 1-year award, 2-year award, multi-milestone catch-up, no re-award.

---

### T3: Wire tenure evaluation into app lifecycle

**Files:**
- `lib/core/achievements/tenure_check.dart` — **new file**, top-level wiring function
- `lib/main.dart` — add `unawaited(evaluateTenureBadges(db))` in `didChangeAppLifecycleState(resumed)`

**`evaluateTenureBadges` flow:**
1. Read `installDate` from settings. If null, return (legacy user — set installDate to now).
2. Construct `AchievementRepository(db)`.
3. Call `evaluateTenureMilestones(installDate: installDate, repository: repo, now: clock.now())`.

**Tests:** Integration test verifying badges appear on app resume.

---

### T4: Achievement definitions for display

**Files:**
- `lib/features/water/water_module.dart` — no changes (anniversary badges are not module-owned)
- `lib/core/achievements/achievement_definitions.dart` — **new file**, defines tenure achievement display metadata

```dart
const tenureAchievementDefinitions = [
  AchievementDisplay(
    key: 'tenure_1_year',
    moduleId: 'core',
    titleKey: 'achievementTenure1YearTitle',
    descriptionKey: 'achievementTenure1YearDescription',
    icon: Icons.workspace_premium,
  ),
  AchievementDisplay(
    key: 'tenure_2_year',
    moduleId: 'core',
    titleKey: 'achievementTenure2YearTitle',
    descriptionKey: 'achievementTenure2YearDescription',
    icon: Icons.diamond,
  ),
];
```

**Note:** These are display-only definitions, not `AchievementDefinition` with `currentProgress` closures — tenure achievements are evaluated by the app-lifecycle path, not the module-write path. The achievements screen reads from the `achievements` table directly, so existing display logic works without changes.

---

### T5: Localization

**Files:**
- `lib/core/l10n/app_en.arb` — ~6 new keys
- `lib/core/l10n/app_bn.arb` — Bangla translations

**Keys:**
- `achievementTenure1YearTitle` — "1 Year Together"
- `achievementTenure1YearDescription` — "You've been with the app for a full year. Thank you for staying."
- `achievementTenure2YearTitle` — "2 Years Together"
- `achievementTenure2YearDescription` — "Two years of tracking. Your consistency is remarkable."

---

## Task sequencing

```
T1 (schema) ──→ T2 (evaluator) ──→ T3 (wiring) ──→ T5 (i18n)
T4 (definitions) ──→ T3
```

---

## Commit plan

| Commit | Tasks | Message |
|--------|-------|---------|
| 1 | T1 | `feat(db): add milestone_value column to achievements table (migration 15)` |
| 2 | T2 | `feat(achievements): add tenure milestone evaluator` |
| 3 | T3 | `feat(achievements): wire tenure evaluation into app lifecycle` |
| 4 | T4 | `feat(achievements): add tenure achievement display definitions` |
| 5 | T5 | `feat(i18n): add en/bn strings for tenure anniversary badges` |

# Yearly Wrapped Recap — Implementation Plan

**Spec:** `docs/superpowers/specs/09-retention/01-yearly-wrapped-recap-design.md`
**Date:** 2026-07-25
**Status:** Ready for implementation

---

## Architecture overview

```
┌─────────────────────────────────────────────────────┐
│  main.dart / HabitTrackerApp.didChangeAppLifecycle   │
│  → checkYearlyRecapTrigger(db)                      │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────┐
│  core/recaps/recap_trigger.dart                     │
│  reads installDate + lastRecapYear from settings    │
│  compares (now - installDate) >= 365 days           │
│  and now.year > lastRecapYear                       │
│  returns YearRecapTriggerResult                     │
└──────────────┬──────────────────────────────────────┘
               │ if trigger fires
               ▼
┌─────────────────────────────────────────────────────┐
│  core/recaps/year_summary.dart                      │
│  YearSummary Freezed class (per-module sub-objects) │
│  populated by each module's yearAggregation()       │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────┐
│  core/recaps/recap_generator.dart                   │
│  YearRecapGeneratorUseCase                          │
│  iterates modules via habitModulesProvider           │
│  calls module.yearAggregation(yearRange)            │
│  builds YearSummary, stores in recaps table         │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────┐
│  core/database/tables/recaps_table.dart             │
│  recaps table: id, yearNumber, generatedAt,         │
│  installYear, summaryJson                            │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────┐
│  presentation/                                      │
│  YearlyRecapScreen (full-screen story cards)        │
│  YearlyRecapCard (per-module card widget)           │
│  PastRecapsScreen (Settings entry, list of past)    │
└─────────────────────────────────────────────────────┘
```

---

## Resolved dependencies (shared infrastructure)

These must be built **before** or **as part of** this spec. The spec marks them as resolved dependencies; we implement them here since no other spec has claimed them yet.

### D-01: `installDate` field on `AppSettings`

| Item | Detail |
|------|--------|
| **Files** | `lib/core/database/tables/app_settings_table.dart`, `lib/features/settings/domain/entities/app_settings.dart`, `lib/features/settings/data/repositories/settings_repository_impl.dart`, `lib/core/database/app_database.dart` |
| **Action** | Add `IntColumn get installDate => integer().nullable()();` to `AppSettingsTable`. Add `DateTime? installDate` to `AppSettings` Freezed class. Add `updateInstallDate` to `SettingsRepository` interface and implementation. Add `installDate` to `_toDomain` mapper and `restoreSettings`. |
| **Migration** | `schemaVersion` → 10. `if (from < 10)` block: `addColumn(appSettingsTable, appSettingsTable.installDate)`. Seed existing installs: `UPDATE app_settings SET install_date = created_at WHERE install_date IS NULL`. This reuses the `createdAt` column (epoch millis) as the best approximation of install time for pre-existing users. |
| **Seed logic** | In `_ensureSeeded()`, set `installDate: Value(now)` for brand-new installs. |

### D-02: `ModuleDayStatusKind.paused` variant

| Item | Detail |
|------|--------|
| **Files** | `lib/core/modules/habit_module.dart` |
| **Action** | Add `paused` variant to `ModuleDayStatusKind` enum, between `missed` and `none`. No code changes needed in existing consumers — they switch on `kind` and the new variant falls through to default/`none` behavior. `longestStreak()` in `day_status_streaks.dart` already breaks on non-`complete`, so `paused` days correctly break streaks (same as `none`). We add explicit handling where needed. |

### D-03: Pause-aware streak calculators

| Item | Detail |
|------|--------|
| **Files** | `lib/core/reports/day_status_streaks.dart`, `lib/features/water/domain/usecases/calculate_water_streak.dart`, `lib/features/medicine/domain/usecases/calculate_adherence.dart`, `lib/features/prayer/domain/usecases/calculate_prayer_streak.dart` |
| **Action** | Add optional `Set<LocalDate> pausedDays = const {}` parameter to `longestStreak()`, `currentStreak()`, `CalculateWaterStreakUseCase.execute()`, `calculateAdherence()`, and `CalculatePrayerStreakUseCase.execute()`. In each, skip `pausedDays` entries (treat them like `none` — neither count nor break). This is backward-compatible: existing callers pass no `pausedDays` and get identical behavior. |

---

## Implementation tasks

### T1: Schema migration — `installDate` + `recaps` table

**Files:**
- `lib/core/database/tables/app_settings_table.dart` — add `installDate` column
- `lib/core/database/tables/recaps_table.dart` — **new file**, define `RecapsTable`
- `lib/core/database/app_database.dart` — add `RecapsTable` to `@DriftDatabase(tables: [...])`, bump `schemaVersion` to 10, add `if (from < 10)` migration block

**RecapsTable definition:**
```dart
@DataClassName('RecapRow')
class RecapsTable extends Table {
  @override
  String get tableName => 'recaps';

  TextColumn get id => text()();           // e.g. 'year_1'
  IntColumn get yearNumber => integer()();  // 1, 2, 3, …
  IntColumn get installYear => integer()(); // Gregorian year of install
  IntColumn get generatedAt => integer()(); // UTC epoch millis
  TextColumn get summaryJson => text()();   // JSON-serialized YearSummary
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Migration block (from < 10):**
```dart
if (from < 10) {
  await m.addColumn(appSettingsTable, appSettingsTable.installDate);
  await m.createTable(recapsTable);
  // Seed installDate for existing installs: reuse createdAt as best proxy
  await customUpdate(
    'UPDATE app_settings SET install_date = created_at WHERE install_date IS NULL',
  );
}
```

**Tests:** `test/core/database/migration_test.dart` — add migration-10 test that verifies `installDate` is seeded and `recaps` table exists.

---

### T2: `AppSettings` domain + repository — `installDate` + `recapEnabled`

**Files:**
- `lib/features/settings/domain/entities/app_settings.dart` — add `DateTime? installDate`, `@Default(true) bool recapEnabled`
- `lib/features/settings/domain/repositories/settings_repository.dart` — add `updateInstallDate(DateTime date)`, `updateRecapEnabled({required bool enabled})`, `updateLastRecapYear(int year)`
- `lib/features/settings/data/repositories/settings_repository_impl.dart` — implement new methods, update `_toDomain`, `restoreSettings`

**Note:** `lastRecapYear` is not a Freezed field — it's a lightweight `IntColumn` on `app_settings` that tracks the last year a recap was generated, preventing re-trigger. Add it to the table and `_toDomain` but NOT to the `AppSettings` domain entity (it's implementation detail, not user-facing settings).

**Add to `AppSettingsTable`:**
```dart
IntColumn get lastRecapYear => integer().withDefault(const Constant(0))();
```

**Tests:** `test/features/settings/data/repositories/settings_repository_impl_test.dart` — add tests for `updateInstallDate`, `updateRecapEnabled`, `updateLastRecapYear`.

---

### T3: `ModuleDayStatusKind.paused` + pause-aware streaks

**Files:**
- `lib/core/modules/habit_module.dart` — add `paused` to enum
- `lib/core/reports/day_status_streaks.dart` — add `pausedDays` param to `longestStreak()` and `currentStreak()`
- `lib/features/water/domain/usecases/calculate_water_streak.dart` — add `pausedDays` param
- `lib/features/medicine/domain/usecases/calculate_adherence.dart` — add `pausedDays` param
- `lib/features/prayer/domain/usecases/calculate_prayer_streak.dart` — add `pausedDays` param

**Tests:** Update existing streak tests to verify paused days are excluded. Add new test cases:
- `test/core/reports/day_status_streaks_test.dart` — paused days don't break streaks
- `test/features/water/domain/calculate_water_streak_test.dart` — paused days excluded
- `test/features/prayer/domain/calculate_prayer_streak_test.dart` — paused days excluded
- `test/features/medicine/domain/calculate_adherence_test.dart` — paused days excluded

---

### T4: `YearSummary` data shape + `yearAggregation` on `HabitModule`

**Files:**
- `lib/core/recaps/year_summary.dart` — **new file**, Freezed class

```dart
@freezed
sealed class YearSummary with _$YearSummary {
  const factory YearSummary({
    required int yearNumber,
    required LocalDate installDate,
    required int activeDays,  // total days with any module activity
    required List<ModuleYearStats> modules,
  }) = _YearSummary;
}

@freezed
sealed class ModuleYearStats with _$ModuleYearStats {
  const factory ModuleYearStats({
    required String moduleId,
    required String displayName,
    required Color accentColor,
    // Water-specific
    int? totalMl,
    double? averageDailyMl,
    int? daysGoalMet,
    // Medicine-specific
    int? totalDoses,
    int? dosesTaken,
    double? adherencePercent,
    int? longestConsecutiveStreak,
    // Prayer-specific
    int? totalPrayers,
    int? prayersCompleted,
    double? onTimePercent,
    int? longestStreak,
    // Shared
    int? longestStreakAll,
    int? bestDayValue,
    // Pause tracking
    int? monthsActive,
    int? monthsTotal,
  }) = _ModuleYearStats;
}
```

- `lib/core/modules/habit_module.dart` — add `Future<ModuleYearStats?> yearAggregation(DateRange yearRange)` to `HabitModule` interface (default returns `null`)

**Each module implements `yearAggregation`:**
- `lib/features/water/water_module.dart` — queries `allEntriesInRange`, computes totalMl, averageDailyMl, daysGoalMet, longestConsecutiveStreak
- `lib/features/medicine/medicine_module.dart` — queries `dosesInRange`, runs `calculateAdherence`, computes longestConsecutiveStreak
- `lib/features/prayer/prayer_module.dart` — queries `recordsInRange`, computes onTime %, longestStreak via `CalculatePrayerStreakUseCase`

**Tests:**
- `test/core/recaps/year_summary_test.dart` — YearSummary serialization roundtrip
- Module-specific `yearAggregation` tests (one per module)

---

### T5: `YearRecapGeneratorUseCase` + `RecapRepository`

**Files:**
- `lib/core/recaps/recap_repository.dart` — **new file**, Drift-backed repository for `recaps` table
- `lib/core/recaps/recap_generator.dart` — **new file**, `YearRecapGeneratorUseCase`
- `lib/core/recaps/recap_providers.dart` — **new file**, Riverpod providers

**RecapRepository methods:**
```dart
class RecapRepository {
  Future<RecapRow?> byYearNumber(int yearNumber);
  Future<List<RecapRow>> allRecaps();  // ordered by yearNumber desc
  Future<void> save(RecapRow recap);
  Future<void> dismiss(String id);
}
```

**YearRecapGeneratorUseCase:**
```dart
class YearRecapGeneratorUseCase {
  const YearRecarGeneratorUseCase({
    required this.recapRepository,
    required this.modules,
    required this.settingsRepository,
  });

  /// Generates the recap for [yearNumber]. Returns the stored YearSummary
  /// or null if not enough data (< 200 active days).
  Future<YearSummary?> execute(int yearNumber, {required LocalDate today});
}
```

**Logic:**
1. Read `installDate` from settings. Compute `yearStart` = installDate + (yearNumber - 1) * 365 days, `yearEnd` = yearStart + 365 days.
2. For each module, call `module.yearAggregation(DateRange(start: yearStart, end: yearEnd))`.
3. Sum `activeDays` across all modules.
4. If `activeDays < 200`, return `null` (not enough data).
5. Build `YearSummary`, serialize to JSON, store in `recaps` table.
6. Update `lastRecapYear` in settings.

**Tests:** `test/core/recaps/recap_generator_test.dart` — test generation, 200-day threshold, multi-year, paused modules.

---

### T6: Recap trigger mechanism

**Files:**
- `lib/core/recaps/recap_trigger.dart` — **new file**, pure logic

```dart
enum RecapTriggerAction {
  /// No recap due.
  none,

  /// Show the yearly recap full-screen.
  showRecap,

  /// Show a "not enough data" fallback.
  notEnoughData,
}

RecapTriggerAction checkYearlyRecapTrigger({
  required DateTime? installDate,
  required int lastRecapYear,
  required DateTime now,
  required int activeDays,
});
```

**Logic:**
1. If `installDate == null`, return `none`.
2. Compute `daysSinceInstall = now.difference(installDate).inDays`.
3. If `daysSinceInstall < 365`, return `none`.
4. Compute `currentYearNumber = (daysSinceInstall / 365).floor()`.
5. If `currentYearNumber <= lastRecapYear`, return `none`.
6. If `activeDays < 200`, return `notEnoughData`.
7. Return `showRecap`.

**Wiring into app lifecycle:**
- `lib/main.dart` — In `didChangeAppLifecycleState(resumed)`, add `unawaited(checkAndShowYearlyRecap(db, container))`.
- `lib/core/recaps/recap_check.dart` — **new file**, top-level function that reads settings, calls trigger, calls generator if triggered, and shows the recap screen via a route.

**Tests:** `test/core/recaps/recap_trigger_test.dart` — pure unit tests for trigger logic.

---

### T7: Presentation — story cards + full-screen recap

**Files:**
- `lib/features/reports/presentation/screens/yearly_recap_screen.dart` — **new file**, full-screen story-style recap
- `lib/features/reports/presentation/widgets/yearly_recap_card.dart` — **new file**, per-module card widget
- `lib/features/reports/presentation/widgets/yearly_recap_hero_card.dart` — **new file**, combined longest-streak card
- `lib/features/reports/presentation/widgets/yearly_recap_not_enough_data.dart` — **new file**, fallback screen

**YearlyRecapScreen design:**
- Full-screen `PageView` with 4+ pages (one per module + hero card).
- Each page: gradient background (module accent color), large stat number, label, supporting stats below.
- Swipe to advance, progress dots at bottom.
- "Done" button on last page dismisses (sets `dismissed: true` in recaps table).
- Reuses `RecapCardCapture` for share functionality (reuse existing `shareMonthlyRecap` pattern but for yearly).

**YearlyRecapCard layout (per module):**
```
┌─────────────────────────────┐
│  [Module Icon]  Year 1      │
│                             │
│     1,234 liters            │  ← hero stat (large, bold)
│     Water consumed          │
│                             │
│  avg 3.4L/day               │  ← supporting stat
│  goal met 287 days          │
│  longest streak: 42 days    │
│                             │
│  active 11 of 12 months     │  ← pause indicator (if applicable)
└─────────────────────────────┘
```

**Tests:** Widget tests for each card type, PageView navigation.

---

### T8: "Past Recaps" entry in Settings

**Files:**
- `lib/features/reports/presentation/screens/past_recaps_screen.dart` — **new file**, list of past recaps
- `lib/features/settings/presentation/screens/settings_home_screen.dart` — add "Past Recaps" tile linking to `/reports/recaps`

**PastRecapsScreen:**
- Lists stored recaps from `RecapRepository.allRecaps()`.
- Each entry: year number, generated date, "View" button → opens `YearlyRecapScreen` with that recap's data.
- Max 5 stored (eviction: delete oldest when inserting 6th).

**Tests:** `test/features/reports/presentation/screens/past_recaps_screen_test.dart`

---

### T9: Localization

**Files:**
- `lib/core/l10n/app_en.arb` — add ~30 new keys
- `lib/core/l10n/app_bn.arb` — Bangla translations

**Key groups:**
- Recap screen title: `yearlyRecapTitle`, `yearlyRecapYearLabel`
- Per-module hero labels: `recapWaterHero`, `recapMedicineHero`, `recapPrayerHero`
- Supporting stats: `recapTotalLiters`, `recapAverageDaily`, `recapDaysGoalMet`, `recapAdherencePercent`, `recapDosesTaken`, `recapOnTimePercent`, `recapPrayersCompleted`, `recapLongestStreak`, `recapBestDay`, `recapMonthsActive`
- Hero card: `recapCombinedHero`, `recapOverallLongestStreak`, `recapOverallBestDay`
- Fallback: `recapNotEnoughData`, `recapNotEnoughDataBody`
- Past recaps: `pastRecapsTitle`, `pastRecapsEmpty`, `pastRecapsView`
- Settings toggle: `recapEnabledLabel`, `recapEnabledDescription`

---

### T10: Settings toggle for recap feature

**Files:**
- `lib/features/settings/presentation/screens/settings_home_screen.dart` — add recap toggle tile
- Use existing `updateRecapEnabled` from T2

---

## Task sequencing

```
T1 (schema) ──→ T2 (settings) ──→ T5 (generator) ──→ T6 (trigger) ──→ T7 (UI)
                                                                      ↑
T3 (paused) ──────────────────────────────────────────────────────────┘
T4 (YearSummary) ──→ T5
T8 (past recaps) ──→ T7
T9 (i18n) ──→ T7, T8
T10 (settings toggle) ──→ T6
```

**Parallel tracks:**
- T1 + T3 can run in parallel (both are shared infrastructure).
- T4 depends on T3 (needs paused variant).
- T5 depends on T1 + T2 + T4.
- T6 depends on T5.
- T7 depends on T5 + T9.
- T8 + T9 + T10 are independent after their prerequisites.

---

## Commit plan

| Commit | Tasks | Message |
|--------|-------|---------|
| 1 | T1 | `feat(db): add installDate column and recaps table (migration 10)` |
| 2 | T2 | `feat(settings): add installDate, recapEnabled, lastRecapYear to AppSettings` |
| 3 | T3 | `feat: add ModuleDayStatusKind.paused and pause-aware streak calculators` |
| 4 | T4 | `feat(recaps): add YearSummary and ModuleYearStats data shapes` |
| 5 | T5 | `feat(recaps): add RecapRepository and YearRecapGeneratorUseCase` |
| 6 | T6 | `feat(recaps): add trigger mechanism and app-lifecycle wiring` |
| 7 | T7 | `feat(recaps): add yearly recap story cards and full-screen UI` |
| 8 | T8 | `feat(recaps): add Past Recaps screen in Settings` |
| 9 | T9 | `feat(i18n): add en/bn localization for yearly recap` |
| 10 | T10 | `feat(settings): add recap feature toggle` |

---

## Risk areas

1. **Schema migration correctness** — The `installDate` seed from `created_at` is an approximation for pre-existing installs. If `created_at` was added in migration 1 and the user's first row predates their actual install, the recap timing will be slightly off. Acceptable trade-off; document in code comment.

2. **Module `yearAggregation` complexity** — Each module must query a full year of data. Water is straightforward (entries table). Medicine needs dose expansion. Prayer needs record materialization. All three modules already have repository methods for range queries, so this is assembly, not new data access.

3. **Recap trigger in background isolate** — The trigger check is lightweight (read two integers from settings), but the generation (iterating a year of data) is heavy. Generate only when the app is in the foreground (triggered from `didChangeAppLifecycleState(resumed)`), never from a background isolate.

4. **Localization coverage** — 30+ new keys in en/bn. The Bangla translations should be reviewed for natural phrasing, not machine-translated.

5. **Pause detection** — Modules don't currently expose "when were you paused" directly. The `dayStatus` map already returns `ModuleDayStatusKind.none` for days before the module was first used. For mid-year module additions, the recap should use the module's first-ever data date as the effective start. The `paused` variant needs each module to actually set it — this requires adding pause-detection logic to each module's `dayStatus` implementation (checking if settings indicate the module was archived during that period).

# Habit-Stacking Suggestions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detect when a user reliably logs water shortly after a Medicine
dose or a Prayer, and surface a dismissible dashboard suggestion offering
to nudge Water's reminder window to follow that pattern, per
`docs/superpowers/specs/02-delightful/04-habit-stacking-suggestions-design.md`.

**Architecture:** A pure correlation heuristic
(`findStackCorrelation`) compares one source-module (Medicine/Prayer)
timestamp per day against Water's logged timestamps over a trailing
14-day window — no DB access, fully unit-testable. A new
`habit_stack_suggestions` Drift table (one row per tracked pair, at most
two: `medicine_water`/`prayer_water`) holds each pair's `pending` →
`accepted`/`dismissed` lifecycle with a 30-day dismiss cooldown. An
evaluator wires the pure heuristic to real repository data and runs from
the same two app-resume trigger points `planAndApplyNotifications`
already uses — no new timer, no new call site. A dashboard `Card` shows
the one pending suggestion (if any); accepting it writes to Water's
existing per-weekday `reminderWindowOverrides` via
`WaterRepository.updateReminderSettings`, the same mechanism
`WaterSettingsScreen` already uses — no new reminder-scheduling concept.

**Tech Stack:** Flutter/Dart, Riverpod (codegen), Drift (codegen),
`package:clock`, `gen_l10n`, `flutter_test`/`mocktail`.

## Global Constraints

- New files only: `lib/core/stacking/habit_stack_correlation_usecase.dart`
  (pure), `lib/core/stacking/habit_stack_suggestion_evaluator.dart`
  (DB-wiring), `lib/core/stacking/habit_stack_suggestion_repository.dart`
  (Drift CRUD + its own `@riverpod` providers, same file — no separate
  providers file), `lib/core/database/tables/habit_stack_suggestions_table
  .dart`, `lib/features/dashboard/presentation/widgets/
  habit_stack_suggestion_card.dart`.
- New table `habit_stack_suggestions` must be added to `AppDatabase`'s
  `@DriftDatabase(tables: [...])` list (bumping `schemaVersion` from 7 to
  8) and to `docs/technical/database-design.md`, per that file's own
  convention.
- No new dependency — pure Dart correlation logic + existing
  Drift/Riverpod/`clock`.
- No modification to `notification_planner.dart` or the notification
  engine itself; the accepted action only ever calls
  `WaterRepository.updateReminderSettings` (already exists,
  `water_repository_impl.dart:290`).
- Water's `loggedAt` may be backdated (FR-W-05, `water_logs_table.dart:22`)
  — the correlation query uses it as-is; a user who habitually backdates
  entries will never qualify. Documented as a known, accepted precision
  limit, not a bug to fix here.
- Only two tracked pairs ever exist: `medicine_water`, `prayer_water`.
  Water is never the source, Medicine/Prayer are never the retimed
  target (neither has a movable-reminder-window concept — Medicine's
  reminders derive from `RepeatRule`, Prayer's from solar times).
- Every new l10n key goes in **both** `lib/core/l10n/app_en.arb` and
  `lib/core/l10n/app_bn.arb`; run `flutter gen-l10n` after each ARB edit
  and before running any test that references the changed getter.
- Per this repo's CLAUDE.md spec-implementation workflow: one commit per
  task, run only that task's own test file (never the full `flutter
  test` suite mid-task), pipe `build_runner`/`gen-l10n`/`test` output
  through `| tail -10`.
- **Deliberate interpretation beyond the source spec's literal table
  schema:** the spec's UI copy references "whichever weekdays
  contributed a qualifying day," but the spec's own `habit_stack_
  suggestions` table has no per-weekday breakdown column — only one
  aggregate `typicalSourceTime`. Task 4 therefore applies the accepted
  nudge to every weekday uniformly. A `sourceLabel` column (nullable
  TEXT, e.g. `'Fajr'` for the prayer pair, always `null` for the medicine
  pair) is added beyond the spec's original column list to fill the
  `{prayer}` placeholder in `habitStackSuggestionPrayerToWater` — the
  same kind of implementation-time schema refinement already precedented
  by `medicine_doses.grace_window_minutes` and `water_logs.source`
  (`CLAUDE.md`'s Medicine/Water sections).

---

### Task 1: Pure correlation heuristic

**Files:**
- Create: `lib/core/stacking/habit_stack_correlation_usecase.dart`
- Test: `test/core/stacking/habit_stack_correlation_usecase_test.dart`

**Interfaces:**
- Produces: `class StackCorrelationResult { qualifyingDays: int,
  totalDaysWithSource: int, medianGapMinutes: int, typicalSourceTime:
  LocalTime }` and `StackCorrelationResult? findStackCorrelation({required
  Map<LocalDate, DateTime> sourceByDay, required Map<LocalDate,
  List<DateTime>> targetByDay, int windowDays = 14, int
  minQualifyingDays = 5, Duration maxGap = const Duration(minutes: 90)})`
  — consumed by Task 3's evaluator and Task 2's repository test fixtures.

- [ ] **Step 1: Write the failing test**

Create `test/core/stacking/habit_stack_correlation_usecase_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/stacking/habit_stack_correlation_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  test(
    'finds a real pattern: 7/7 days qualify at a consistent 20-minute gap',
    () {
      final sourceByDay = <LocalDate, DateTime>{
        for (var i = 0; i < 7; i++)
          LocalDate(2026, 6, 1 + i): DateTime(2026, 6, 1 + i, 8, 15),
      };
      final targetByDay = <LocalDate, List<DateTime>>{
        for (var i = 0; i < 7; i++)
          LocalDate(2026, 6, 1 + i): [DateTime(2026, 6, 1 + i, 8, 35)],
      };

      final result = findStackCorrelation(
        sourceByDay: sourceByDay,
        targetByDay: targetByDay,
      );

      expect(result, isNotNull);
      expect(result!.qualifyingDays, 7);
      expect(result.totalDaysWithSource, 7);
      expect(result.medianGapMinutes, 20);
      expect(result.typicalSourceTime, const LocalTime(8, 15));
    },
  );

  test(
    'below minQualifyingDays returns null even at a 100% qualifying rate',
    () {
      final sourceByDay = <LocalDate, DateTime>{
        LocalDate(2026, 6, 1): DateTime(2026, 6, 1, 8, 15),
        LocalDate(2026, 6, 2): DateTime(2026, 6, 2, 8, 15),
        LocalDate(2026, 6, 3): DateTime(2026, 6, 3, 8, 15),
      };
      final targetByDay = <LocalDate, List<DateTime>>{
        LocalDate(2026, 6, 1): [DateTime(2026, 6, 1, 8, 30)],
        LocalDate(2026, 6, 2): [DateTime(2026, 6, 2, 8, 30)],
        LocalDate(2026, 6, 3): [DateTime(2026, 6, 3, 8, 30)],
      };

      expect(
        findStackCorrelation(
          sourceByDay: sourceByDay,
          targetByDay: targetByDay,
        ),
        isNull,
      );
    },
  );

  test(
    'below the 70% qualifying-day rate returns null even with enough '
    'qualifying days',
    () {
      // 10 days with a source action, only 5 (50%) have a same-day water
      // log within the gap window — 5 clears minQualifyingDays but fails
      // the 70% rate check.
      final sourceByDay = <LocalDate, DateTime>{
        for (var i = 0; i < 10; i++)
          LocalDate(2026, 6, 1 + i): DateTime(2026, 6, 1 + i, 8),
      };
      final targetByDay = <LocalDate, List<DateTime>>{
        for (var i = 0; i < 5; i++)
          LocalDate(2026, 6, 1 + i): [DateTime(2026, 6, 1 + i, 8, 30)],
      };

      expect(
        findStackCorrelation(
          sourceByDay: sourceByDay,
          targetByDay: targetByDay,
        ),
        isNull,
      );
    },
  );

  test('a target logged before the source action never qualifies that day', () {
    final sourceByDay = <LocalDate, DateTime>{
      for (var i = 0; i < 7; i++)
        LocalDate(2026, 6, 1 + i): DateTime(2026, 6, 1 + i, 8, 15),
    };
    final targetByDay = <LocalDate, List<DateTime>>{
      // Every water log is 10 minutes BEFORE the source action.
      for (var i = 0; i < 7; i++)
        LocalDate(2026, 6, 1 + i): [DateTime(2026, 6, 1 + i, 8, 5)],
    };

    expect(
      findStackCorrelation(sourceByDay: sourceByDay, targetByDay: targetByDay),
      isNull,
    );
  });

  test('a gap beyond maxGap never qualifies that day', () {
    final sourceByDay = <LocalDate, DateTime>{
      for (var i = 0; i < 7; i++)
        LocalDate(2026, 6, 1 + i): DateTime(2026, 6, 1 + i, 8),
    };
    final targetByDay = <LocalDate, List<DateTime>>{
      // 2 hours after the source action -> beyond the default 90-minute cap.
      for (var i = 0; i < 7; i++)
        LocalDate(2026, 6, 1 + i): [DateTime(2026, 6, 1 + i, 10)],
    };

    expect(
      findStackCorrelation(sourceByDay: sourceByDay, targetByDay: targetByDay),
      isNull,
    );
  });

  test(
    'only the trailing windowDays days count — older source days outside '
    'the window are excluded from totalDaysWithSource',
    () {
      // 20 days of source data; only the trailing 14 (relative to the
      // latest day present) should be considered.
      final baseDay = const LocalDate(2026, 5, 20);
      final days = [for (var i = 0; i < 20; i++) baseDay.addDays(i)];
      final sourceByDay = {
        for (final day in days) day: DateTime(day.year, day.month, day.day, 8),
      };
      final targetByDay = {
        for (final day in days)
          day: [DateTime(day.year, day.month, day.day, 8, 30)],
      };

      final result = findStackCorrelation(
        sourceByDay: sourceByDay,
        targetByDay: targetByDay,
      );

      expect(result, isNotNull);
      expect(result!.totalDaysWithSource, 14);
      expect(result.qualifyingDays, 14);
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/stacking/habit_stack_correlation_usecase_test.dart | tail -10`
Expected: FAIL to compile — `habit_stack_correlation_usecase.dart` doesn't
exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/core/stacking/habit_stack_correlation_usecase.dart`:

```dart
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:meta/meta.dart';

/// One correlation candidate: a source module's (Medicine/Prayer)
/// completed-action time reliably precedes a Water log by a short,
/// consistent gap (`docs/superpowers/specs/02-delightful/
/// 04-habit-stacking-suggestions-design.md`).
@immutable
class StackCorrelationResult {
  /// Creates a correlation result.
  const StackCorrelationResult({
    required this.qualifyingDays,
    required this.totalDaysWithSource,
    required this.medianGapMinutes,
    required this.typicalSourceTime,
  });

  /// Days (within the trailing window) where a Water log followed the
  /// source action within `maxGap`.
  final int qualifyingDays;

  /// Days (within the trailing window) the source module had any
  /// completed action at all — the correlation's denominator.
  final int totalDaysWithSource;

  /// Median gap, source-action -> water-log, across qualifying days.
  final int medianGapMinutes;

  /// Median source-action wall-clock time, e.g. `08:15` — the anchor
  /// time an accepted suggestion nudges Water's reminder window to.
  final LocalTime typicalSourceTime;

  @override
  bool operator ==(Object other) =>
      other is StackCorrelationResult &&
      qualifyingDays == other.qualifyingDays &&
      totalDaysWithSource == other.totalDaysWithSource &&
      medianGapMinutes == other.medianGapMinutes &&
      typicalSourceTime == other.typicalSourceTime;

  @override
  int get hashCode => Object.hash(
    qualifyingDays,
    totalDaysWithSource,
    medianGapMinutes,
    typicalSourceTime,
  );

  @override
  String toString() =>
      'StackCorrelationResult(qualifyingDays: $qualifyingDays, '
      'totalDaysWithSource: $totalDaysWithSource, '
      'medianGapMinutes: $medianGapMinutes, '
      'typicalSourceTime: $typicalSourceTime)';
}

/// Pure heuristic — explainable, not a model. [sourceByDay] is one
/// timestamp per day (the source module's first `done`/`prayed` action
/// that day); [targetByDay] is every Water `loggedAt` that day. Only the
/// trailing [windowDays] days (relative to the latest day present in
/// [sourceByDay]) are considered. A day "qualifies" if any target
/// timestamp falls in `(source, source + maxGap]`. Returns `null` below
/// [minQualifyingDays] or below a 70% qualifying-day rate — both guard
/// against "coincidence, not a pattern."
StackCorrelationResult? findStackCorrelation({
  required Map<LocalDate, DateTime> sourceByDay,
  required Map<LocalDate, List<DateTime>> targetByDay,
  int windowDays = 14,
  int minQualifyingDays = 5,
  Duration maxGap = const Duration(minutes: 90),
}) {
  if (sourceByDay.isEmpty) return null;

  final latestDay = sourceByDay.keys.reduce(
    (a, b) => a.compareTo(b) >= 0 ? a : b,
  );
  final earliestInWindow = latestDay.addDays(-(windowDays - 1));
  final windowedSource = {
    for (final entry in sourceByDay.entries)
      if (entry.key.compareTo(earliestInWindow) >= 0) entry.key: entry.value,
  };
  final totalDaysWithSource = windowedSource.length;

  final gapsMinutes = <int>[];
  final sourceMinutesOfDay = <int>[];
  for (final entry in windowedSource.entries) {
    final sourceTime = entry.value;
    final targets = targetByDay[entry.key] ?? const [];
    int? bestGapMinutes;
    for (final target in targets) {
      final gap = target.difference(sourceTime);
      if (gap > Duration.zero && gap <= maxGap) {
        final gapMinutes = gap.inMinutes;
        if (bestGapMinutes == null || gapMinutes < bestGapMinutes) {
          bestGapMinutes = gapMinutes;
        }
      }
    }
    if (bestGapMinutes != null) {
      gapsMinutes.add(bestGapMinutes);
      sourceMinutesOfDay.add(sourceTime.hour * 60 + sourceTime.minute);
    }
  }

  final qualifyingDays = gapsMinutes.length;
  if (qualifyingDays < minQualifyingDays) return null;
  if (qualifyingDays / totalDaysWithSource < 0.7) return null;

  final medianGap = _median(gapsMinutes);
  final medianMinuteOfDay = _median(sourceMinutesOfDay);
  return StackCorrelationResult(
    qualifyingDays: qualifyingDays,
    totalDaysWithSource: totalDaysWithSource,
    medianGapMinutes: medianGap,
    typicalSourceTime: LocalTime(
      medianMinuteOfDay ~/ 60,
      medianMinuteOfDay % 60,
    ),
  );
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : ((sorted[mid - 1] + sorted[mid]) / 2).round();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/stacking/habit_stack_correlation_usecase_test.dart | tail -10`
Expected: PASS (6 tests).

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze lib/core/stacking/habit_stack_correlation_usecase.dart | tail -10`
Run: `dart format lib/core/stacking/habit_stack_correlation_usecase.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/stacking/habit_stack_correlation_usecase.dart \
  test/core/stacking/habit_stack_correlation_usecase_test.dart
git commit -m "feat(stacking): add the pure habit-stack correlation heuristic"
```

---

### Task 2: Suggestion table + repository

**Files:**
- Create: `lib/core/database/tables/habit_stack_suggestions_table.dart`
- Create: `lib/core/stacking/habit_stack_suggestion_repository.dart`
- Modify: `lib/core/database/app_database.dart`
- Modify: `docs/technical/database-design.md`
- Test: `test/core/stacking/habit_stack_suggestion_repository_test.dart`

**Interfaces:**
- Consumes: `StackCorrelationResult` from Task 1.
- Produces: `class HabitStackSuggestionRow { id, sourceModuleId,
  targetModuleId, status, qualifyingDays, medianGapMinutes,
  typicalSourceTime, sourceLabel, lastEvaluatedAt, respondedAt, createdAt,
  updatedAt }` (Drift-generated), `class HabitStackSuggestionRepository`
  with `byId(String id)`, `pendingSuggestion()` (stream), `upsertEvaluation
  ({required id, required sourceModuleId, required targetModuleId,
  required StackCorrelationResult result, String? sourceLabel, required
  DateTime now})`, `accept(String id, {required DateTime now})`,
  `dismiss(String id, {required DateTime now})`, plus
  `habitStackSuggestionRepositoryProvider`/
  `pendingHabitStackSuggestionProvider` (`@riverpod`) — consumed by
  Task 3's evaluator and Task 4's dashboard card.

- [ ] **Step 1: Write the failing test**

Create `test/core/stacking/habit_stack_suggestion_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/stacking/habit_stack_correlation_usecase.dart';
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_repository.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  late AppDatabase db;
  late HabitStackSuggestionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HabitStackSuggestionRepository(db);
  });

  tearDown(() => db.close());

  const result = StackCorrelationResult(
    qualifyingDays: 6,
    totalDaysWithSource: 7,
    medianGapMinutes: 20,
    typicalSourceTime: LocalTime(8, 15),
  );

  test('upsertEvaluation creates a pending row when none exists', () async {
    await repo.upsertEvaluation(
      id: 'medicine_water',
      sourceModuleId: 'medicine',
      targetModuleId: 'water',
      result: result,
      now: DateTime.utc(2026, 7, 1),
    );

    final row = await repo.byId('medicine_water');
    expect(row, isNotNull);
    expect(row!.status, 'pending');
    expect(row.qualifyingDays, 6);
    expect(row.typicalSourceTime, '08:15');
    expect(row.sourceLabel, isNull);
  });

  test(
    'accept locks the row so a later evaluation never overwrites it',
    () async {
      await repo.upsertEvaluation(
        id: 'medicine_water',
        sourceModuleId: 'medicine',
        targetModuleId: 'water',
        result: result,
        now: DateTime.utc(2026, 7, 1),
      );
      await repo.accept('medicine_water', now: DateTime.utc(2026, 7, 2));

      await repo.upsertEvaluation(
        id: 'medicine_water',
        sourceModuleId: 'medicine',
        targetModuleId: 'water',
        result: const StackCorrelationResult(
          qualifyingDays: 7,
          totalDaysWithSource: 7,
          medianGapMinutes: 10,
          typicalSourceTime: LocalTime(9, 0),
        ),
        now: DateTime.utc(2026, 7, 10),
      );

      final row = await repo.byId('medicine_water');
      expect(row!.status, 'accepted');
      expect(row.qualifyingDays, 6); // unchanged
    },
  );

  test(
    'a dismissed row stays dismissed on re-evaluation within the 30-day '
    'cooldown, but its lastEvaluatedAt still bumps',
    () async {
      await repo.upsertEvaluation(
        id: 'prayer_water',
        sourceModuleId: 'prayer',
        targetModuleId: 'water',
        result: result,
        sourceLabel: 'Fajr',
        now: DateTime.utc(2026, 7, 1),
      );
      await repo.dismiss('prayer_water', now: DateTime.utc(2026, 7, 2));

      await repo.upsertEvaluation(
        id: 'prayer_water',
        sourceModuleId: 'prayer',
        targetModuleId: 'water',
        result: result,
        sourceLabel: 'Fajr',
        now: DateTime.utc(2026, 7, 20), // 18 days after dismissal
      );

      final row = await repo.byId('prayer_water');
      expect(row!.status, 'dismissed');
      expect(
        row.lastEvaluatedAt,
        DateTime.utc(2026, 7, 20).millisecondsSinceEpoch,
      );
    },
  );

  test(
    'a dismissed row resurfaces to pending once the 30-day cooldown has '
    'passed',
    () async {
      await repo.upsertEvaluation(
        id: 'prayer_water',
        sourceModuleId: 'prayer',
        targetModuleId: 'water',
        result: result,
        sourceLabel: 'Fajr',
        now: DateTime.utc(2026, 7, 1),
      );
      await repo.dismiss('prayer_water', now: DateTime.utc(2026, 7, 2));

      await repo.upsertEvaluation(
        id: 'prayer_water',
        sourceModuleId: 'prayer',
        targetModuleId: 'water',
        result: result,
        sourceLabel: 'Fajr',
        now: DateTime.utc(2026, 9, 5), // 65 days after dismissal
      );

      final row = await repo.byId('prayer_water');
      expect(row!.status, 'pending');
      expect(row.respondedAt, isNull);
    },
  );

  test('pendingSuggestion streams the one pending row', () async {
    await repo.upsertEvaluation(
      id: 'medicine_water',
      sourceModuleId: 'medicine',
      targetModuleId: 'water',
      result: result,
      now: DateTime.utc(2026, 7, 1),
    );

    final pending = await repo.pendingSuggestion().first;
    expect(pending, isNotNull);
    expect(pending!.id, 'medicine_water');
  });

  test('byId returns null for an unknown id', () async {
    expect(await repo.byId('nope'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/stacking/habit_stack_suggestion_repository_test.dart | tail -10`
Expected: FAIL to compile — neither file exists yet.

- [ ] **Step 3: Create the table**

Create `lib/core/database/tables/habit_stack_suggestions_table.dart`:

```dart
import 'package:drift/drift.dart';

/// One tracked source-module -> Water correlation candidate
/// (`docs/superpowers/specs/02-delightful/
/// 04-habit-stacking-suggestions-design.md`). At most two rows exist in
/// v1 (`id` `'medicine_water'`/`'prayer_water'`) — a small, independently
/// queryable, multi-row table, following `achievements_table.dart`'s and
/// `notification_ledger_table.dart`'s precedent rather than a JSON blob
/// crammed into `app_settings` (which is a true singleton).
@DataClassName('HabitStackSuggestionRow')
class HabitStackSuggestionsTable extends Table {
  @override
  String get tableName => 'habit_stack_suggestions';

  /// Deterministic: `'{sourceModuleId}_{targetModuleId}'`, e.g.
  /// `'medicine_water'`.
  TextColumn get id => text()();

  /// `'medicine'` | `'prayer'` in v1.
  TextColumn get sourceModuleId => text()();

  /// Always `'water'` in v1 — Medicine/Prayer have no movable-reminder
  /// concept to retime.
  TextColumn get targetModuleId => text()();

  /// `'pending'` | `'accepted'` | `'dismissed'`.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Days (of the trailing window) a same-day Water log followed the
  /// source action within the gap cap.
  IntColumn get qualifyingDays => integer()();

  /// Median source-action -> water-log gap, in minutes.
  IntColumn get medianGapMinutes => integer()();

  /// `"HH:mm"` — median source-action wall-clock time, the anchor an
  /// accepted suggestion nudges Water's reminder window to.
  TextColumn get typicalSourceTime => text()();

  /// Human-readable label for the source action, e.g. `'Fajr'` for the
  /// prayer pair — `null` for the medicine pair (Medicine has only one
  /// kind of dose-completion event, nothing to name). **Added beyond the
  /// design doc's original column list** to fill the `{prayer}`
  /// placeholder in `habitStackSuggestionPrayerToWater` — the doc's
  /// `{prayer}` UI copy assumes a nameable source action, but its own
  /// table schema had nowhere to store one.
  TextColumn get sourceLabel => text().nullable()();

  /// UTC epoch millis of the last time this pair was evaluated —
  /// backs the 24h cheap-early-exit re-evaluation guard.
  IntColumn get lastEvaluatedAt => integer()();

  /// UTC epoch millis the user last accepted/dismissed this suggestion;
  /// null while `pending`.
  IntColumn get respondedAt => integer().nullable()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 4: Register the table and bump the schema version**

In `lib/core/database/app_database.dart`, add the import alongside the
other table imports:

```dart
import 'package:habit_tracker/core/database/tables/habit_stack_suggestions_table.dart';
```

Add `HabitStackSuggestionsTable` to the `@DriftDatabase(tables: [...])`
list, right after `AchievementsTable`:

```dart
@DriftDatabase(
  tables: [
    AppSettingsTable,
    NotificationLedgerTable,
    AchievementsTable,
    HabitStackSuggestionsTable,
    WaterGoalsTable,
```

Change:

```dart
  @override
  int get schemaVersion => 7;
```

to:

```dart
  @override
  int get schemaVersion => 8;
```

And add a new migration block right before the "Seam:" comment inside
`onUpgrade`:

```dart
      if (from < 8) {
        // Habit-stacking suggestions (medicine/prayer -> water).
        await m.createTable(habitStackSuggestionsTable);
      }
      // Seam: when schemaVersion increments further, add
      // `if (from < N) ...` blocks here — no other file needs to
      // change for a schema migration.
```

- [ ] **Step 5: Document the table**

In `docs/technical/database-design.md`, insert a new section right after
the existing `### \`achievements\`` section (before `## Water module`):

```markdown
### `habit_stack_suggestions`

Backs the habit-stacking suggestion card added in
`../superpowers/specs/02-delightful/04-habit-stacking-suggestions-design.md`.
Cross-module (not owned by any single module's own section below), same
reasoning as `achievements` — a small, independently-queryable, multi-row
table, not a JSON blob in `app_settings`. At most two rows exist in v1.

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | `'{sourceModuleId}_{targetModuleId}'`, e.g. `'medicine_water'` |
| source_module_id | TEXT | `'medicine'` \| `'prayer'` |
| target_module_id | TEXT | always `'water'` in v1 |
| status | TEXT | `'pending'` \| `'accepted'` \| `'dismissed'` |
| qualifying_days | INTEGER | |
| median_gap_minutes | INTEGER | |
| typical_source_time | TEXT | local `"HH:mm"` |
| source_label | TEXT NULL | e.g. `'Fajr'`; always null for the medicine pair |
| last_evaluated_at | INTEGER | UTC; backs the 24h re-evaluation guard |
| responded_at | INTEGER NULL | UTC; null while pending |
| created_at, updated_at | INTEGER | |

---
```

- [ ] **Step 6: Implement the repository + providers**

Create `lib/core/stacking/habit_stack_suggestion_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/stacking/habit_stack_correlation_usecase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'habit_stack_suggestion_repository.g.dart';

/// Drift-backed CRUD over the `habit_stack_suggestions` table
/// (`core/stacking/habit_stack_suggestion_evaluator.dart`'s only data
/// dependency).
class HabitStackSuggestionRepository {
  /// Creates a repository backed by [_db].
  HabitStackSuggestionRepository(this._db);

  final AppDatabase _db;

  /// Looks up a single row by its deterministic [id], or `null` if it has
  /// never been evaluated.
  Future<HabitStackSuggestionRow?> byId(String id) {
    return (_db.select(
      _db.habitStackSuggestionsTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// The one `pending` row, if any — the dashboard card's data source.
  /// (At most two rows exist in v1; ordering by `lastEvaluatedAt` desc
  /// just makes "which one, if somehow both are pending" deterministic.)
  Stream<HabitStackSuggestionRow?> pendingSuggestion() {
    final query = _db.select(_db.habitStackSuggestionsTable)
      ..where((t) => t.status.equals('pending'))
      ..orderBy([(t) => OrderingTerm.desc(t.lastEvaluatedAt)])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  /// Writes [result] as [id]'s current evaluation. Only ever moves a row
  /// **into** `pending` from nothing, from itself (still pending), or
  /// from an expired (`>= 30` days) `dismissed` cooldown — never
  /// overwrites `accepted`, and never resets `dismissed` before its
  /// cooldown expires (though `lastEvaluatedAt` still bumps either way,
  /// so the 24h early-exit in `habit_stack_suggestion_evaluator.dart`
  /// keeps working).
  Future<void> upsertEvaluation({
    required String id,
    required String sourceModuleId,
    required String targetModuleId,
    required StackCorrelationResult result,
    String? sourceLabel,
    required DateTime now,
  }) async {
    final nowMillis = now.millisecondsSinceEpoch;
    final existing = await byId(id);
    if (existing == null) {
      await _db
          .into(_db.habitStackSuggestionsTable)
          .insert(
            HabitStackSuggestionsTableCompanion.insert(
              id: id,
              sourceModuleId: sourceModuleId,
              targetModuleId: targetModuleId,
              qualifyingDays: result.qualifyingDays,
              medianGapMinutes: result.medianGapMinutes,
              typicalSourceTime: result.typicalSourceTime.format(),
              sourceLabel: Value(sourceLabel),
              lastEvaluatedAt: nowMillis,
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
      return;
    }
    if (existing.status == 'accepted') return;
    if (existing.status == 'dismissed') {
      final respondedAt = existing.respondedAt;
      final cooldownExpired =
          respondedAt == null ||
          now.difference(DateTime.fromMillisecondsSinceEpoch(respondedAt)) >=
              const Duration(days: 30);
      if (!cooldownExpired) {
        await (_db.update(
          _db.habitStackSuggestionsTable,
        )..where((t) => t.id.equals(id))).write(
          HabitStackSuggestionsTableCompanion(
            lastEvaluatedAt: Value(nowMillis),
            updatedAt: Value(nowMillis),
          ),
        );
        return;
      }
    }
    await (_db.update(
      _db.habitStackSuggestionsTable,
    )..where((t) => t.id.equals(id))).write(
      HabitStackSuggestionsTableCompanion(
        status: const Value('pending'),
        qualifyingDays: Value(result.qualifyingDays),
        medianGapMinutes: Value(result.medianGapMinutes),
        typicalSourceTime: Value(result.typicalSourceTime.format()),
        sourceLabel: Value(sourceLabel),
        lastEvaluatedAt: Value(nowMillis),
        respondedAt: const Value(null),
        updatedAt: Value(nowMillis),
      ),
    );
  }

  /// Marks [id] accepted — never re-evaluated again (the reminder is
  /// already adjusted; re-suggesting the same stack is noise).
  Future<void> accept(String id, {required DateTime now}) => _respond(
    id,
    status: 'accepted',
    now: now,
  );

  /// Marks [id] dismissed — eligible for re-evaluation after a 30-day
  /// cooldown (`upsertEvaluation`'s own check).
  Future<void> dismiss(String id, {required DateTime now}) => _respond(
    id,
    status: 'dismissed',
    now: now,
  );

  Future<void> _respond(
    String id, {
    required String status,
    required DateTime now,
  }) async {
    final nowMillis = now.millisecondsSinceEpoch;
    await (_db.update(
      _db.habitStackSuggestionsTable,
    )..where((t) => t.id.equals(id))).write(
      HabitStackSuggestionsTableCompanion(
        status: Value(status),
        respondedAt: Value(nowMillis),
        updatedAt: Value(nowMillis),
      ),
    );
  }
}

/// The shared [HabitStackSuggestionRepository].
@Riverpod(keepAlive: true)
HabitStackSuggestionRepository habitStackSuggestionRepository(Ref ref) {
  return HabitStackSuggestionRepository(ref.watch(databaseProvider));
}

/// The one pending suggestion, if any — `HabitStackSuggestionCard`'s data
/// source.
@riverpod
Stream<HabitStackSuggestionRow?> pendingHabitStackSuggestion(Ref ref) {
  return ref.watch(habitStackSuggestionRepositoryProvider).pendingSuggestion();
}
```

- [ ] **Step 7: Regenerate code**

Run: `dart run build_runner build --delete-conflicting-outputs | tail -10`
Expected: exits 0, regenerates `app_database.g.dart` and
`habit_stack_suggestion_repository.g.dart` (both gitignored).

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/core/stacking/habit_stack_suggestion_repository_test.dart | tail -10`
Expected: PASS (6 tests).

- [ ] **Step 9: Analyze and format**

Run: `flutter analyze lib/core/database/tables/habit_stack_suggestions_table.dart lib/core/database/app_database.dart lib/core/stacking/habit_stack_suggestion_repository.dart | tail -10`
Run: `dart format lib/core/database/tables/habit_stack_suggestions_table.dart lib/core/database/app_database.dart lib/core/stacking/habit_stack_suggestion_repository.dart`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/core/database/tables/habit_stack_suggestions_table.dart \
  lib/core/database/app_database.dart \
  lib/core/stacking/habit_stack_suggestion_repository.dart \
  docs/technical/database-design.md \
  test/core/stacking/habit_stack_suggestion_repository_test.dart
git commit -m "feat(stacking): add the habit_stack_suggestions table and repository"
```

---

### Task 3: Evaluator wiring + app-resume trigger

**Files:**
- Create: `lib/core/stacking/habit_stack_suggestion_evaluator.dart`
- Modify: `lib/main.dart:91,183`
- Test: `test/core/stacking/habit_stack_suggestion_evaluator_test.dart`

**Interfaces:**
- Consumes: `findStackCorrelation` (Task 1),
  `HabitStackSuggestionRepository` (Task 2),
  `MedicineRepositoryImpl.dosesInRange`, `PrayerRepositoryImpl
  .recordsInRange`, `WaterRepositoryImpl.watchEntriesInRange` (all
  pre-existing).
- Produces: `Future<void> evaluateStackSuggestions({required AppDatabase
  db})` — consumed by `main.dart`'s two re-planning trigger points.

- [ ] **Step 1: Write the failing test**

Create `test/core/stacking/habit_stack_suggestion_evaluator_test.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_evaluator.dart';
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_repository.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> seedMedicineSchedule(AppDatabase db) async {
    final medicineRepo = MedicineRepositoryImpl(db);
    final medicineResult = await medicineRepo.createMedicine(
      name: 'Aspirin',
      stockEnabled: false,
    );
    final medicine = (medicineResult as Success<Medicine>).value;
    final scheduleResult = await medicineRepo.createSchedule(
      medicineId: medicine.id,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 5, 20),
    );
    return (scheduleResult as Success<MedicineSchedule>).value.id;
  }

  test(
    'a real medicine -> water pattern over 7 days produces a pending '
    "'medicine_water' suggestion",
    () async {
      final medicineRepo = MedicineRepositoryImpl(db);
      final waterRepo = WaterRepositoryImpl(db);
      final scheduleId = await seedMedicineSchedule(db);
      final medicines = await medicineRepo.allMedicines();
      final medicineId = medicines.single.id;

      final today = DateTime.utc(2026, 6, 7);
      for (var i = 0; i < 7; i++) {
        final day = today.subtract(Duration(days: i));
        await medicineRepo.restoreDose(
          MedicineDose(
            id: '',
            medicineId: medicineId,
            scheduleId: scheduleId,
            scheduledFor: DateTime.utc(day.year, day.month, day.day, 8),
            storedStatus: MedicineDoseStatus.done,
            graceWindowMinutes: 30,
            statusChangedAt: DateTime.utc(
              day.year,
              day.month,
              day.day,
              8,
              5,
            ),
            stockDeltaApplied: 0,
          ),
        );
        await waterRepo.addEntry(
          amountMl: 250,
          loggedAt: DateTime.utc(day.year, day.month, day.day, 8, 25),
          source: WaterEntrySource.quick,
        );
      }

      await withClock(Clock.fixed(today.add(const Duration(hours: 9))), () async {
        await evaluateStackSuggestions(db: db);
      });

      final repository = HabitStackSuggestionRepository(db);
      final row = await repository.byId('medicine_water');
      expect(row, isNotNull);
      expect(row!.status, 'pending');
      expect(row.sourceModuleId, 'medicine');
      expect(row.targetModuleId, 'water');
      expect(row.qualifyingDays, greaterThanOrEqualTo(5));
    },
  );

  test(
    'a second evaluation within 24h does not re-evaluate (the row is '
    'left exactly as the first evaluation wrote it)',
    () async {
      final medicineRepo = MedicineRepositoryImpl(db);
      final waterRepo = WaterRepositoryImpl(db);
      final scheduleId = await seedMedicineSchedule(db);
      final medicineId = (await medicineRepo.allMedicines()).single.id;
      final today = DateTime.utc(2026, 6, 7);

      for (var i = 0; i < 7; i++) {
        final day = today.subtract(Duration(days: i));
        await medicineRepo.restoreDose(
          MedicineDose(
            id: '',
            medicineId: medicineId,
            scheduleId: scheduleId,
            scheduledFor: DateTime.utc(day.year, day.month, day.day, 8),
            storedStatus: MedicineDoseStatus.done,
            graceWindowMinutes: 30,
            statusChangedAt: DateTime.utc(
              day.year,
              day.month,
              day.day,
              8,
              5,
            ),
            stockDeltaApplied: 0,
          ),
        );
        await waterRepo.addEntry(
          amountMl: 250,
          loggedAt: DateTime.utc(day.year, day.month, day.day, 8, 25),
          source: WaterEntrySource.quick,
        );
      }

      final firstRun = today.add(const Duration(hours: 9));
      await withClock(Clock.fixed(firstRun), () async {
        await evaluateStackSuggestions(db: db);
      });
      final repository = HabitStackSuggestionRepository(db);
      final firstEvaluatedAt = (await repository.byId('medicine_water'))!
          .lastEvaluatedAt;

      // Adds a same-day water log that would otherwise change the
      // computed result, to make the "no-op" observable.
      await waterRepo.addEntry(
        amountMl: 100,
        loggedAt: today.add(const Duration(hours: 10)),
        source: WaterEntrySource.quick,
      );
      await withClock(
        Clock.fixed(firstRun.add(const Duration(hours: 1))),
        () async {
          await evaluateStackSuggestions(db: db);
        },
      );

      final row = await repository.byId('medicine_water');
      expect(row!.lastEvaluatedAt, firstEvaluatedAt);
    },
  );

  test('no pattern at all leaves no row', () async {
    await seedMedicineSchedule(db);
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 7, 9)), () async {
      await evaluateStackSuggestions(db: db);
    });

    final repository = HabitStackSuggestionRepository(db);
    expect(await repository.byId('medicine_water'), isNull);
    expect(await repository.byId('prayer_water'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/stacking/habit_stack_suggestion_evaluator_test.dart | tail -10`
Expected: FAIL to compile — `habit_stack_suggestion_evaluator.dart`
doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/core/stacking/habit_stack_suggestion_evaluator.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/stacking/habit_stack_correlation_usecase.dart';
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_repository.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';

/// Evaluates both tracked stacking pairs (`medicine -> water`,
/// `prayer -> water`) against the trailing 14 days of real log data and
/// persists any qualifying pattern as a `pending` suggestion. Piggybacks
/// on the same app-resume trigger `planAndApplyNotifications` already
/// uses (`main.dart`) — no new timer, no new call site
/// (`docs/superpowers/specs/02-delightful/
/// 04-habit-stacking-suggestions-design.md`, "Where it runs").
Future<void> evaluateStackSuggestions({required AppDatabase db}) async {
  final now = clock.now();
  final repository = HabitStackSuggestionRepository(db);
  final today = localDayKey(now);
  final windowStart = today.addDays(-13);

  final waterEntries = await WaterRepositoryImpl(
    db,
  ).watchEntriesInRange(windowStart, today).first;
  final targetByDay = <LocalDate, List<DateTime>>{};
  for (final entry in waterEntries) {
    (targetByDay[localDayKey(entry.loggedAt)] ??= []).add(entry.loggedAt);
  }

  await _evaluatePair(
    repository: repository,
    id: 'medicine_water',
    sourceModuleId: 'medicine',
    targetModuleId: 'water',
    now: now,
    sourceByDay: await _medicineDoneByDay(db, windowStart, today),
    sourceLabel: null,
    targetByDay: targetByDay,
  );

  final prayerSource = await _prayerPrayedByDay(db, windowStart, today);
  await _evaluatePair(
    repository: repository,
    id: 'prayer_water',
    sourceModuleId: 'prayer',
    targetModuleId: 'water',
    now: now,
    sourceByDay: prayerSource.byDay,
    sourceLabel: prayerSource.modeLabel,
    targetByDay: targetByDay,
  );
}

Future<void> _evaluatePair({
  required HabitStackSuggestionRepository repository,
  required String id,
  required String sourceModuleId,
  required String targetModuleId,
  required DateTime now,
  required Map<LocalDate, DateTime> sourceByDay,
  required String? sourceLabel,
  required Map<LocalDate, List<DateTime>> targetByDay,
}) async {
  final existing = await repository.byId(id);
  if (existing != null) {
    if (existing.status == 'accepted') return;
    // Cheap early-exit: a user resuming the app five times a day
    // shouldn't re-run the correlation query five times.
    final lastEvaluated = DateTime.fromMillisecondsSinceEpoch(
      existing.lastEvaluatedAt,
    );
    if (now.difference(lastEvaluated) < const Duration(hours: 24)) return;
  }
  final result = findStackCorrelation(
    sourceByDay: sourceByDay,
    targetByDay: targetByDay,
  );
  if (result == null) return;
  await repository.upsertEvaluation(
    id: id,
    sourceModuleId: sourceModuleId,
    targetModuleId: targetModuleId,
    result: result,
    sourceLabel: sourceLabel,
    now: now,
  );
}

Future<Map<LocalDate, DateTime>> _medicineDoneByDay(
  AppDatabase db,
  LocalDate start,
  LocalDate end,
) async {
  final doses = await MedicineRepositoryImpl(db).dosesInRange(start, end);
  final result = <LocalDate, DateTime>{};
  for (final dose in doses) {
    if (dose.storedStatus != MedicineDoseStatus.done) continue;
    final changedAt = dose.statusChangedAt;
    if (changedAt == null) continue;
    final day = localDayKey(changedAt);
    final existing = result[day];
    if (existing == null || changedAt.isBefore(existing)) {
      result[day] = changedAt;
    }
  }
  return result;
}

/// Prayer's "first prayed action of the day," plus the most common
/// prayer name behind it (for the `{prayer}` placeholder in
/// `habitStackSuggestionPrayerToWater`) — a plain 'record.prayerDate' is
/// already the bucket key (no `localDayKey` needed, unlike Medicine's
/// `scheduledFor`).
Future<({Map<LocalDate, DateTime> byDay, String? modeLabel})>
_prayerPrayedByDay(AppDatabase db, LocalDate start, LocalDate end) async {
  final records = await PrayerRepositoryImpl(db).recordsInRange(start, end);
  final byDay = <LocalDate, DateTime>{};
  final labelByDay = <LocalDate, String>{};
  for (final record in records) {
    if (record.storedStatus != PrayerStatus.prayed) continue;
    final changedAt = record.statusChangedAt;
    if (changedAt == null) continue;
    final day = record.prayerDate;
    final existing = byDay[day];
    if (existing == null || changedAt.isBefore(existing)) {
      byDay[day] = changedAt;
      labelByDay[day] = _titleCase(record.prayerName.name);
    }
  }
  return (byDay: byDay, modeLabel: _modeLabel(labelByDay));
}

String? _modeLabel(Map<LocalDate, String> labels) {
  if (labels.isEmpty) return null;
  final counts = <String, int>{};
  for (final label in labels.values) {
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return sorted.first.key;
}

String _titleCase(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/stacking/habit_stack_suggestion_evaluator_test.dart | tail -10`
Expected: PASS (3 tests).

- [ ] **Step 5: Wire the two app-resume trigger points**

In `lib/main.dart`, add the import:

```dart
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_evaluator.dart';
```

Change:

```dart
      // Re-planning trigger 1 (`strategies/notifications.md`): always
      // top up on app start; `_AppLifecycleReplanner` below repeats this on
      // every subsequent resume.
      unawaited(planAndApplyNotifications(db: db));
```

to:

```dart
      // Re-planning trigger 1 (`strategies/notifications.md`): always
      // top up on app start; `_AppLifecycleReplanner` below repeats this on
      // every subsequent resume.
      unawaited(planAndApplyNotifications(db: db));
      // Habit-stacking suggestions piggyback on the same trigger — no
      // new timer, no new call site (`docs/superpowers/specs/
      // 02-delightful/04-habit-stacking-suggestions-design.md`).
      unawaited(evaluateStackSuggestions(db: db));
```

And change:

```dart
    if (state == AppLifecycleState.resumed) {
      unawaited(planAndApplyNotifications(db: ref.read(databaseProvider)));
      unawaited(refreshAllWidgets(ref.read(databaseProvider)));
      unawaited(syncWearableData(ref.read(databaseProvider)));
    }
```

to:

```dart
    if (state == AppLifecycleState.resumed) {
      unawaited(planAndApplyNotifications(db: ref.read(databaseProvider)));
      unawaited(evaluateStackSuggestions(db: ref.read(databaseProvider)));
      unawaited(refreshAllWidgets(ref.read(databaseProvider)));
      unawaited(syncWearableData(ref.read(databaseProvider)));
    }
```

- [ ] **Step 6: Analyze and format**

Run: `flutter analyze lib/core/stacking/habit_stack_suggestion_evaluator.dart lib/main.dart | tail -10`
Run: `dart format lib/core/stacking/habit_stack_suggestion_evaluator.dart lib/main.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/core/stacking/habit_stack_suggestion_evaluator.dart \
  lib/main.dart \
  test/core/stacking/habit_stack_suggestion_evaluator_test.dart
git commit -m "feat(stacking): wire the correlation evaluator to the app-resume trigger"
```

---

### Task 4: Dashboard suggestion card + l10n

**Files:**
- Create: `lib/features/dashboard/presentation/widgets/habit_stack_suggestion_card.dart`
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart:69-71`
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`
- Test: `test/features/dashboard/presentation/widgets/habit_stack_suggestion_card_test.dart`

**Interfaces:**
- Consumes: `HabitStackSuggestionRepository`/
  `pendingHabitStackSuggestionProvider`/`habitStackSuggestionRepositoryProvider`
  (Task 2), `WaterRepository.updateReminderSettings` (pre-existing,
  `water_repository_impl.dart:290`).

- [ ] **Step 1: Add l10n keys to both arb files**

In `lib/core/l10n/app_en.arb`, insert after the `"searchNoResults"` block
(immediately before `"medicineMarkDoneAction"`) — find this exact anchor
text:

```json
  "searchNoResults": "No results found",
  "@searchNoResults": {"description": "Shown when a search query matches nothing."},
  "medicineMarkDoneAction": "Mark done",
```

Replace it with:

```json
  "searchNoResults": "No results found",
  "@searchNoResults": {"description": "Shown when a search query matches nothing."},
  "habitStackSuggestionMedicineToWater": "You usually log water shortly after your morning dose — want your water reminder nudged to follow it?",
  "@habitStackSuggestionMedicineToWater": {
    "description": "Dashboard suggestion card copy: medicine -> water habit-stacking pattern detected."
  },
  "habitStackSuggestionPrayerToWater": "You usually log water shortly after {prayer} — want your water reminder nudged to follow it?",
  "@habitStackSuggestionPrayerToWater": {
    "description": "Dashboard suggestion card copy: prayer -> water habit-stacking pattern detected.",
    "placeholders": {"prayer": {"type": "String"}}
  },
  "habitStackSuggestionAccept": "Nudge my reminder",
  "@habitStackSuggestionAccept": {
    "description": "Accepts a habit-stacking suggestion."
  },
  "habitStackSuggestionDismiss": "Not now",
  "@habitStackSuggestionDismiss": {
    "description": "Dismisses a habit-stacking suggestion (re-offered after a 30-day cooldown if the pattern still holds)."
  },
  "medicineMarkDoneAction": "Mark done",
```

In `lib/core/l10n/app_bn.arb`, insert after the `"searchNoResults"` line
(immediately before `"medicineMarkDoneAction"`) — find this exact anchor
text:

```json
  "searchNoResults": "কোনো ফলাফল পাওয়া যায়নি",
  "medicineMarkDoneAction": "সম্পন্ন হিসেবে চিহ্নিত করুন",
```

Replace it with:

```json
  "searchNoResults": "কোনো ফলাফল পাওয়া যায়নি",
  "habitStackSuggestionMedicineToWater": "আপনি সাধারণত সকালের ওষুধ খাওয়ার পরপরই পানি পান করেন — আপনার পানির রিমাইন্ডার সেই সময় অনুযায়ী সরিয়ে দিতে চান?",
  "habitStackSuggestionPrayerToWater": "আপনি সাধারণত {prayer} এর পরপরই পানি পান করেন — আপনার পানির রিমাইন্ডার সেই সময় অনুযায়ী সরিয়ে দিতে চান?",
  "habitStackSuggestionAccept": "আমার রিমাইন্ডার সরান",
  "habitStackSuggestionDismiss": "এখন না",
  "medicineMarkDoneAction": "সম্পন্ন হিসেবে চিহ্নিত করুন",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n | tail -10`
Expected: no errors.

- [ ] **Step 3: Write the failing widget test**

Create `test/features/dashboard/presentation/widgets/habit_stack_suggestion_card_test.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/stacking/habit_stack_correlation_usecase.dart';
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_repository.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/habit_stack_suggestion_card.dart';
import 'package:habit_tracker/features/water/data/repositories/water_repository_impl.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: HabitStackSuggestionCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('renders nothing when there is no pending suggestion', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.byType(Card), findsNothing);
    await disposeTree(tester);
  });

  testWidgets(
    'shows the medicine->water copy and both actions for a pending '
    'suggestion',
    (tester) async {
      final repository = HabitStackSuggestionRepository(db);
      await repository.upsertEvaluation(
        id: 'medicine_water',
        sourceModuleId: 'medicine',
        targetModuleId: 'water',
        result: const StackCorrelationResult(
          qualifyingDays: 6,
          totalDaysWithSource: 7,
          medianGapMinutes: 20,
          typicalSourceTime: LocalTime(8, 15),
        ),
        now: DateTime.utc(2026, 7, 1),
      );

      await pumpCard(tester);

      expect(
        find.text(
          'You usually log water shortly after your morning dose — want '
          'your water reminder nudged to follow it?',
        ),
        findsOneWidget,
      );
      expect(find.text('Nudge my reminder'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'tapping Nudge my reminder accepts the suggestion and applies the '
    "typical time to every weekday's reminder window",
    (tester) async {
      final repository = HabitStackSuggestionRepository(db);
      await repository.upsertEvaluation(
        id: 'medicine_water',
        sourceModuleId: 'medicine',
        targetModuleId: 'water',
        result: const StackCorrelationResult(
          qualifyingDays: 6,
          totalDaysWithSource: 7,
          medianGapMinutes: 20,
          typicalSourceTime: LocalTime(8, 15),
        ),
        now: DateTime.utc(2026, 7, 1),
      );

      await withClock(Clock.fixed(DateTime.utc(2026, 7, 2)), () async {
        await pumpCard(tester);
        await tester.tap(find.text('Nudge my reminder'));
        await tester.pumpAndSettle();
      });

      final row = await repository.byId('medicine_water');
      expect(row!.status, 'accepted');

      final waterSettings = await WaterRepositoryImpl(db).watchSettings().first;
      for (var weekday = 1; weekday <= 7; weekday++) {
        expect(
          waterSettings.reminderWindowOverrides[weekday]?.start,
          const LocalTime(8, 15),
        );
      }

      await disposeTree(tester);
    },
  );

  testWidgets('tapping Not now dismisses the suggestion and hides the card', (
    tester,
  ) async {
    final repository = HabitStackSuggestionRepository(db);
    await repository.upsertEvaluation(
      id: 'medicine_water',
      sourceModuleId: 'medicine',
      targetModuleId: 'water',
      result: const StackCorrelationResult(
        qualifyingDays: 6,
        totalDaysWithSource: 7,
        medianGapMinutes: 20,
        typicalSourceTime: LocalTime(8, 15),
      ),
      now: DateTime.utc(2026, 7, 1),
    );

    await pumpCard(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
    final row = await repository.byId('medicine_water');
    expect(row!.status, 'dismissed');

    await disposeTree(tester);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/dashboard/presentation/widgets/habit_stack_suggestion_card_test.dart | tail -10`
Expected: FAIL to compile — `habit_stack_suggestion_card.dart` doesn't
exist yet.

- [ ] **Step 5: Write the implementation**

Create `lib/features/dashboard/presentation/widgets/habit_stack_suggestion_card.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/stacking/habit_stack_suggestion_repository.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';

/// Dashboard card surfacing a pending habit-stacking suggestion — a
/// `Card`, not a snackbar (needs to stay visible with two actions,
/// `docs/superpowers/specs/02-delightful/
/// 04-habit-stacking-suggestions-design.md`'s "UI surface"). Renders
/// nothing when there's no pending suggestion.
class HabitStackSuggestionCard extends ConsumerWidget {
  /// Creates the suggestion card.
  const HabitStackSuggestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = ref.watch(pendingHabitStackSuggestionProvider).value;
    if (suggestion == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final message = suggestion.sourceModuleId == 'medicine'
        ? l10n.habitStackSuggestionMedicineToWater
        : l10n.habitStackSuggestionPrayerToWater(
            suggestion.sourceLabel ?? suggestion.sourceModuleId,
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _dismiss(ref, suggestion.id),
                  child: Text(l10n.habitStackSuggestionDismiss),
                ),
                FilledButton(
                  onPressed: () => _accept(ref, suggestion),
                  child: Text(l10n.habitStackSuggestionAccept),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismiss(WidgetRef ref, String id) => ref
      .read(habitStackSuggestionRepositoryProvider)
      .dismiss(id, now: clock.now());

  Future<void> _accept(
    WidgetRef ref,
    HabitStackSuggestionRow suggestion,
  ) async {
    final now = clock.now();
    await ref
        .read(habitStackSuggestionRepositoryProvider)
        .accept(suggestion.id, now: now);

    // Applies the nudge to every weekday, not just the weekdays that
    // happened to contribute a qualifying day: `habit_stack_suggestions`
    // stores one aggregate `typicalSourceTime`, not a per-weekday
    // breakdown, so "whichever weekdays contributed" (the design doc's
    // UI-surface note) reduces to "every weekday" given this table's
    // actual columns (this plan's Global Constraints).
    final waterRepository = ref.read(waterRepositoryProvider);
    final currentSettings = await waterRepository.watchSettings().first;
    final typicalTime = LocalTime.parse(suggestion.typicalSourceTime);
    final overrides = {
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: (
          start: typicalTime,
          end:
              currentSettings.reminderWindowOverrides[weekday]?.end ??
              currentSettings.reminderWindowEnd,
        ),
    };
    await waterRepository.updateReminderSettings(
      enabled: currentSettings.reminderEnabled,
      intervalMinutes: currentSettings.reminderIntervalMinutes,
      windowStart: currentSettings.reminderWindowStart,
      windowEnd: currentSettings.reminderWindowEnd,
      windowOverrides: overrides,
    );
  }
}
```

- [ ] **Step 6: Wire the card into the dashboard**

In `lib/features/dashboard/presentation/screens/dashboard_screen.dart`,
add the import:

```dart
import 'package:habit_tracker/features/dashboard/presentation/widgets/habit_stack_suggestion_card.dart';
```

Change:

```dart
                children: [
                  _DayCompletionIndicator(modules: modules),
                  const SizedBox(height: 16),
                  _UpcomingStrip(modules: modules),
                  const SizedBox(height: 16),
                  _QuickActionsRow(modules: modules),
                  const SizedBox(height: 16),
                  for (final module in modules) module.dashboardSummary(ref),
                ],
```

to:

```dart
                children: [
                  _DayCompletionIndicator(modules: modules),
                  const SizedBox(height: 16),
                  _UpcomingStrip(modules: modules),
                  const SizedBox(height: 16),
                  const HabitStackSuggestionCard(),
                  const SizedBox(height: 16),
                  _QuickActionsRow(modules: modules),
                  const SizedBox(height: 16),
                  for (final module in modules) module.dashboardSummary(ref),
                ],
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/features/dashboard/presentation/widgets/habit_stack_suggestion_card_test.dart | tail -10`
Expected: PASS (4 tests).

- [ ] **Step 8: Analyze and format**

Run: `flutter analyze lib/features/dashboard/presentation/widgets/habit_stack_suggestion_card.dart lib/features/dashboard/presentation/screens/dashboard_screen.dart | tail -10`
Run: `dart format lib/features/dashboard/presentation/widgets/habit_stack_suggestion_card.dart lib/features/dashboard/presentation/screens/dashboard_screen.dart`
Expected: `No issues found!`

- [ ] **Step 9: Full sweep**

Run: `flutter analyze | tail -10`
Expected: `No issues found!`

Run: `dart format --output=none --set-exit-if-changed . | tail -10`
Expected: exits 0.

- [ ] **Step 10: Commit**

```bash
git add lib/features/dashboard/presentation/widgets/habit_stack_suggestion_card.dart \
  lib/features/dashboard/presentation/screens/dashboard_screen.dart \
  lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  test/features/dashboard/presentation/widgets/habit_stack_suggestion_card_test.dart
git commit -m "feat(dashboard): add the habit-stacking suggestion card"
```

---

## After all tasks

Per this repo's CLAUDE.md spec-implementation workflow: once every task
above is committed, open a PR for the spec with the design summary in the
description, then run a code review against the finished PR (comment →
fix → commit cycle, up to 5 rounds), then stop and wait for the user's
own review and merge.

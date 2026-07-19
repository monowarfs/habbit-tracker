# Dashboard, Reports, Achievements (Run 15) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Run 15 — dashboard day-completion/upcoming-strip/quick-actions,
cross-module weekly/monthly/yearly reports, an achievement/badge engine,
longest-streak records, cross-module search, and a global month calendar —
per `docs/superpowers/specs/2026-07-19-dashboard-reports-achievements-design.md`.

**Architecture:** Extend the `HabitModule` contract with five new methods
(`dayStatus`, `nextUpcoming`, `quickActions`, `search`,
`achievementDefinitions`) that Water/Medicine/Prayer each implement against
their own existing repositories/use cases. Everything else (Reports,
Achievements, global calendar, search UI, dashboard rewrite) is new `core/`
and `features/` code that consumes those five methods uniformly through
`habitModulesProvider` — no module-id branching anywhere in `core/`.

**Tech Stack:** Flutter, Riverpod (codegen, `@riverpod`/`@Riverpod(keepAlive:
true)`), Drift (`achievements` table, already schema-only in the DB), GoRouter,
`fl_chart` via the existing `PeriodBarChart`, `gen_l10n` (en/bn), `mocktail`
(module unit tests), in-memory Drift (`NativeDatabase.memory()`) for
repository/widget tests.

## Global Constraints

- `flutter analyze` must stay clean after every task (`very_good_analysis`
  lint set, `public_member_api_docs` enforced — every new public class/
  member needs a doc comment, one line unless a WHY needs explaining).
- `dart format --output=none --set-exit-if-changed .` clean after every task.
- No raw user-facing strings — every new string goes through
  `AppLocalizations` with an en (`lib/core/l10n/app_en.arb`) and bn
  (`lib/core/l10n/app_bn.arb`) entry, each with an `"@key": {"description":
  "..."}` metadata block, matching the existing arb files' format exactly.
- Domain logic (`core/reports/`, `core/achievements/`, module `dayStatus`/
  `achievementDefinitions` closures) must use `clock.now()` (`package:
  clock`), never `DateTime.now()` directly — every existing use case in this
  codebase follows this rule so tests can inject a fixed clock.
  `localDayKey()` (`lib/core/utils/local_day.dart`) is this codebase's
  DST-safe local-day bucketing helper — reuse it, don't hand-roll date math.
  `generateId()` (`lib/core/utils/uuid.dart`) generates UUID v7 (D-12) for
  any new row id.
- Row identifiers: UUID v7 via `generateId()`. Timestamps in new Drift
  tables/columns: UTC epoch millis (`int`), matching every existing table.
- New Riverpod providers: `@Riverpod(keepAlive: true)` for anything wrapping
  a repository/engine singleton (matches `waterRepositoryProvider`,
  `medicineRepositoryProvider`, `habitModulesProvider`); plain `@riverpod`
  for derived/computed values.
- `core/` code must never import a module's internal (`domain`/`data`)
  files directly — only `HabitModule`/`habitModulesProvider`. This is the
  decoupling rule `architecture.md` states and this run's DoD proves with a
  widget test.
- No new third-party dependencies — everything in this plan is buildable
  from packages already in `pubspec.yaml` (`fl_chart`, `drift`,
  `flutter_riverpod`, `go_router`) plus Flutter's own `showSearch`/
  `SearchDelegate`.
- One conventional commit per task on the feature branch is fine (this
  plan's "frequent commits" — squashed to the run's single DoD commit,
  `feat(dashboard): cross-module dashboard, reports, achievements`, at
  merge time per `docs/engineering/git-strategy.md`, not by this plan).

---

## File Structure

**New files:**
- `lib/core/utils/date_range.dart` — `DateRange` value type.
- `lib/core/reports/day_status_streaks.dart` — pure `longestStreak`/
  `currentStreak` functions over a `dayStatus()` map.
- `lib/core/reports/aggregate_report_usecase.dart` — `ReportPeriod` enum +
  `AggregateReportUseCase`, period-bucketing for Reports.
- `lib/core/achievements/achievement_repository.dart` — Drift-backed CRUD
  over the `achievements` table.
- `lib/core/achievements/achievement_engine.dart` — `AchievementEngine`,
  evaluates one module's `achievementDefinitions` and persists progress/
  unlock state.
- `lib/core/achievements/achievement_providers.dart` — `@riverpod` wiring
  for the repository/engine.
- `lib/core/widgets/global_month_calendar.dart` — `GlobalMonthCalendar`
  widget + `combinedDayStatusKind` pure helper.
- `lib/features/reports/presentation/providers/reports_providers.dart`
- `lib/features/reports/presentation/screens/reports_screen.dart`
- `lib/features/achievements/presentation/providers/achievement_providers.dart`
- `lib/features/achievements/presentation/screens/achievement_gallery_screen.dart`
- `lib/features/dashboard/presentation/search/app_search_delegate.dart`
- Test files mirroring every source file above under `test/`.

**Modified files:**
- `lib/core/modules/habit_module.dart` — new types + 5 abstract methods.
- `lib/core/database/tables/achievements_table.dart` — doc-comment fix.
- `lib/features/water/water_module.dart`,
  `lib/features/medicine/medicine_module.dart`,
  `lib/features/prayer/prayer_module.dart` — implement the 5 new methods.
- `lib/features/water/presentation/providers/water_controller.dart`,
  `lib/features/medicine/presentation/providers/medicine_controller.dart`,
  `lib/features/prayer/presentation/providers/prayer_controller.dart` —
  call `AchievementEngine.evaluate(moduleId)` after their write.
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` —
  full rewrite.
- `lib/core/router/app_router.dart` — add `/reports`, `/achievements` routes.
- `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb` — new keys.
- `docs/product/functional-requirements.md` (FR-C-11..16),
  `docs/product/decisions.md` (D-16..19),
  `docs/technical/database-design.md` (achievements table comment),
  `docs/engineering/phases-and-dod.md`, `docs/product/roadmap.md`,
  `docs/product/feature-breakdown.md` (Run 15 sections), `CLAUDE.md`
  (project-state paragraph) — Task 17.

---

### Task 1: `DateRange` value type

**Files:**
- Create: `lib/core/utils/date_range.dart`
- Test: `test/core/utils/date_range_test.dart`

**Interfaces:**
- Produces: `class DateRange { const DateRange({required LocalDate start,
  required LocalDate end}); final LocalDate start; final LocalDate end; }`
  — every later task's `dayStatus`/report/calendar code takes this type.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

void main() {
  test('DateRange holds its start/end and supports equality', () {
    const a = DateRange(start: LocalDate(2026, 6, 1), end: LocalDate(2026, 6, 7));
    const b = DateRange(start: LocalDate(2026, 6, 1), end: LocalDate(2026, 6, 7));
    expect(a, b);
    expect(a.start, const LocalDate(2026, 6, 1));
    expect(a.end, const LocalDate(2026, 6, 7));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/date_range_test.dart`
Expected: FAIL — `date_range.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:meta/meta.dart';

/// An inclusive local-day range (`[start, end]`) — the shared parameter
/// type for `HabitModule.dayStatus`, Reports' period bucketing, and the
/// global calendar's month window (D-17,
/// `../../../docs/superpowers/specs/2026-07-19-dashboard-reports-achievements-design.md`).
@immutable
class DateRange {
  /// Creates an inclusive date range from [start] to [end].
  const DateRange({required this.start, required this.end});

  /// The first day in the range, inclusive.
  final LocalDate start;

  /// The last day in the range, inclusive.
  final LocalDate end;

  @override
  bool operator ==(Object other) =>
      other is DateRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '${start.toIso()}..${end.toIso()}';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/date_range_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/date_range.dart test/core/utils/date_range_test.dart
git commit -m "feat(core): add DateRange value type"
```

---

### Task 2: Extend the `HabitModule` contract

**Files:**
- Modify: `lib/core/modules/habit_module.dart`
- Modify: `lib/features/water/water_module.dart`
- Modify: `lib/features/medicine/medicine_module.dart`
- Modify: `lib/features/prayer/prayer_module.dart`
- Modify: `lib/core/database/tables/achievements_table.dart`
- Modify: `docs/technical/database-design.md`

**Interfaces:**
- Consumes: `DateRange` (Task 1).
- Produces: `ModuleDayStatusKind` enum, `ModuleDayStatus` class,
  `SearchResult` class, `AchievementDefinition` class, and 5 new
  `HabitModule` abstract members —
  `Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range)`,
  `Widget? nextUpcoming(WidgetRef ref)`,
  `List<Widget> quickActions(WidgetRef ref)`,
  `Future<List<SearchResult>> search(String query)`,
  `List<AchievementDefinition> get achievementDefinitions`. Every later
  task relies on these exact names/signatures.

This task adds the contract and gives all three existing modules a
**stub** implementation (`dayStatus` returns every day in range as `none`,
`nextUpcoming` returns `null`, `quickActions`/`search`/
`achievementDefinitions` return `[]`) — just enough for the app to keep
compiling. Tasks 4-6 replace each module's stub with its real
implementation, one module at a time, independently reviewable.

- [ ] **Step 1: Add the new types and abstract methods to the contract**

Add to `lib/core/modules/habit_module.dart` (after the existing
`ModuleExport` class, before `abstract class HabitModule`):

```dart
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// How a module's day went, for the global calendar / Reports / the
/// dashboard's day-completion indicator (D-17).
enum ModuleDayStatusKind {
  /// Every relevant item for the day was completed.
  complete,

  /// Some but not all relevant items were completed.
  partial,

  /// Nothing was completed and the day is fully resolved (not still in
  /// progress).
  missed,

  /// No data for this day (before the module's first use, or a day still
  /// in progress with nothing logged yet).
  none,
}

/// One day's status for a module, plus its natural numeric value (ml
/// logged, doses taken, prayers completed) for report charts.
@immutable
class ModuleDayStatus {
  /// Creates a day status.
  const ModuleDayStatus({required this.kind, required this.value});

  /// This day's completion category.
  final ModuleDayStatusKind kind;

  /// This day's value in the module's own natural unit.
  final num value;
}

/// One cross-module search hit (D-18).
@immutable
class SearchResult {
  /// Creates a search result.
  const SearchResult({
    required this.title,
    required this.subtitle,
    required this.deepLinkRoute,
  });

  /// The matched record's display title (e.g. a medicine's name).
  final String title;

  /// Secondary detail shown under the title.
  final String subtitle;

  /// Route to open on tap (FR-C-09-style deep link).
  final String deepLinkRoute;
}

/// One achievement a module contributes to the shared engine
/// (`core/achievements/achievement_engine.dart`, D-16). [currentProgress]
/// is a closure over the module's own repository/use cases — the engine
/// never queries a module's data directly.
@immutable
class AchievementDefinition {
  /// Creates an achievement definition.
  const AchievementDefinition({
    required this.key,
    required this.moduleId,
    required this.titleKey,
    required this.descriptionKey,
    required this.target,
    required this.currentProgress,
  });

  /// Stable key (e.g. `'water_7_day_streak'`), the `achievements.key`
  /// column and this achievement's identity across re-evaluations.
  final String key;

  /// Which module this achievement belongs to.
  final String moduleId;

  /// `AppLocalizations` key naming this achievement's title.
  final String titleKey;

  /// `AppLocalizations` key naming this achievement's description.
  final String descriptionKey;

  /// Progress needed to unlock.
  final int target;

  /// Computes current progress toward [target] from live data.
  final Future<int> Function() currentProgress;
}
```

Add these 5 members inside `abstract class HabitModule` (after
`onNotificationAction`, before `exportData`):

```dart
  /// Per-day status for [range] — used by the global calendar (as-is),
  /// Reports (bucketed by period), and the dashboard's day-completion
  /// indicator (today's entry only). D-17.
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range);

  /// The next actionable item this module wants surfaced on the
  /// dashboard's upcoming strip, or `null` if there's nothing upcoming.
  /// D-19.
  Widget? nextUpcoming(WidgetRef ref);

  /// One-tap actions this module wants exposed on the dashboard's
  /// quick-actions row. Empty list if none. D-19.
  List<Widget> quickActions(WidgetRef ref);

  /// Free-text search over this module's own named user data. Modules
  /// with nothing free-text-searchable return `[]`. D-18.
  Future<List<SearchResult>> search(String query);

  /// Achievement definitions this module contributes, evaluated by
  /// `core/achievements/achievement_engine.dart`. D-16.
  List<AchievementDefinition> get achievementDefinitions;
```

- [ ] **Step 2: Run analyze to confirm the expected compile break**

Run: `flutter analyze`
Expected: errors in `water_module.dart`/`medicine_module.dart`/
`prayer_module.dart` — "Missing concrete implementations" for the 5 new
members. This is expected; Step 3 fixes it.

- [ ] **Step 3: Add stub implementations to all three modules**

In `lib/features/water/water_module.dart`, add (inside `class
WaterModule`, after `onNotificationAction`, before `exportData`):

```dart
  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    final result = <LocalDate, ModuleDayStatus>{};
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      result[day] = const ModuleDayStatus(kind: ModuleDayStatusKind.none, value: 0);
      day = day.addDays(1);
    }
    return result;
  }

  @override
  Widget? nextUpcoming(WidgetRef ref) => null;

  @override
  List<Widget> quickActions(WidgetRef ref) => const [];

  @override
  Future<List<SearchResult>> search(String query) async => const [];

  @override
  List<AchievementDefinition> get achievementDefinitions => const [];
```

Add the identical 6 members (same bodies) to `MedicineModule` in
`lib/features/medicine/medicine_module.dart` and to `PrayerModule` in
`lib/features/prayer/prayer_module.dart`, in the same position (after
`onNotificationAction`, before `exportData`).

- [ ] **Step 4: Run analyze and existing tests to confirm the app compiles again**

Run: `flutter analyze && flutter test`
Expected: `flutter analyze` clean; all existing tests still PASS (stubs
don't change any existing behavior).

- [ ] **Step 5: Fix the achievements table doc comment**

In `lib/core/database/tables/achievements_table.dart`, replace:

```dart
/// Schema-only groundwork (`database-design.md`) — no achievement UI/logic
/// ships in v1.0; this table exists so a future gamification feature has a
/// home without a schema migration.
```

with:

```dart
/// Backs the achievement/badge engine (`core/achievements/`, Run 15's
/// `docs/superpowers/specs/2026-07-19-dashboard-reports-achievements-design.md`).
/// Was schema-only groundwork through v1.0 — this is the first run to
/// read/write it.
```

In `docs/technical/database-design.md`, find the `### \`achievements\``
section and replace the paragraph starting "Schema-only groundwork per
this run's explicit requirement — **no achievement UI/logic ships in
v1.0**..." with:

```markdown
Backs the achievement/badge engine added in Run 15
(`../superpowers/specs/2026-07-19-dashboard-reports-achievements-design.md`).
Was schema-only groundwork through v1.0 (no achievement UI/logic shipped
before then) — this table's shape was fixed early so that run needed no
migration.
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/modules/habit_module.dart lib/features/water/water_module.dart \
  lib/features/medicine/medicine_module.dart lib/features/prayer/prayer_module.dart \
  lib/core/database/tables/achievements_table.dart docs/technical/database-design.md
git commit -m "feat(core): extend HabitModule contract with dayStatus/nextUpcoming/quickActions/search/achievementDefinitions"
```

---

### Task 3: `core/reports/day_status_streaks.dart` — shared streak math

**Files:**
- Create: `lib/core/reports/day_status_streaks.dart`
- Test: `test/core/reports/day_status_streaks_test.dart`

**Interfaces:**
- Consumes: `ModuleDayStatus`, `ModuleDayStatusKind` (Task 2), `LocalDate`.
- Produces: `int longestStreak(Map<LocalDate, ModuleDayStatus> dayStatus)`,
  `int currentStreak(Map<LocalDate, ModuleDayStatus> dayStatus, LocalDate
  today)` — reused by Reports (Task 12, longest) and by Medicine's
  achievement definitions (Task 5, current).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

ModuleDayStatus _s(ModuleDayStatusKind kind) =>
    ModuleDayStatus(kind: kind, value: 0);

void main() {
  group('longestStreak', () {
    test('finds the longest run of complete days, ignoring gaps', () {
      final map = {
        const LocalDate(2026, 6, 1): _s(ModuleDayStatusKind.complete),
        const LocalDate(2026, 6, 2): _s(ModuleDayStatusKind.complete),
        const LocalDate(2026, 6, 3): _s(ModuleDayStatusKind.missed),
        const LocalDate(2026, 6, 4): _s(ModuleDayStatusKind.complete),
        const LocalDate(2026, 6, 5): _s(ModuleDayStatusKind.complete),
        const LocalDate(2026, 6, 6): _s(ModuleDayStatusKind.complete),
      };
      expect(longestStreak(map), 3);
    });

    test('empty map has zero longest streak', () {
      expect(longestStreak(const {}), 0);
    });
  });

  group('currentStreak', () {
    test('counts consecutive complete days ending at today', () {
      final map = {
        const LocalDate(2026, 6, 1): _s(ModuleDayStatusKind.missed),
        const LocalDate(2026, 6, 2): _s(ModuleDayStatusKind.complete),
        const LocalDate(2026, 6, 3): _s(ModuleDayStatusKind.complete),
      };
      expect(currentStreak(map, const LocalDate(2026, 6, 3)), 2);
    });

    test('a missed today breaks the current streak to zero', () {
      final map = {
        const LocalDate(2026, 6, 1): _s(ModuleDayStatusKind.complete),
        const LocalDate(2026, 6, 2): _s(ModuleDayStatusKind.missed),
      };
      expect(currentStreak(map, const LocalDate(2026, 6, 2)), 0);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/reports/day_status_streaks_test.dart`
Expected: FAIL — `day_status_streaks.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// The longest run of consecutive `complete` days in [dayStatus], sorted
/// by date — the shared building block behind every module's
/// longest-streak record in Reports (D-17).
int longestStreak(Map<LocalDate, ModuleDayStatus> dayStatus) {
  final days = dayStatus.keys.toList()..sort();
  var longest = 0;
  var running = 0;
  for (final day in days) {
    if (dayStatus[day]!.kind == ModuleDayStatusKind.complete) {
      running += 1;
      longest = running > longest ? running : longest;
    } else {
      running = 0;
    }
  }
  return longest;
}

/// The run of consecutive `complete` days ending at (and including)
/// [today] in [dayStatus] — used by achievement definitions that need
/// "how close am I right now," not the all-time record.
int currentStreak(Map<LocalDate, ModuleDayStatus> dayStatus, LocalDate today) {
  var running = 0;
  var day = today;
  while (dayStatus[day]?.kind == ModuleDayStatusKind.complete) {
    running += 1;
    day = day.addDays(-1);
  }
  return running;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/reports/day_status_streaks_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/reports/day_status_streaks.dart test/core/reports/day_status_streaks_test.dart
git commit -m "feat(core): add longestStreak/currentStreak over a dayStatus map"
```

---

### Task 4: Water module — real `dayStatus`/`nextUpcoming`/`quickActions`/`search`/`achievementDefinitions`

**Files:**
- Modify: `lib/features/water/water_module.dart`
- Test: `test/features/water/water_module_test.dart` (extend existing file)

**Interfaces:**
- Consumes: `DateRange`, `ModuleDayStatus(Kind)`, `SearchResult`,
  `AchievementDefinition` (Task 2); `WaterRepository.watchEntriesInRange`/
  `allGoals`/`allEntries` (existing); `CalculateWaterStreakUseCase`,
  `ResolveGoalForDateUseCase` (existing); `todaysWaterProgressProvider`,
  `waterSettingsProvider` (existing, `water_providers.dart`);
  `waterControllerProvider` (existing, `water_controller.dart`).
- Produces: Water's stub 5 methods replaced with real logic — no new
  public API beyond what Task 2 already declared.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/water/water_module_test.dart` (reuse the
existing `_FakeWaterRepository`, extending it with the methods `dayStatus`
needs):

```dart
// Add to _FakeWaterRepository:
class _FakeWaterRepository extends Fake implements WaterRepository {
  _FakeWaterRepository(this._settings, {List<WaterEntry>? entries, List<WaterGoal>? goals})
      : _entries = entries ?? const [],
        _goals = goals ?? const [];

  final WaterSettings _settings;
  final List<WaterEntry> _entries;
  final List<WaterGoal> _goals;
  int? capturedAmountMl;
  WaterEntrySource? capturedSource;

  @override
  Stream<WaterSettings> watchSettings() => Stream.value(_settings);

  @override
  Stream<List<WaterEntry>> watchEntriesInRange(LocalDate start, LocalDate end) =>
      Stream.value(
        _entries.where((e) {
          final day = localDayKey(e.loggedAt);
          return day.compareTo(start) >= 0 && day.compareTo(end) <= 0;
        }).toList(),
      );

  @override
  Future<List<WaterGoal>> allGoals() async => _goals;

  @override
  Future<List<WaterEntry>> allEntries() async => _entries;

  @override
  Future<Result<WaterEntry>> addEntry({
    required int amountMl,
    required DateTime loggedAt,
    required WaterEntrySource source,
  }) async {
    capturedAmountMl = amountMl;
    capturedSource = source;
    return Result.success(WaterEntry(id: 'x', amountMl: amountMl, loggedAt: loggedAt, source: source));
  }
}

// New test group, appended to main():
test('dayStatus classifies days as complete/partial/none against the goal', () async {
  final goal = WaterGoal(id: 'g1', goalMl: 2000, effectiveFrom: DateTime.utc(2026, 6, 1));
  final module = WaterModule(
    _FakeWaterRepository(
      _settings(reminderEnabled: false),
      goals: [goal],
      entries: [
        WaterEntry(id: 'e1', amountMl: 2000, loggedAt: DateTime.utc(2026, 6, 1, 9), source: WaterEntrySource.quick),
        WaterEntry(id: 'e2', amountMl: 500, loggedAt: DateTime.utc(2026, 6, 2, 9), source: WaterEntrySource.quick),
      ],
    ),
  );
  final status = await module.dayStatus(
    DateRange(start: const LocalDate(2026, 6, 1), end: const LocalDate(2026, 6, 3)),
  );
  expect(status[const LocalDate(2026, 6, 1)]!.kind, ModuleDayStatusKind.complete);
  expect(status[const LocalDate(2026, 6, 2)]!.kind, ModuleDayStatusKind.partial);
  expect(status[const LocalDate(2026, 6, 3)]!.kind, ModuleDayStatusKind.none);
  expect(status[const LocalDate(2026, 6, 1)]!.value, 2000);
});

test('search always returns empty (Water has no named entities)', () async {
  final module = WaterModule(_FakeWaterRepository(_settings(reminderEnabled: false)));
  expect(await module.search('anything'), isEmpty);
});

test('achievementDefinitions: water_first_log progress is 0 with no entries, 1 with one', () async {
  final empty = WaterModule(_FakeWaterRepository(_settings(reminderEnabled: false)));
  final firstLogEmpty = empty.achievementDefinitions.firstWhere((d) => d.key == 'water_first_log');
  expect(await firstLogEmpty.currentProgress(), 0);

  final withEntry = WaterModule(
    _FakeWaterRepository(
      _settings(reminderEnabled: false),
      entries: [WaterEntry(id: 'e1', amountMl: 100, loggedAt: DateTime.utc(2026, 6, 1), source: WaterEntrySource.quick)],
    ),
  );
  final firstLog = withEntry.achievementDefinitions.firstWhere((d) => d.key == 'water_first_log');
  expect(await firstLog.currentProgress(), 1);
});
```

Add the needed imports to the top of the test file:
`import 'package:habit_tracker/core/modules/habit_module.dart';`,
`import 'package:habit_tracker/core/utils/date_range.dart';`,
`import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/water/water_module_test.dart`
Expected: FAIL — `dayStatus` still returns all-`none`, `achievementDefinitions`
still `[]`.

- [ ] **Step 3: Implement**

In `lib/features/water/water_module.dart`, add imports:

```dart
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/features/water/domain/usecases/calculate_water_streak.dart';
import 'package:habit_tracker/features/water/domain/usecases/resolve_goal_for_date.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';
```

(`water_providers.dart` is already imported for `todaysWaterProgressProvider`
— check before duplicating.) Replace the 5 stub members with:

```dart
  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    final entries = await _repository
        .watchEntriesInRange(range.start, range.end)
        .first;
    final goals = await _repository.allGoals();
    final totalsByDay = <LocalDate, int>{};
    for (final entry in entries) {
      final day = localDayKey(entry.loggedAt);
      totalsByDay[day] = (totalsByDay[day] ?? 0) + entry.amountMl;
    }
    const resolveGoal = ResolveGoalForDateUseCase();
    final result = <LocalDate, ModuleDayStatus>{};
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      final total = totalsByDay[day] ?? 0;
      final goal = resolveGoal.execute(goals, day);
      final kind = total == 0
          ? ModuleDayStatusKind.none
          : (goal.goalMl > 0 && total >= goal.goalMl)
              ? ModuleDayStatusKind.complete
              : ModuleDayStatusKind.partial;
      result[day] = ModuleDayStatus(kind: kind, value: total);
      day = day.addDays(1);
    }
    return result;
  }

  @override
  Widget? nextUpcoming(WidgetRef ref) {
    final progress = ref.watch(todaysWaterProgressProvider);
    if (progress == null) return null;
    final remainingMl = progress.goalMl - progress.totalMl;
    if (remainingMl <= 0) return null;
    final unit = ref.watch(appSettingsProvider).value?.waterUnit ?? WaterUnit.ml;
    return Builder(
      builder: (context) => Chip(
        avatar: const Icon(Icons.water_drop, size: 16),
        label: Text(formatWaterAmount(context, remainingMl, unit)),
      ),
    );
  }

  @override
  List<Widget> quickActions(WidgetRef ref) {
    final settings = ref.watch(waterSettingsProvider).value;
    if (settings == null || settings.quickAddAmountsMl.isEmpty) return const [];
    final unit = ref.watch(appSettingsProvider).value?.waterUnit ?? WaterUnit.ml;
    final amountMl = settings.quickAddAmountsMl.first;
    return [
      Consumer(
        builder: (context, innerRef, _) => ActionChip(
          avatar: const Icon(Icons.add, size: 16),
          label: Text(formatWaterAmount(context, amountMl, unit)),
          onPressed: () => innerRef.read(waterControllerProvider).logQuickAdd(amountMl),
        ),
      ),
    ];
  }

  @override
  Future<List<SearchResult>> search(String query) async => const [];

  @override
  List<AchievementDefinition> get achievementDefinitions => [
    AchievementDefinition(
      key: 'water_first_log',
      moduleId: id,
      titleKey: 'achievementWaterFirstLogTitle',
      descriptionKey: 'achievementWaterFirstLogDescription',
      target: 1,
      currentProgress: () async {
        final entries = await _repository.allEntries();
        return entries.isEmpty ? 0 : 1;
      },
    ),
    AchievementDefinition(
      key: 'water_streak_7',
      moduleId: id,
      titleKey: 'achievementWaterStreak7Title',
      descriptionKey: 'achievementWaterStreak7Description',
      target: 7,
      currentProgress: _currentWaterStreak,
    ),
    AchievementDefinition(
      key: 'water_streak_30',
      moduleId: id,
      titleKey: 'achievementWaterStreak30Title',
      descriptionKey: 'achievementWaterStreak30Description',
      target: 30,
      currentProgress: _currentWaterStreak,
    ),
    AchievementDefinition(
      key: 'water_streak_100',
      moduleId: id,
      titleKey: 'achievementWaterStreak100Title',
      descriptionKey: 'achievementWaterStreak100Description',
      target: 100,
      currentProgress: _currentWaterStreak,
    ),
    AchievementDefinition(
      key: 'water_perfect_week',
      moduleId: id,
      titleKey: 'achievementWaterPerfectWeekTitle',
      descriptionKey: 'achievementWaterPerfectWeekDescription',
      target: 1,
      currentProgress: _perfectWaterWeek,
    ),
  ];

  Future<int> _currentWaterStreak() async {
    final goals = await _repository.allGoals();
    if (goals.isEmpty) return 0;
    final today = localDayKey(clock.now());
    final earliest = goals
        .map((g) => localDayKey(g.effectiveFrom))
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    final entries = await _repository.watchEntriesInRange(earliest, today).first;
    final totals = <LocalDate, int>{};
    for (final entry in entries) {
      final day = localDayKey(entry.loggedAt);
      totals[day] = (totals[day] ?? 0) + entry.amountMl;
    }
    final result = const CalculateWaterStreakUseCase().execute(
      dailyTotalsMl: totals,
      goals: goals,
      earliestDay: earliest,
      today: today,
    );
    return result.current;
  }

  Future<int> _perfectWaterWeek() async {
    final today = localDayKey(clock.now());
    final status = await dayStatus(
      DateRange(start: today.addDays(-6), end: today),
    );
    final allComplete = status.values.every(
      (s) => s.kind == ModuleDayStatusKind.complete,
    );
    return allComplete ? 1 : 0;
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/water/water_module_test.dart`
Expected: PASS. Also run `flutter analyze` — clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/water/water_module.dart test/features/water/water_module_test.dart
git commit -m "feat(water): implement dayStatus/nextUpcoming/quickActions/search/achievementDefinitions"
```

---

### Task 5: Medicine module — real implementations

**Files:**
- Modify: `lib/features/medicine/medicine_module.dart`
- Test: `test/features/medicine/medicine_module_test.dart` (extend existing)

**Interfaces:**
- Consumes: `dayStatus`/etc. contract (Task 2); `currentStreak` (Task 3);
  `MedicineRepository.dosesInRange`/`allMedicines` (existing);
  `effectiveDoseStatus` (existing, `dose_status.dart`); `calculateAdherence`
  (existing, unused here but demonstrates the pattern is available);
  `todaysDoseViewsProvider` (existing, `medicine_providers.dart`);
  `medicineControllerProvider` (existing, `medicine_controller.dart`).
- Produces: Medicine's stub 5 methods replaced with real logic.

- [ ] **Step 1: Write the failing tests**

Add to `test/features/medicine/medicine_module_test.dart` (find the
existing fake repository class there and extend it the same way Task 4
did for Water — add `dosesInRange`/`allMedicines` support backed by
constructor-supplied lists):

```dart
test('dayStatus classifies a day complete when every dose that day is done', () async {
  final medicine = Medicine(
    id: 'm1', name: 'Vitamin D', dosageNote: null, stockEnabled: false,
    stockCount: null, stockThreshold: null, stopWhenStockDepleted: false,
    consumptionPerDose: 1, archivedAt: null,
  );
  final dose = MedicineDose(
    id: 'd1', medicineId: 'm1', scheduleId: 's1',
    scheduledFor: DateTime.utc(2026, 6, 1, 8),
    storedStatus: MedicineDoseStatus.done, graceWindowMinutes: 30,
  );
  final module = MedicineModule(
    _FakeMedicineRepository(doses: [dose], medicines: [medicine]),
  );
  final status = await module.dayStatus(
    DateRange(start: const LocalDate(2026, 6, 1), end: const LocalDate(2026, 6, 1)),
  );
  expect(status[const LocalDate(2026, 6, 1)]!.kind, ModuleDayStatusKind.complete);
  expect(status[const LocalDate(2026, 6, 1)]!.value, 1);
});

test('search matches medicine name and dosage note, case-insensitively', () async {
  final medicine = Medicine(
    id: 'm1', name: 'Paracetamol', dosageNote: '500mg', stockEnabled: false,
    stockCount: null, stockThreshold: null, stopWhenStockDepleted: false,
    consumptionPerDose: 1, archivedAt: null,
  );
  final module = MedicineModule(_FakeMedicineRepository(medicines: [medicine]));
  final results = await module.search('paracet');
  expect(results, hasLength(1));
  expect(results.first.title, 'Paracetamol');
  expect(results.first.deepLinkRoute, '/medicine/m1');
  expect(await module.search('nomatch'), isEmpty);
});
```

Add a minimal `_FakeMedicineRepository` (or extend the file's existing
one) implementing `dosesInRange`/`allMedicines` from constructor lists,
following the exact pattern used in Task 4's `_FakeWaterRepository`.
Check `lib/features/medicine/domain/entities/medicine.dart` and
`medicine_dose.dart` for the exact constructor field names before writing
these fixtures — copy them from there rather than guessing.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/medicine/medicine_module_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

In `lib/features/medicine/medicine_module.dart`, add imports:

```dart
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_controller.dart';
```

Replace the 5 stub members with:

```dart
  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    final doses = await _repository.dosesInRange(range.start, range.end);
    final now = clock.now();
    final byDay = <LocalDate, List<MedicineDose>>{};
    for (final dose in doses) {
      final day = localDayKey(dose.scheduledFor);
      (byDay[day] ??= []).add(dose);
    }
    final result = <LocalDate, ModuleDayStatus>{};
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      final dayDoses = byDay[day] ?? const [];
      if (dayDoses.isEmpty) {
        result[day] = const ModuleDayStatus(kind: ModuleDayStatusKind.none, value: 0);
        day = day.addDays(1);
        continue;
      }
      final statuses = dayDoses
          .map((d) => effectiveDoseStatus(
                storedStatus: d.storedStatus,
                scheduledFor: d.scheduledFor,
                now: now,
                graceWindowMinutes: d.graceWindowMinutes,
              ))
          .toList();
      final unresolved = statuses.any(
        (s) => s == MedicineDoseStatus.upcoming || s == MedicineDoseStatus.due,
      );
      final doneCount = statuses.where((s) => s == MedicineDoseStatus.done).length;
      final kind = unresolved
          ? ModuleDayStatusKind.none
          : doneCount == statuses.length
              ? ModuleDayStatusKind.complete
              : doneCount == 0
                  ? ModuleDayStatusKind.missed
                  : ModuleDayStatusKind.partial;
      result[day] = ModuleDayStatus(kind: kind, value: doneCount);
      day = day.addDays(1);
    }
    return result;
  }

  @override
  Widget? nextUpcoming(WidgetRef ref) {
    final views = ref.watch(todaysDoseViewsProvider);
    if (views == null) return null;
    MedicineDoseView? next;
    for (final view in views) {
      if (view.effectiveStatus == MedicineDoseStatus.due ||
          view.effectiveStatus == MedicineDoseStatus.upcoming) {
        next = view;
        break;
      }
    }
    if (next == null) return null;
    return Builder(
      builder: (context) => Chip(
        avatar: const Icon(Icons.medication, size: 16),
        label: Text(next!.medicine.name),
      ),
    );
  }

  @override
  List<Widget> quickActions(WidgetRef ref) {
    final views = ref.watch(todaysDoseViewsProvider);
    if (views == null) return const [];
    final due = views.where((v) => v.effectiveStatus == MedicineDoseStatus.due);
    if (due.isEmpty) return const [];
    final doseId = due.first.dose.id;
    return [
      Consumer(
        builder: (context, innerRef, _) => ActionChip(
          avatar: const Icon(Icons.check, size: 16),
          label: const Text('Mark done'),
          onPressed: () =>
              innerRef.read(medicineControllerProvider).markDoseDone(doseId),
        ),
      ),
    ];
  }

  @override
  Future<List<SearchResult>> search(String query) async {
    final medicines = await _repository.allMedicines();
    final lowerQuery = query.toLowerCase();
    return [
      for (final medicine in medicines)
        if (medicine.name.toLowerCase().contains(lowerQuery) ||
            (medicine.dosageNote?.toLowerCase().contains(lowerQuery) ?? false))
          SearchResult(
            title: medicine.name,
            subtitle: medicine.dosageNote ?? '',
            deepLinkRoute: '/medicine/${medicine.id}',
          ),
    ];
  }

  @override
  List<AchievementDefinition> get achievementDefinitions => [
    AchievementDefinition(
      key: 'medicine_first_dose',
      moduleId: id,
      titleKey: 'achievementMedicineFirstDoseTitle',
      descriptionKey: 'achievementMedicineFirstDoseDescription',
      target: 1,
      currentProgress: () async {
        final medicines = await _repository.allMedicines();
        if (medicines.isEmpty) return 0;
        final earliest = medicines.first;
        final doses = await _repository.dosesInRange(
          localDayKey(DateTime.utc(2000)),
          localDayKey(clock.now()),
        );
        return doses.any((d) => d.storedStatus == MedicineDoseStatus.done)
            ? 1
            : (earliest == null ? 0 : 0);
      },
    ),
    AchievementDefinition(
      key: 'medicine_adherence_streak_7',
      moduleId: id,
      titleKey: 'achievementMedicineAdherenceStreak7Title',
      descriptionKey: 'achievementMedicineAdherenceStreak7Description',
      target: 7,
      currentProgress: _currentAdherenceStreak,
    ),
    AchievementDefinition(
      key: 'medicine_adherence_streak_30',
      moduleId: id,
      titleKey: 'achievementMedicineAdherenceStreak30Title',
      descriptionKey: 'achievementMedicineAdherenceStreak30Description',
      target: 30,
      currentProgress: _currentAdherenceStreak,
    ),
  ];

  Future<int> _currentAdherenceStreak() async {
    final today = localDayKey(clock.now());
    final status = await dayStatus(
      DateRange(start: today.addDays(-30), end: today),
    );
    return currentStreak(status, today);
  }
```

The `medicine_first_dose` closure above is over-complicated by trying to
avoid an extra repository call — simplify it before committing: it only
needs "has any dose ever been marked done." Replace it with:

```dart
      currentProgress: () async {
        final today = localDayKey(clock.now());
        final doses = await _repository.dosesInRange(
          const LocalDate(2000, 1, 1),
          today,
        );
        return doses.any((d) => d.storedStatus == MedicineDoseStatus.done) ? 1 : 0;
      },
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/medicine/medicine_module_test.dart`
Expected: PASS. Also run `flutter analyze` — clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/medicine/medicine_module.dart test/features/medicine/medicine_module_test.dart
git commit -m "feat(medicine): implement dayStatus/nextUpcoming/quickActions/search/achievementDefinitions"
```

---

### Task 6: Prayer module — real implementations

**Files:**
- Modify: `lib/features/prayer/prayer_module.dart`
- Test: `test/features/prayer/prayer_module_test.dart` (extend existing)

**Interfaces:**
- Consumes: contract (Task 2); `PrayerRepository.recordsInRange` (existing);
  `CalculatePrayerStreakUseCase` (existing); `todaysPrayerViewsProvider`
  (existing); `prayerControllerProvider` (existing).
- Produces: Prayer's stub 5 methods replaced with real logic.

- [ ] **Step 1: Write the failing tests**

Add to `test/features/prayer/prayer_module_test.dart` (extend that file's
fake repository with `recordsInRange` support, same pattern as Tasks 4-5):

```dart
test('dayStatus: 5 prayed records is complete, mix is partial, none is missed', () async {
  final day = const LocalDate(2026, 6, 1);
  List<PrayerRecord> recordsWith(PrayerStatus Function(int) statusFor) => [
    for (var i = 0; i < 5; i++)
      PrayerRecord(
        id: 'r$i', prayerDate: day, prayerName: PrayerName.values[i],
        scheduledFor: DateTime.utc(2026, 6, 1, 5 + i),
        storedStatus: statusFor(i), statusChangedAt: null,
      ),
  ];
  final complete = PrayerModule(_FakePrayerRepository(records: recordsWith((_) => PrayerStatus.prayed)));
  final missed = PrayerModule(_FakePrayerRepository(records: recordsWith((_) => PrayerStatus.missed)));
  final partial = PrayerModule(
    _FakePrayerRepository(records: recordsWith((i) => i == 0 ? PrayerStatus.prayed : PrayerStatus.missed)),
  );
  final range = DateRange(start: day, end: day);
  expect((await complete.dayStatus(range))[day]!.kind, ModuleDayStatusKind.complete);
  expect((await missed.dayStatus(range))[day]!.kind, ModuleDayStatusKind.missed);
  expect((await partial.dayStatus(range))[day]!.kind, ModuleDayStatusKind.partial);
});

test('search always returns empty (Prayer has no named user data)', () async {
  final module = PrayerModule(_FakePrayerRepository(records: const []));
  expect(await module.search('fajr'), isEmpty);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/prayer/prayer_module_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

In `lib/features/prayer/prayer_module.dart`, add imports:

```dart
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_streak.dart';
```

Replace the 5 stub members with:

```dart
  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    final records = await _repository.recordsInRange(range.start, range.end);
    final byDay = <LocalDate, List<PrayerRecord>>{};
    for (final record in records) {
      (byDay[record.prayerDate] ??= []).add(record);
    }
    final result = <LocalDate, ModuleDayStatus>{};
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      final dayRecords = byDay[day] ?? const [];
      if (dayRecords.length < 5 ||
          dayRecords.any((r) => r.storedStatus == PrayerStatus.upcoming)) {
        result[day] = const ModuleDayStatus(kind: ModuleDayStatusKind.none, value: 0);
        day = day.addDays(1);
        continue;
      }
      final prayedCount =
          dayRecords.where((r) => r.storedStatus == PrayerStatus.prayed).length;
      final kind = prayedCount == dayRecords.length
          ? ModuleDayStatusKind.complete
          : prayedCount == 0
              ? ModuleDayStatusKind.missed
              : ModuleDayStatusKind.partial;
      result[day] = ModuleDayStatus(kind: kind, value: prayedCount);
      day = day.addDays(1);
    }
    return result;
  }

  @override
  Widget? nextUpcoming(WidgetRef ref) {
    final views = ref.watch(todaysPrayerViewsProvider);
    if (views == null) return null;
    PrayerRecordView? next;
    for (final view in views) {
      if (view.effectiveStatus == PrayerStatus.due ||
          view.effectiveStatus == PrayerStatus.upcoming) {
        next = view;
        break;
      }
    }
    if (next == null) return null;
    final label = next!.showAsJumuah ? "Jumu'ah" : _titleCase(next.record.prayerName.name);
    return Builder(
      builder: (context) => Chip(
        avatar: const Icon(Icons.mosque, size: 16),
        label: Text(label),
      ),
    );
  }

  @override
  List<Widget> quickActions(WidgetRef ref) {
    final views = ref.watch(todaysPrayerViewsProvider);
    if (views == null) return const [];
    final due = views.where((v) => v.effectiveStatus == PrayerStatus.due);
    if (due.isEmpty) return const [];
    final recordId = due.first.record.id;
    return [
      Consumer(
        builder: (context, innerRef, _) => ActionChip(
          avatar: const Icon(Icons.check, size: 16),
          label: const Text('Mark prayed'),
          onPressed: () => innerRef
              .read(prayerControllerProvider)
              .togglePrayed(recordId, currentlyPrayed: false),
        ),
      ),
    ];
  }

  @override
  Future<List<SearchResult>> search(String query) async => const [];

  @override
  List<AchievementDefinition> get achievementDefinitions => [
    AchievementDefinition(
      key: 'prayer_first_log',
      moduleId: id,
      titleKey: 'achievementPrayerFirstLogTitle',
      descriptionKey: 'achievementPrayerFirstLogDescription',
      target: 1,
      currentProgress: () async {
        final today = localDayKey(clock.now());
        final records = await _repository.recordsInRange(
          const LocalDate(2000, 1, 1),
          today,
        );
        return records.any((r) => r.storedStatus == PrayerStatus.prayed) ? 1 : 0;
      },
    ),
    AchievementDefinition(
      key: 'prayer_streak_7',
      moduleId: id,
      titleKey: 'achievementPrayerStreak7Title',
      descriptionKey: 'achievementPrayerStreak7Description',
      target: 7,
      currentProgress: _currentPrayerStreak,
    ),
    AchievementDefinition(
      key: 'prayer_streak_30',
      moduleId: id,
      titleKey: 'achievementPrayerStreak30Title',
      descriptionKey: 'achievementPrayerStreak30Description',
      target: 30,
      currentProgress: _currentPrayerStreak,
    ),
    AchievementDefinition(
      key: 'prayer_streak_100',
      moduleId: id,
      titleKey: 'achievementPrayerStreak100Title',
      descriptionKey: 'achievementPrayerStreak100Description',
      target: 100,
      currentProgress: _currentPrayerStreak,
    ),
    AchievementDefinition(
      key: 'prayer_perfect_week',
      moduleId: id,
      titleKey: 'achievementPrayerPerfectWeekTitle',
      descriptionKey: 'achievementPrayerPerfectWeekDescription',
      target: 1,
      currentProgress: _perfectPrayerWeek,
    ),
  ];

  Future<int> _currentPrayerStreak() async {
    final today = localDayKey(clock.now());
    final records = await _repository.recordsInRange(
      today.addDays(-100),
      today,
    );
    final byDay = <LocalDate, List<PrayerRecord>>{};
    for (final record in records) {
      (byDay[record.prayerDate] ??= []).add(record);
    }
    final result = const CalculatePrayerStreakUseCase().execute(
      recordsByDay: byDay,
      earliestDay: today.addDays(-100),
      today: today,
    );
    return result.current;
  }

  Future<int> _perfectPrayerWeek() async {
    final today = localDayKey(clock.now());
    final status = await dayStatus(
      DateRange(start: today.addDays(-6), end: today),
    );
    final allComplete = status.values.every(
      (s) => s.kind == ModuleDayStatusKind.complete,
    );
    return allComplete ? 1 : 0;
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/prayer/prayer_module_test.dart`
Expected: PASS. Also run `flutter analyze` — clean (fixes the
`achievementDefinitions` unused-import warnings if any).

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer/prayer_module.dart test/features/prayer/prayer_module_test.dart
git commit -m "feat(prayer): implement dayStatus/nextUpcoming/quickActions/search/achievementDefinitions"
```

---

### Task 7: `core/achievements/achievement_repository.dart`

**Files:**
- Create: `lib/core/achievements/achievement_repository.dart`
- Test: `test/core/achievements/achievement_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`/`AchievementsTable` (existing, Task 2 doc fix
  only), `generateId()` (existing).
- Produces: `class AchievementRepository`, methods
  `Future<AchievementRow?> byKey(String key)`,
  `Future<void> upsertProgress({required String moduleId, required String
  key, required int current, required int target, required DateTime now})`,
  `Stream<List<AchievementRow>> watchByModule(String moduleId)`,
  `Stream<List<AchievementRow>> watchAll()`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late AchievementRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = AchievementRepository(db);
  });

  tearDown(() => db.close());

  test('upsertProgress creates a row when none exists', () async {
    await repo.upsertProgress(
      moduleId: 'water',
      key: 'water_first_log',
      current: 1,
      target: 1,
      now: DateTime.utc(2026, 6, 1),
    );
    final row = await repo.byKey('water_first_log');
    expect(row, isNotNull);
    expect(row!.progressCurrent, 1);
    expect(row.unlockedAt, DateTime.utc(2026, 6, 1).millisecondsSinceEpoch);
  });

  test('upsertProgress updates an existing row without re-locking it', () async {
    await repo.upsertProgress(
      moduleId: 'water', key: 'water_streak_7', current: 7, target: 7,
      now: DateTime.utc(2026, 6, 1),
    );
    final firstUnlock = (await repo.byKey('water_streak_7'))!.unlockedAt;

    await repo.upsertProgress(
      moduleId: 'water', key: 'water_streak_7', current: 0, target: 7,
      now: DateTime.utc(2026, 6, 2),
    );
    final row = await repo.byKey('water_streak_7');
    expect(row!.progressCurrent, 0);
    expect(row.unlockedAt, firstUnlock);
  });

  test('byKey returns null for an unknown key', () async {
    expect(await repo.byKey('nope'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/achievements/achievement_repository_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement**

```dart
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/utils/uuid.dart';

/// Drift-backed CRUD over the `achievements` table
/// (`core/achievements/achievement_engine.dart`'s only data dependency).
class AchievementRepository {
  /// Creates a repository backed by [_db].
  AchievementRepository(this._db);

  final AppDatabase _db;

  /// Looks up a single achievement row by its stable [key], or `null` if
  /// it has never been evaluated.
  Future<AchievementRow?> byKey(String key) {
    return (_db.select(_db.achievementsTable)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
  }

  /// Every achievement row for [moduleId], live-updating.
  Stream<List<AchievementRow>> watchByModule(String moduleId) {
    return (_db.select(_db.achievementsTable)
          ..where((t) => t.moduleId.equals(moduleId)))
        .watch();
  }

  /// Every achievement row across every module, live-updating — the
  /// badge gallery's source.
  Stream<List<AchievementRow>> watchAll() => _db.select(_db.achievementsTable).watch();

  /// Creates or updates [key]'s progress row. Once `unlockedAt` is set it
  /// is never cleared or overwritten by a later, lower [current] — an
  /// achievement stays unlocked.
  Future<void> upsertProgress({
    required String moduleId,
    required String key,
    required int current,
    required int target,
    required DateTime now,
  }) async {
    final nowMillis = now.millisecondsSinceEpoch;
    final existing = await byKey(key);
    if (existing == null) {
      await _db.into(_db.achievementsTable).insert(
        AchievementsTableCompanion.insert(
          id: generateId(),
          moduleId: moduleId,
          key: key,
          progressCurrent: current,
          progressTarget: target,
          unlockedAt: Value(current >= target ? nowMillis : null),
          createdAt: nowMillis,
          updatedAt: nowMillis,
        ),
      );
      return;
    }
    final justUnlocked = existing.unlockedAt == null && current >= target;
    await (_db.update(_db.achievementsTable)
          ..where((t) => t.id.equals(existing.id)))
        .write(
      AchievementsTableCompanion(
        progressCurrent: Value(current),
        progressTarget: Value(target),
        unlockedAt: Value(justUnlocked ? nowMillis : existing.unlockedAt),
        updatedAt: Value(nowMillis),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/achievements/achievement_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/achievements/achievement_repository.dart test/core/achievements/achievement_repository_test.dart
git commit -m "feat(achievements): add AchievementRepository"
```

---

### Task 8: `core/achievements/achievement_engine.dart` + providers

**Files:**
- Create: `lib/core/achievements/achievement_engine.dart`
- Create: `lib/core/achievements/achievement_providers.dart`
- Test: `test/core/achievements/achievement_engine_test.dart`

**Interfaces:**
- Consumes: `AchievementRepository` (Task 7), `HabitModule`/
  `AchievementDefinition` (Task 2), `habitModulesProvider`/
  `databaseProvider` (existing).
- Produces: `class AchievementEngine { Future<void> evaluate(String
  moduleId); }`, `@Riverpod(keepAlive: true) AchievementEngine
  achievementEngine(Ref ref)`, `@Riverpod(keepAlive: true)
  AchievementRepository achievementRepository(Ref ref)` — Task 9's
  controller wiring and Task 14's gallery screen both depend on these
  provider names.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_engine.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this._definitions);
  final List<AchievementDefinition> _definitions;

  @override
  String get id => 'fake';

  @override
  List<AchievementDefinition> get achievementDefinitions => _definitions;
}

void main() {
  late AppDatabase db;
  late AchievementRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = AchievementRepository(db);
  });

  tearDown(() => db.close());

  test('evaluate persists progress for every definition the module contributes', () async {
    final module = _FakeModule([
      AchievementDefinition(
        key: 'fake_one', moduleId: 'fake', titleKey: 't', descriptionKey: 'd',
        target: 3, currentProgress: () async => 2,
      ),
    ]);
    final engine = AchievementEngine(repository: repo, modules: [module]);

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1)), () async {
      await engine.evaluate('fake');
    });

    final row = await repo.byKey('fake_one');
    expect(row, isNotNull);
    expect(row!.progressCurrent, 2);
    expect(row.progressTarget, 3);
    expect(row.unlockedAt, isNull);
  });

  test('evaluate sets unlockedAt exactly once when progress reaches target', () async {
    final module = _FakeModule([
      AchievementDefinition(
        key: 'fake_two', moduleId: 'fake', titleKey: 't', descriptionKey: 'd',
        target: 1, currentProgress: () async => 1,
      ),
    ]);
    final engine = AchievementEngine(repository: repo, modules: [module]);

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1)), () async {
      await engine.evaluate('fake');
    });
    final firstUnlock = (await repo.byKey('fake_two'))!.unlockedAt;
    expect(firstUnlock, isNotNull);

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 2)), () async {
      await engine.evaluate('fake');
    });
    expect((await repo.byKey('fake_two'))!.unlockedAt, firstUnlock);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/achievements/achievement_engine_test.dart`
Expected: FAIL — `achievement_engine.dart` doesn't exist.

- [ ] **Step 3: Implement**

`lib/core/achievements/achievement_engine.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

/// Evaluates one module's [HabitModule.achievementDefinitions] against
/// live data and persists progress/unlock state (D-16). Called by each
/// module's own controller right after a write commits — never on a
/// timer, never scanning every module at once.
class AchievementEngine {
  /// Creates an engine over [modules], persisting through [repository].
  const AchievementEngine({required this.repository, required this.modules});

  /// Where progress/unlock state is stored.
  final AchievementRepository repository;

  /// Every registered module — [evaluate] looks up the one matching
  /// [moduleId] and reads its `achievementDefinitions`.
  final List<HabitModule> modules;

  /// Re-evaluates every achievement [moduleId] contributes.
  Future<void> evaluate(String moduleId) async {
    final module = modules.firstWhere((m) => m.id == moduleId);
    final now = clock.now();
    for (final definition in module.achievementDefinitions) {
      final progress = await definition.currentProgress();
      await repository.upsertProgress(
        moduleId: moduleId,
        key: definition.key,
        current: progress.clamp(0, definition.target),
        target: definition.target,
        now: now,
      );
    }
  }
}
```

`lib/core/achievements/achievement_providers.dart`:

```dart
import 'package:habit_tracker/core/achievements/achievement_engine.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'achievement_providers.g.dart';

/// The shared [AchievementRepository].
@Riverpod(keepAlive: true)
AchievementRepository achievementRepository(Ref ref) {
  return AchievementRepository(ref.watch(databaseProvider));
}

/// The shared [AchievementEngine], rebuilt if the module list changes.
@Riverpod(keepAlive: true)
AchievementEngine achievementEngine(Ref ref) {
  return AchievementEngine(
    repository: ref.watch(achievementRepositoryProvider),
    modules: ref.watch(habitModulesProvider),
  );
}
```

- [ ] **Step 4: Run build_runner, then run tests to verify they pass**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/core/achievements/achievement_engine_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/achievements/achievement_engine.dart lib/core/achievements/achievement_providers.dart \
  lib/core/achievements/achievement_providers.g.dart test/core/achievements/achievement_engine_test.dart
git commit -m "feat(achievements): add AchievementEngine + providers"
```

---

### Task 9: Wire achievement evaluation into each module's write path

**Files:**
- Modify: `lib/features/water/presentation/providers/water_controller.dart`
- Modify: `lib/features/medicine/presentation/providers/medicine_controller.dart`
- Modify: `lib/features/prayer/presentation/providers/prayer_controller.dart`
- Test: `test/features/water/presentation/water_controller_test.dart` (new),
  or extend an existing controller test if one already covers `_log` —
  check first with `find test/features/water -iname "*controller*"`.

**Interfaces:**
- Consumes: `achievementEngineProvider` (Task 8).
- Produces: no new public API — each controller now also triggers
  achievement evaluation as a side effect of its existing write methods.

- [ ] **Step 1: Write the failing test**

Create `test/features/water/presentation/water_controller_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';

void main() {
  test('logQuickAdd triggers achievement evaluation for water', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    await container.read(waterControllerProvider).logQuickAdd(250);

    final row = await container
        .read(achievementRepositoryProvider)
        .byKey('water_first_log');
    expect(row, isNotNull);
    expect(row!.progressCurrent, 1);
    expect(row.unlockedAt, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/water/presentation/water_controller_test.dart`
Expected: FAIL — no achievement row is written yet.

- [ ] **Step 3: Wire the evaluate call into each controller**

In `lib/features/water/presentation/providers/water_controller.dart`, add
the import `import 'package:habit_tracker/core/achievements/achievement_providers.dart';`
and change `_log`:

```dart
  Future<void> _log({
    required int amountMl,
    required WaterEntrySource source,
    DateTime? loggedAt,
  }) async {
    final repository = ref.read(waterRepositoryProvider);
    final result = await LogWaterEntryUseCase(
      repository,
    ).execute(amountMl: amountMl, source: source, loggedAt: loggedAt);
    if (result case Failure(:final error)) {
      logException(error);
      return;
    }
    await ref.read(achievementEngineProvider).evaluate('water');
  }
```

In `lib/features/medicine/presentation/providers/medicine_controller.dart`,
add the same import and change `markDoseDone`:

```dart
  Future<void> markDoseDone(
    String doseId, {
    bool fromOtherSource = false,
  }) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .markDoseDone(doseId, fromOtherSource: fromOtherSource);
    if (result case Failure(:final error)) {
      logException(error);
      return;
    }
    await ref.read(achievementEngineProvider).evaluate('medicine');
  }
```

In `lib/features/prayer/presentation/providers/prayer_controller.dart`,
add the same import and change `togglePrayed`:

```dart
  Future<void> togglePrayed(
    String recordId, {
    required bool currentlyPrayed,
  }) async {
    final repository = ref.read(prayerRepositoryProvider);
    final result = currentlyPrayed
        ? await repository.unmarkPrayed(recordId)
        : await repository.markPrayed(recordId);
    if (result case Failure(:final error)) {
      logException(error);
      return;
    }
    await ref.read(achievementEngineProvider).evaluate('prayer');
  }
```

- [ ] **Step 4: Run test to verify it passes, then run the full suite**

Run: `flutter test test/features/water/presentation/water_controller_test.dart`
Expected: PASS.
Run: `flutter test`
Expected: all PASS (no regressions in existing controller-adjacent tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/water/presentation/providers/water_controller.dart \
  lib/features/medicine/presentation/providers/medicine_controller.dart \
  lib/features/prayer/presentation/providers/prayer_controller.dart \
  test/features/water/presentation/water_controller_test.dart
git commit -m "feat(achievements): evaluate progress after each module's write"
```

---

### Task 10: `core/reports/aggregate_report_usecase.dart`

**Files:**
- Create: `lib/core/reports/aggregate_report_usecase.dart`
- Test: `test/core/reports/aggregate_report_usecase_test.dart`

**Interfaces:**
- Consumes: `HabitModule`/`ModuleDayStatus(Kind)` (Task 2), `DateRange`
  (Task 1), `longestStreak` (Task 3), `BarChartPoint` (existing,
  `core/widgets/charts/period_bar_chart.dart`).
- Produces: `enum ReportPeriod { week, month, year }`,
  `typedef ModuleReport = ({String moduleId, String displayName, Color
  accentColor, List<BarChartPoint> points, int longestStreak})`,
  `class AggregateReportUseCase { Future<List<ModuleReport>> execute({
  required List<HabitModule> modules, required ReportPeriod period,
  required LocalDate periodAnchor}); }` — Task 13's `ReportsScreen` and
  its providers depend on this exact shape.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart' show AchievementRepository; // unused import guard removed below
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:mocktail/mocktail.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id, this._byDay);
  @override
  final String id;
  final Map<LocalDate, ModuleDayStatus> _byDay;

  @override
  ModuleMetadata get metadata => ModuleMetadata(
    displayName: id, icon: Icons.circle, accentColor: Colors.blue,
  );

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async => _byDay;
}

void main() {
  test('a module with only "none" days is excluded (empty-state case)', () async {
    final module = _FakeModule('water', {
      const LocalDate(2026, 6, 1): const ModuleDayStatus(kind: ModuleDayStatusKind.none, value: 0),
    });
    final reports = await const AggregateReportUseCase().execute(
      modules: [module], period: ReportPeriod.week, periodAnchor: const LocalDate(2026, 6, 1),
    );
    expect(reports, isEmpty);
  });

  test('week period buckets one bar per day and computes the longest streak', () async {
    final module = _FakeModule('water', {
      for (var d = 1; d <= 7; d++)
        LocalDate(2026, 6, d): ModuleDayStatus(
          kind: d <= 3 ? ModuleDayStatusKind.complete : ModuleDayStatusKind.missed,
          value: d * 100,
        ),
    });
    final reports = await const AggregateReportUseCase().execute(
      modules: [module], period: ReportPeriod.week, periodAnchor: const LocalDate(2026, 6, 3),
    );
    expect(reports, hasLength(1));
    expect(reports.first.longestStreak, 3);
    expect(reports.first.points, isNotEmpty);
  });

  test('year period buckets one bar per month', () async {
    final module = _FakeModule('water', {
      const LocalDate(2026, 1, 15): const ModuleDayStatus(kind: ModuleDayStatusKind.complete, value: 500),
      const LocalDate(2026, 2, 15): const ModuleDayStatus(kind: ModuleDayStatusKind.complete, value: 700),
    });
    final reports = await const AggregateReportUseCase().execute(
      modules: [module], period: ReportPeriod.year, periodAnchor: const LocalDate(2026, 3, 1),
    );
    expect(reports.first.points, hasLength(12));
  });
}
```

Drop the unused `AchievementRepository` import above before running —
it was left in by mistake; the test file needs only the imports actually
referenced (`flutter/material.dart`, `flutter_test`, `habit_module.dart`,
`aggregate_report_usecase.dart`, `local_date.dart`, `mocktail`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/reports/aggregate_report_usecase_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/reports/day_status_streaks.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';

/// The Reports screen's period granularity (FR-C-12).
enum ReportPeriod {
  /// One bar per day, 7 days.
  week,

  /// One bar per day, the whole calendar month.
  month,

  /// One bar per calendar month, 12 months.
  year,
}

/// One module's contribution to a Reports period — its chart series plus
/// its longest-streak record (FR-C-14).
typedef ModuleReport = ({
  String moduleId,
  String displayName,
  Color accentColor,
  List<BarChartPoint> points,
  int longestStreak,
});

/// Builds each enabled module's [ModuleReport] for [period], anchored at
/// [periodAnchor] (any day within the target period). A module with no
/// data anywhere in the period is omitted — the caller renders that as
/// an empty state, not a zero-filled chart (FR-C-12).
class AggregateReportUseCase {
  /// Creates the use case.
  const AggregateReportUseCase();

  /// Computes every [modules] entry's report for [period].
  Future<List<ModuleReport>> execute({
    required List<HabitModule> modules,
    required ReportPeriod period,
    required LocalDate periodAnchor,
  }) async {
    final range = _rangeForPeriod(period, periodAnchor);
    final reports = <ModuleReport>[];
    for (final module in modules) {
      final dayStatus = await module.dayStatus(range);
      final hasData = dayStatus.values.any(
        (s) => s.kind != ModuleDayStatusKind.none,
      );
      if (!hasData) continue;
      reports.add((
        moduleId: module.id,
        displayName: module.metadata.displayName,
        accentColor: module.metadata.accentColor,
        points: _bucketPoints(dayStatus, period, range),
        longestStreak: longestStreak(dayStatus),
      ));
    }
    return reports;
  }

  DateRange _rangeForPeriod(ReportPeriod period, LocalDate anchor) {
    switch (period) {
      case ReportPeriod.week:
        final weekday = anchor.toDateTimeUtc().weekday;
        final start = anchor.addDays(-(weekday - 1));
        return DateRange(start: start, end: start.addDays(6));
      case ReportPeriod.month:
        final start = LocalDate(anchor.year, anchor.month, 1);
        final end = LocalDate(anchor.year, anchor.month + 1, 1).addDays(-1);
        return DateRange(start: start, end: end);
      case ReportPeriod.year:
        return DateRange(
          start: LocalDate(anchor.year, 1, 1),
          end: LocalDate(anchor.year, 12, 31),
        );
    }
  }

  static const _monthLabels = [
    'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
  ];

  List<BarChartPoint> _bucketPoints(
    Map<LocalDate, ModuleDayStatus> dayStatus,
    ReportPeriod period,
    DateRange range,
  ) {
    if (period != ReportPeriod.year) {
      final points = <BarChartPoint>[];
      var day = range.start;
      while (day.compareTo(range.end) <= 0) {
        final value = dayStatus[day]?.value ?? 0;
        points.add(BarChartPoint(label: '${day.day}', value: value.toDouble()));
        day = day.addDays(1);
      }
      return points;
    }
    final totalsByMonth = List<double>.filled(12, 0);
    dayStatus.forEach((day, status) {
      totalsByMonth[day.month - 1] += status.value.toDouble();
    });
    return [
      for (var i = 0; i < 12; i++)
        BarChartPoint(label: _monthLabels[i], value: totalsByMonth[i]),
    ];
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/reports/aggregate_report_usecase_test.dart`
Expected: PASS. Run `flutter analyze` — clean.

- [ ] **Step 5: Commit**

```bash
git add lib/core/reports/aggregate_report_usecase.dart test/core/reports/aggregate_report_usecase_test.dart
git commit -m "feat(reports): add AggregateReportUseCase"
```

---

### Task 11: Dashboard rewrite — day-completion indicator, upcoming strip, quick actions

**Files:**
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- Test: `test/features/dashboard/dashboard_screen_test.dart` (new — this is
  the DoD's decoupling proof)

**Interfaces:**
- Consumes: `habitModulesProvider` (existing), `HabitModule.dayStatus`/
  `nextUpcoming`/`quickActions`/`dashboardSummary` (Task 2/4-6),
  `DateRange` (Task 1).
- Produces: rewritten `DashboardScreen` — no new public API (screens don't
  export types other files import).

- [ ] **Step 1: Write the failing test (the decoupling proof)**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:mocktail/mocktail.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id);
  @override
  final String id;

  @override
  ModuleMetadata get metadata => ModuleMetadata(
    displayName: id, icon: Icons.circle, accentColor: Colors.blue,
  );

  @override
  Widget dashboardSummary(WidgetRef ref) => Card(child: Text('$id summary'));

  @override
  Widget? nextUpcoming(WidgetRef ref) => null;

  @override
  List<Widget> quickActions(WidgetRef ref) => const [];

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async => {};
}

Future<void> _pump(WidgetTester tester, List<HabitModule> modules) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [habitModulesProvider.overrideWith((ref) => modules)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('0 modules: shows the empty state, no summary cards', (tester) async {
    await _pump(tester, []);
    expect(find.textContaining('summary'), findsNothing);
  });

  testWidgets('1 module: shows exactly that module\'s summary card', (tester) async {
    await _pump(tester, [_FakeModule('water')]);
    expect(find.text('water summary'), findsOneWidget);
  });

  testWidgets('3 modules: shows all three summary cards', (tester) async {
    await _pump(tester, [_FakeModule('water'), _FakeModule('medicine'), _FakeModule('prayer')]);
    expect(find.text('water summary'), findsOneWidget);
    expect(find.text('medicine summary'), findsOneWidget);
    expect(find.text('prayer summary'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dashboard/dashboard_screen_test.dart`
Expected: FAIL — `DashboardScreen` doesn't yet iterate
`habitModulesProvider` (it currently only shows the empty state).

- [ ] **Step 3: Rewrite the screen**

Replace the whole contents of
`lib/features/dashboard/presentation/screens/dashboard_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/dashboard/presentation/search/app_search_delegate.dart';

/// The dashboard tab. Shows an empty state until a module is enabled;
/// otherwise every enabled module's summary card, a day-completion
/// indicator, an upcoming-items strip, and a quick-actions row (FR-C-11).
class DashboardScreen extends ConsumerWidget {
  /// Creates the dashboard screen.
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final modules = ref.watch(habitModulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navDashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: modules.isEmpty
                ? null
                : () => showSearch(context: context, delegate: AppSearchDelegate(modules)),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push('/achievements'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push('/reports'),
          ),
        ],
      ),
      body: modules.isEmpty
          ? Center(child: Text(l10n.emptyDashboardMessage))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _DayCompletionIndicator(modules: modules),
                const SizedBox(height: 16),
                _UpcomingStrip(modules: modules),
                const SizedBox(height: 16),
                _QuickActionsRow(modules: modules),
                const SizedBox(height: 16),
                for (final module in modules) module.dashboardSummary(ref),
              ],
            ),
    );
  }
}

class _DayCompletionIndicator extends ConsumerWidget {
  const _DayCompletionIndicator({required this.modules});
  final List<HabitModule> modules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<int>>(
      future: Future.wait(
        modules.map((m) async {
          final today = localDayKey(DateTime.now());
          final status = await m.dayStatus(DateRange(start: today, end: today));
          return status[today]?.kind == ModuleDayStatusKind.complete ? 1 : 0;
        }),
      ),
      builder: (context, snapshot) {
        final completed = snapshot.data?.fold<int>(0, (a, b) => a + b) ?? 0;
        return LinearProgressIndicator(
          value: modules.isEmpty ? 0 : completed / modules.length,
          minHeight: 8,
        );
      },
    );
  }
}

class _UpcomingStrip extends StatelessWidget {
  const _UpcomingStrip({required this.modules});
  final List<HabitModule> modules;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final chips = [
          for (final module in modules)
            if (module.nextUpcoming(ref) case final chip?) chip,
        ];
        if (chips.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => chips[index],
          ),
        );
      },
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.modules});
  final List<HabitModule> modules;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final actions = [
          for (final module in modules) ...module.quickActions(ref),
        ];
        if (actions.isEmpty) return const SizedBox.shrink();
        return Wrap(spacing: 8, runSpacing: 8, children: actions);
      },
    );
  }
}
```

Note: `_UpcomingStrip`/`_QuickActionsRow` call `module.nextUpcoming(ref)`/
`module.quickActions(ref)` from inside a `Consumer`'s own `ref` — every
module implementation from Tasks 4-6 internally calls `ref.watch(...)`,
which is valid because it's the same `ref` the `Consumer` supplies.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dashboard/dashboard_screen_test.dart`
Expected: PASS.
Run: `flutter test && flutter analyze`
Expected: everything green (this rewrite must not break Water/Medicine/
Prayer's own existing tests, none of which touch `DashboardScreen`).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/presentation/screens/dashboard_screen.dart \
  test/features/dashboard/dashboard_screen_test.dart
git commit -m "feat(dashboard): add day-completion indicator, upcoming strip, quick actions"
```

*(This task references `app_search_delegate.dart`, built in Task 15 —
implement Task 15's file before running Task 11's app on a device/
simulator; the widget test above doesn't exercise the search icon, so
Task 11's own test suite passes without it existing yet, but `flutter
analyze` on the whole project won't be clean until Task 15 lands. Do
Tasks 12-15 next, in order, before the final Task 18 verification.)*

---

### Task 12: Global month calendar

**Files:**
- Create: `lib/core/widgets/global_month_calendar.dart`
- Test: `test/core/widgets/global_month_calendar_test.dart`
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
  (wire in an entry point)

**Interfaces:**
- Consumes: `ModuleDayStatus(Kind)` (Task 2), `LocalDate`.
- Produces: `ModuleDayStatusKind combinedDayStatusKind(List<
  ModuleDayStatusKind> kinds)` (pure, testable alone),
  `class GlobalMonthCalendar extends StatelessWidget { const
  GlobalMonthCalendar({required LocalDate month, required
  Map<String, Map<LocalDate, ModuleDayStatus>> statusesByModule, required
  void Function(LocalDate day) onDayTap}); }`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/global_month_calendar.dart';

void main() {
  group('combinedDayStatusKind', () {
    test('all complete -> complete', () {
      expect(
        combinedDayStatusKind([ModuleDayStatusKind.complete, ModuleDayStatusKind.complete]),
        ModuleDayStatusKind.complete,
      );
    });
    test('mixed complete/missed -> partial', () {
      expect(
        combinedDayStatusKind([ModuleDayStatusKind.complete, ModuleDayStatusKind.missed]),
        ModuleDayStatusKind.partial,
      );
    });
    test('all missed -> missed', () {
      expect(combinedDayStatusKind([ModuleDayStatusKind.missed]), ModuleDayStatusKind.missed);
    });
    test('empty or all none -> none', () {
      expect(combinedDayStatusKind([]), ModuleDayStatusKind.none);
      expect(combinedDayStatusKind([ModuleDayStatusKind.none]), ModuleDayStatusKind.none);
    });
  });

  testWidgets('renders a cell per day of the month and calls onDayTap', (tester) async {
    LocalDate? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalMonthCalendar(
          month: const LocalDate(2026, 6, 1),
          statusesByModule: {
            'water': {
              const LocalDate(2026, 6, 1): const ModuleDayStatus(kind: ModuleDayStatusKind.complete, value: 1),
            },
          },
          onDayTap: (day) => tapped = day,
        ),
      ),
    );
    await tester.tap(find.text('1').first);
    expect(tapped, const LocalDate(2026, 6, 1));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/widgets/global_month_calendar_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// Combines every module's [ModuleDayStatusKind] for one day into a
/// single coloring decision for [GlobalMonthCalendar] (FR-C-16). `none`
/// entries are ignored unless every entry is `none`.
ModuleDayStatusKind combinedDayStatusKind(List<ModuleDayStatusKind> kinds) {
  final resolved = kinds.where((k) => k != ModuleDayStatusKind.none).toList();
  if (resolved.isEmpty) return ModuleDayStatusKind.none;
  if (resolved.every((k) => k == ModuleDayStatusKind.complete)) {
    return ModuleDayStatusKind.complete;
  }
  if (resolved.every((k) => k == ModuleDayStatusKind.missed)) {
    return ModuleDayStatusKind.missed;
  }
  return ModuleDayStatusKind.partial;
}

/// A month grid coloring each day by every enabled module's combined
/// status (FR-C-16). [statusesByModule] maps a module id to that
/// module's `dayStatus()` result covering (at least) [month].
class GlobalMonthCalendar extends StatelessWidget {
  /// Creates a month calendar for [month] (any day within the target
  /// month), colored from [statusesByModule], calling [onDayTap] when a
  /// day cell is tapped.
  const GlobalMonthCalendar({
    required this.month,
    required this.statusesByModule,
    required this.onDayTap,
    super.key,
  });

  /// Any day within the month to render.
  final LocalDate month;

  /// Module id -> that module's day-status map.
  final Map<String, Map<LocalDate, ModuleDayStatus>> statusesByModule;

  /// Called with the tapped day.
  final void Function(LocalDate day) onDayTap;

  int _daysInMonth() =>
      LocalDate(month.year, month.month + 1, 1).addDays(-1).day;

  Color _colorFor(BuildContext context, ModuleDayStatusKind kind) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    switch (kind) {
      case ModuleDayStatusKind.complete:
        return semantic.success;
      case ModuleDayStatusKind.partial:
        return colors.tertiary;
      case ModuleDayStatusKind.missed:
        return colors.error;
      case ModuleDayStatusKind.none:
        return colors.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayCount = _daysInMonth();
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemCount: dayCount,
      itemBuilder: (context, index) {
        final day = LocalDate(month.year, month.month, index + 1);
        final kinds = [
          for (final statuses in statusesByModule.values)
            statuses[day]?.kind ?? ModuleDayStatusKind.none,
        ];
        final combined = combinedDayStatusKind(kinds);
        return InkWell(
          onTap: () => onDayTap(day),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _colorFor(context, combined),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text('${day.day}'),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/widgets/global_month_calendar_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire an entry point + commit**

The dashboard already pushes `/achievements` and `/reports` (Task 11).
Add a third icon for the calendar in
`lib/features/dashboard/presentation/screens/dashboard_screen.dart`'s
`AppBar.actions`, opening a bottom sheet (no dedicated route needed — it's
a drill-down surface, not a persisted-history screen, per the design
doc):

```dart
          IconButton(
            icon: const Icon(Icons.calendar_view_month),
            onPressed: modules.isEmpty
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => _GlobalCalendarSheet(modules: modules),
                  ),
          ),
```

Add `_GlobalCalendarSheet` to the same file:

```dart
class _GlobalCalendarSheet extends StatefulWidget {
  const _GlobalCalendarSheet({required this.modules});
  final List<HabitModule> modules;

  @override
  State<_GlobalCalendarSheet> createState() => _GlobalCalendarSheetState();
}

class _GlobalCalendarSheetState extends State<_GlobalCalendarSheet> {
  late LocalDate _month = localDayKey(DateTime.now());
  Map<String, Map<LocalDate, ModuleDayStatus>>? _statuses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final start = LocalDate(_month.year, _month.month, 1);
    final end = LocalDate(_month.year, _month.month + 1, 1).addDays(-1);
    final entries = await Future.wait(
      widget.modules.map((m) async => MapEntry(m.id, await m.dayStatus(DateRange(start: start, end: end)))),
    );
    setState(() => _statuses = Map.fromEntries(entries));
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _statuses;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: statuses == null
            ? const Center(child: CircularProgressIndicator())
            : GlobalMonthCalendar(
                month: _month,
                statusesByModule: statuses,
                onDayTap: (day) => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(day.toIso()),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final module in widget.modules)
                          Text('${module.metadata.displayName}: '
                              '${statuses[module.id]?[day]?.kind.name ?? 'none'}'),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
```

Add the import `import 'package:habit_tracker/core/widgets/global_month_calendar.dart';`
to `dashboard_screen.dart`.

```bash
git add lib/core/widgets/global_month_calendar.dart \
  test/core/widgets/global_month_calendar_test.dart \
  lib/features/dashboard/presentation/screens/dashboard_screen.dart
git commit -m "feat(dashboard): add global month calendar with per-day drill-down"
```

---

### Task 13: Reports feature

**Files:**
- Create: `lib/features/reports/presentation/providers/reports_providers.dart`
- Create: `lib/features/reports/presentation/screens/reports_screen.dart`
- Modify: `lib/core/router/app_router.dart` (add `/reports` route)
- Test: `test/features/reports/presentation/reports_screen_test.dart`

**Interfaces:**
- Consumes: `AggregateReportUseCase`/`ReportPeriod`/`ModuleReport` (Task
  10), `habitModulesProvider` (existing), `PeriodBarChart` (existing).
- Produces: `AppRoutes.reports = '/reports'`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/reports/presentation/screens/reports_screen.dart';
import 'package:mocktail/mocktail.dart';

class _EmptyModule extends Fake implements HabitModule {
  @override
  String get id => 'water';
  @override
  ModuleMetadata get metadata =>
      const ModuleMetadata(displayName: 'Water', icon: Icons.water_drop, accentColor: Colors.blue);
  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async => {};
}

void main() {
  testWidgets('shows an empty state when no module has data for the period', (tester) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 15)), () async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [habitModulesProvider.overrideWith((ref) => [_EmptyModule()])],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ReportsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No data'), findsWidgets);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reports/presentation/reports_screen_test.dart`
Expected: FAIL — `reports_screen.dart` doesn't exist.

- [ ] **Step 3: Implement**

`lib/features/reports/presentation/providers/reports_providers.dart`:

```dart
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reports_providers.g.dart';

/// The requested period + anchor day, used as a family provider parameter.
typedef ReportRequest = ({ReportPeriod period, LocalDate anchor});

/// Every enabled module's [ModuleReport] for [request].
@riverpod
Future<List<ModuleReport>> moduleReports(Ref ref, ReportRequest request) {
  final modules = ref.watch(habitModulesProvider);
  return const AggregateReportUseCase().execute(
    modules: modules,
    period: request.period,
    periodAnchor: request.anchor,
  );
}
```

`lib/features/reports/presentation/screens/reports_screen.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/reports/presentation/providers/reports_providers.dart';

/// Weekly/monthly/yearly cross-module reports (FR-C-12/14).
class ReportsScreen extends ConsumerStatefulWidget {
  /// Creates the reports screen.
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.week;
  late var _anchor = localDayKey(clock.now());

  void _shiftPeriod(int direction) {
    setState(() {
      _anchor = switch (_period) {
        ReportPeriod.week => _anchor.addDays(7 * direction),
        ReportPeriod.month => LocalDate(_anchor.year, _anchor.month + direction, 1),
        ReportPeriod.year => LocalDate(_anchor.year + direction, _anchor.month, 1),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reportsAsync = ref.watch(
      moduleReportsProvider((period: _period, anchor: _anchor)),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsTitle),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shiftPeriod(-1)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shiftPeriod(1)),
        ],
      ),
      body: Column(
        children: [
          SegmentedButton<ReportPeriod>(
            segments: [
              ButtonSegment(value: ReportPeriod.week, label: Text(l10n.reportsPeriodWeek)),
              ButtonSegment(value: ReportPeriod.month, label: Text(l10n.reportsPeriodMonth)),
              ButtonSegment(value: ReportPeriod.year, label: Text(l10n.reportsPeriodYear)),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          Expanded(
            child: reportsAsync.when(
              data: (reports) => reports.isEmpty
                  ? Center(child: Text(l10n.reportsEmptyState))
                  : ListView(
                      children: [
                        for (final report in reports)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(report.displayName, style: Theme.of(context).textTheme.titleMedium),
                                  Text(l10n.reportsLongestStreak(report.longestStreak)),
                                  PeriodBarChart(points: report.points, color: report.accentColor),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
              error: (error, stack) => Center(child: Text('$error')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}
```

Add to `lib/core/router/app_router.dart`: `AppRoutes.reports = '/reports'`
constant, and inside the dashboard `StatefulShellBranch`'s `GoRoute`
(path `AppRoutes.dashboard`), add to its `routes:` list (create the list
if it doesn't have one yet):

```dart
                routes: [
                  GoRoute(
                    path: 'reports',
                    builder: (context, state) => const ReportsScreen(),
                  ),
                ],
```

with the import `import 'package:habit_tracker/features/reports/presentation/screens/reports_screen.dart';`.

- [ ] **Step 4: Run build_runner, then run the test to verify it passes**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/reports/presentation/reports_screen_test.dart`
Expected: PASS (once `reportsTitle`/`reportsPeriodWeek`/`reportsPeriodMonth`/
`reportsPeriodYear`/`reportsEmptyState`/`reportsLongestStreak` exist in
`AppLocalizations` — added in Task 16; if this task runs before Task 16,
temporarily hardcode English strings to keep this task's test green, then
replace with `l10n.*` calls as part of Task 16's edits).

- [ ] **Step 5: Commit**

```bash
git add lib/features/reports lib/core/router/app_router.dart \
  test/features/reports/presentation/reports_screen_test.dart
git commit -m "feat(reports): add ReportsScreen with week/month/year period navigation"
```

---

### Task 14: Achievements feature

**Files:**
- Create: `lib/features/achievements/presentation/providers/achievement_providers.dart`
- Create: `lib/features/achievements/presentation/screens/achievement_gallery_screen.dart`
- Modify: `lib/core/router/app_router.dart` (add `/achievements` route)
- Test: `test/features/achievements/presentation/achievement_gallery_screen_test.dart`

**Interfaces:**
- Consumes: `achievementRepositoryProvider` (Task 8),
  `habitModulesProvider` (existing), `HabitModule.achievementDefinitions`
  (Task 2/4-6).
- Produces: `AppRoutes.achievements = '/achievements'`; a
  `String localizedAchievementText(AppLocalizations l10n, String key)`
  helper mapping every achievement key (Tasks 4-6) to its l10n string —
  Task 16 must keep this switch exhaustive as new keys are added.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/features/achievements/presentation/screens/achievement_gallery_screen.dart';
import 'package:mocktail/mocktail.dart';

class _OneAchievementModule extends Fake implements HabitModule {
  @override
  String get id => 'water';
  @override
  ModuleMetadata get metadata =>
      const ModuleMetadata(displayName: 'Water', icon: Icons.water_drop, accentColor: Colors.blue);
  @override
  List<AchievementDefinition> get achievementDefinitions => [
    AchievementDefinition(
      key: 'water_first_log', moduleId: 'water',
      titleKey: 'achievementWaterFirstLogTitle',
      descriptionKey: 'achievementWaterFirstLogDescription',
      target: 1, currentProgress: () async => 0,
    ),
  ];
}

void main() {
  testWidgets('shows one locked badge for the one achievement definition', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          habitModulesProvider.overrideWith((ref) => [_OneAchievementModule()]),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AchievementGalleryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.emoji_events), findsNothing); // locked = outline icon, not filled
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await db.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/achievements/presentation/achievement_gallery_screen_test.dart`
Expected: FAIL — screen doesn't exist.

- [ ] **Step 3: Implement**

`lib/features/achievements/presentation/providers/achievement_providers.dart`:

```dart
import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'achievement_providers.g.dart';

/// One achievement's definition (title/description/target) joined with
/// its persisted progress row, or `null` progress if never evaluated.
typedef AchievementView = ({
  AchievementDefinition definition,
  int progressCurrent,
  DateTime? unlockedAt,
});

/// Every registered module's achievement definitions joined with their
/// current persisted progress, for the badge gallery.
@riverpod
Stream<List<AchievementView>> achievementViews(Ref ref) {
  final modules = ref.watch(habitModulesProvider);
  final repository = ref.watch(achievementRepositoryProvider);
  return repository.watchAll().map((rows) {
    final rowsByKey = {for (final row in rows) row.key: row};
    return [
      for (final module in modules)
        for (final definition in module.achievementDefinitions)
          (
            definition: definition,
            progressCurrent: rowsByKey[definition.key]?.progressCurrent ?? 0,
            unlockedAt: rowsByKey[definition.key]?.unlockedAt case final millis?
                ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
                : null,
          ),
    ];
  });
}
```

The `case` pattern above is invalid Dart syntax for a ternary-position
match — fix it to plain null-checking before committing:

```dart
            unlockedAt: () {
              final millis = rowsByKey[definition.key]?.unlockedAt;
              return millis == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
            }(),
```

`lib/features/achievements/presentation/screens/achievement_gallery_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/achievements/presentation/providers/achievement_providers.dart';

/// Maps an [AchievementDefinition]'s `titleKey`/`descriptionKey` to its
/// localized text. Every key produced by a module's
/// `achievementDefinitions` (Water/Medicine/Prayer) must have a case
/// here — `flutter analyze`'s exhaustiveness won't catch a missing one
/// since these are plain strings, not an enum; keep this list in sync
/// with each module's achievement keys by hand.
String _localizedTitle(AppLocalizations l10n, String titleKey) {
  return switch (titleKey) {
    'achievementWaterFirstLogTitle' => l10n.achievementWaterFirstLogTitle,
    'achievementWaterStreak7Title' => l10n.achievementWaterStreak7Title,
    'achievementWaterStreak30Title' => l10n.achievementWaterStreak30Title,
    'achievementWaterStreak100Title' => l10n.achievementWaterStreak100Title,
    'achievementWaterPerfectWeekTitle' => l10n.achievementWaterPerfectWeekTitle,
    'achievementMedicineFirstDoseTitle' => l10n.achievementMedicineFirstDoseTitle,
    'achievementMedicineAdherenceStreak7Title' => l10n.achievementMedicineAdherenceStreak7Title,
    'achievementMedicineAdherenceStreak30Title' => l10n.achievementMedicineAdherenceStreak30Title,
    'achievementPrayerFirstLogTitle' => l10n.achievementPrayerFirstLogTitle,
    'achievementPrayerStreak7Title' => l10n.achievementPrayerStreak7Title,
    'achievementPrayerStreak30Title' => l10n.achievementPrayerStreak30Title,
    'achievementPrayerStreak100Title' => l10n.achievementPrayerStreak100Title,
    'achievementPrayerPerfectWeekTitle' => l10n.achievementPrayerPerfectWeekTitle,
    _ => titleKey,
  };
}

String _localizedDescription(AppLocalizations l10n, String descriptionKey) {
  return switch (descriptionKey) {
    'achievementWaterFirstLogDescription' => l10n.achievementWaterFirstLogDescription,
    'achievementWaterStreak7Description' => l10n.achievementWaterStreak7Description,
    'achievementWaterStreak30Description' => l10n.achievementWaterStreak30Description,
    'achievementWaterStreak100Description' => l10n.achievementWaterStreak100Description,
    'achievementWaterPerfectWeekDescription' => l10n.achievementWaterPerfectWeekDescription,
    'achievementMedicineFirstDoseDescription' => l10n.achievementMedicineFirstDoseDescription,
    'achievementMedicineAdherenceStreak7Description' => l10n.achievementMedicineAdherenceStreak7Description,
    'achievementMedicineAdherenceStreak30Description' => l10n.achievementMedicineAdherenceStreak30Description,
    'achievementPrayerFirstLogDescription' => l10n.achievementPrayerFirstLogDescription,
    'achievementPrayerStreak7Description' => l10n.achievementPrayerStreak7Description,
    'achievementPrayerStreak30Description' => l10n.achievementPrayerStreak30Description,
    'achievementPrayerStreak100Description' => l10n.achievementPrayerStreak100Description,
    'achievementPrayerPerfectWeekDescription' => l10n.achievementPrayerPerfectWeekDescription,
    _ => descriptionKey,
  };
}

/// The badge gallery — every module's achievements, locked (progress bar)
/// or unlocked (unlock date) (FR-C-13).
class AchievementGalleryScreen extends ConsumerWidget {
  /// Creates the achievement gallery screen.
  const AchievementGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final viewsAsync = ref.watch(achievementViewsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.achievementsTitle)),
      body: viewsAsync.when(
        data: (views) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: views.length,
          itemBuilder: (context, index) {
            final view = views[index];
            final unlocked = view.unlockedAt != null;
            return Card(
              color: unlocked ? null : Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      unlocked ? Icons.emoji_events : Icons.emoji_events_outlined,
                      size: 40,
                      color: unlocked ? Theme.of(context).colorScheme.primary : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _localizedTitle(l10n, view.definition.titleKey),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _localizedDescription(l10n, view.definition.descriptionKey),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (!unlocked)
                      LinearProgressIndicator(
                        value: view.progressCurrent / view.definition.target,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        error: (error, stack) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
```

Add to `lib/core/router/app_router.dart`: `AppRoutes.achievements =
'/achievements'` constant and a matching child `GoRoute(path:
'achievements', builder: (context, state) => const
AchievementGalleryScreen())` alongside Task 13's `reports` route, with
the import
`import 'package:habit_tracker/features/achievements/presentation/screens/achievement_gallery_screen.dart';`.

**Unlock snackbar** — add to `AchievementEngine.evaluate` (Task 8) is the
wrong layer (it has no `BuildContext`); instead, wire it where a write
already has one: in `lib/features/water/presentation/screens/
water_home_screen.dart` (and Medicine's/Prayer's equivalent "mark done"
screens), after calling the controller method that leads to
`evaluate()`, check whether any of that module's achievements just
unlocked and show a `SnackBar` if so. This is a small addition:

```dart
Future<void> _logAndCelebrate(WidgetRef ref, int amountMl) async {
  final before = await ref.read(achievementRepositoryProvider).watchByModule('water').first;
  final unlockedBefore = before.where((r) => r.unlockedAt != null).map((r) => r.key).toSet();
  await ref.read(waterControllerProvider).logQuickAdd(amountMl);
  final after = await ref.read(achievementRepositoryProvider).watchByModule('water').first;
  final newlyUnlocked = after.where(
    (r) => r.unlockedAt != null && !unlockedBefore.contains(r.key),
  );
  if (newlyUnlocked.isNotEmpty && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Achievement unlocked: ${newlyUnlocked.first.key}')),
    );
  }
}
```

This exact wiring (finding the right existing tap handler per screen,
threading a `BuildContext`) is UI-integration detail specific to each
screen's current code, not a single reusable snippet — implement it by
reading `water_home_screen.dart`'s existing quick-add button handler,
`medicine_home_screen.dart`'s "mark done" handler, and
`prayer_home_screen.dart`'s "mark prayed" handler first, then wrap each
one the same way this snippet shows. Use `l10n.achievementUnlockedSnackbar
(_localizedTitle(l10n, key))` (added in Task 16) instead of the raw key
string above once that l10n key exists.

- [ ] **Step 4: Run build_runner, then run the test to verify it passes**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/achievements/presentation/achievement_gallery_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/achievements lib/core/router/app_router.dart \
  lib/features/water/presentation/screens/water_home_screen.dart \
  lib/features/medicine/presentation/screens/medicine_home_screen.dart \
  lib/features/prayer/presentation/screens/prayer_home_screen.dart \
  test/features/achievements/presentation/achievement_gallery_screen_test.dart
git commit -m "feat(achievements): add badge gallery screen and unlock snackbars"
```

---

### Task 15: Search UI

**Files:**
- Create: `lib/features/dashboard/presentation/search/app_search_delegate.dart`
- Test: `test/features/dashboard/presentation/search/app_search_delegate_test.dart`

**Interfaces:**
- Consumes: `HabitModule.search` (Task 2/4-6), `SearchResult` (Task 2).
- Produces: `class AppSearchDelegate extends SearchDelegate<void> {
  AppSearchDelegate(List<HabitModule> modules); }` — Task 11's dashboard
  already calls this via `showSearch(context: context, delegate:
  AppSearchDelegate(modules))`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/dashboard/presentation/search/app_search_delegate.dart';
import 'package:mocktail/mocktail.dart';

class _SearchableModule extends Fake implements HabitModule {
  @override
  String get id => 'medicine';
  @override
  Future<List<SearchResult>> search(String query) async => query == 'para'
      ? [const SearchResult(title: 'Paracetamol', subtitle: '500mg', deepLinkRoute: '/medicine/m1')]
      : [];
}

void main() {
  testWidgets('typing a query shows matching results from every module', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(context: context, delegate: AppSearchDelegate([_SearchableModule()])),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'para');
    await tester.pumpAndSettle();
    expect(find.text('Paracetamol'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dashboard/presentation/search/app_search_delegate_test.dart`
Expected: FAIL — `app_search_delegate.dart` doesn't exist.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

/// Cross-module search (FR-C-15) — queries every module's own
/// [HabitModule.search] in parallel and merges the results, sorted
/// title-prefix matches first.
class AppSearchDelegate extends SearchDelegate<void> {
  /// Creates a search delegate over [_modules].
  AppSearchDelegate(this._modules);

  final List<HabitModule> _modules;

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (query.trim().isEmpty) {
      return Center(child: Text(l10n.searchPrompt));
    }
    return FutureBuilder<List<SearchResult>>(
      future: _search(query),
      builder: (context, snapshot) {
        final results = snapshot.data ?? const [];
        if (snapshot.connectionState == ConnectionState.done && results.isEmpty) {
          return Center(child: Text(l10n.searchNoResults));
        }
        return ListView(
          children: [
            for (final result in results)
              ListTile(
                title: Text(result.title),
                subtitle: Text(result.subtitle),
                onTap: () {
                  close(context, null);
                  context.go(result.deepLinkRoute);
                },
              ),
          ],
        );
      },
    );
  }

  Future<List<SearchResult>> _search(String rawQuery) async {
    final lowerQuery = rawQuery.toLowerCase();
    final perModule = await Future.wait(_modules.map((m) => m.search(rawQuery)));
    final all = perModule.expand((results) => results).toList();
    all.sort((a, b) {
      final aPrefix = a.title.toLowerCase().startsWith(lowerQuery);
      final bPrefix = b.title.toLowerCase().startsWith(lowerQuery);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
      return a.title.compareTo(b.title);
    });
    return all;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dashboard/presentation/search/app_search_delegate_test.dart`
Expected: PASS (once `searchPrompt`/`searchNoResults` exist in
`AppLocalizations` — Task 16; hardcode English placeholders temporarily
if this task runs before Task 16, same note as Task 13).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/presentation/search test/features/dashboard/presentation/search
git commit -m "feat(dashboard): add cross-module search"
```

---

### Task 16: Localization — en/bn for every new string

**Files:**
- Modify: `lib/core/l10n/app_en.arb`
- Modify: `lib/core/l10n/app_bn.arb`
- Modify: every file from Tasks 11-15 that currently has a hardcoded
  English placeholder string (search each for `'Mark done'`, `'Mark
  prayed'`, `'No data'`, and any other literal added as a stand-in).

**Interfaces:**
- Consumes: nothing new.
- Produces: every `AppLocalizations.of(context)!.xyz` getter this plan's
  earlier tasks reference by name — this task is what makes them
  compile. Run `flutter gen-l10n` after editing the arb files.

- [ ] **Step 1: Add every new key to `app_en.arb`**

Append before the final closing `}` in `lib/core/l10n/app_en.arb` (keep
the file's existing two-space-indent, one-key-per-line, immediately
followed by its `@key` metadata block format):

```json
  ,
  "reportsTitle": "Reports",
  "@reportsTitle": {"description": "Title of the cross-module reports screen."},
  "reportsPeriodWeek": "Week",
  "@reportsPeriodWeek": {"description": "Reports period selector: week."},
  "reportsPeriodMonth": "Month",
  "@reportsPeriodMonth": {"description": "Reports period selector: month."},
  "reportsPeriodYear": "Year",
  "@reportsPeriodYear": {"description": "Reports period selector: year."},
  "reportsEmptyState": "No data for this period",
  "@reportsEmptyState": {"description": "Shown when no module has data for the selected report period."},
  "reportsLongestStreak": "Longest streak: {days} days",
  "@reportsLongestStreak": {
    "description": "A module's longest-streak record on the reports screen.",
    "placeholders": {"days": {"type": "int"}}
  },
  "achievementsTitle": "Achievements",
  "@achievementsTitle": {"description": "Title of the badge gallery screen."},
  "achievementUnlockedSnackbar": "Achievement unlocked: {title}",
  "@achievementUnlockedSnackbar": {
    "description": "Snackbar shown when an achievement is newly unlocked.",
    "placeholders": {"title": {"type": "String"}}
  },
  "searchPrompt": "Search medicines and more",
  "@searchPrompt": {"description": "Placeholder shown before the user types a search query."},
  "searchNoResults": "No results found",
  "@searchNoResults": {"description": "Shown when a search query matches nothing."},
  "achievementWaterFirstLogTitle": "First Sip",
  "@achievementWaterFirstLogTitle": {"description": "Achievement title: first water entry ever logged."},
  "achievementWaterFirstLogDescription": "Log your first water entry",
  "@achievementWaterFirstLogDescription": {"description": "Achievement description: first water entry ever logged."},
  "achievementWaterStreak7Title": "Hydration Habit",
  "@achievementWaterStreak7Title": {"description": "Achievement title: 7-day water streak."},
  "achievementWaterStreak7Description": "Meet your water goal for 7 days in a row",
  "@achievementWaterStreak7Description": {"description": "Achievement description: 7-day water streak."},
  "achievementWaterStreak30Title": "Steady Stream",
  "@achievementWaterStreak30Title": {"description": "Achievement title: 30-day water streak."},
  "achievementWaterStreak30Description": "Meet your water goal for 30 days in a row",
  "@achievementWaterStreak30Description": {"description": "Achievement description: 30-day water streak."},
  "achievementWaterStreak100Title": "Century of Sips",
  "@achievementWaterStreak100Title": {"description": "Achievement title: 100-day water streak."},
  "achievementWaterStreak100Description": "Meet your water goal for 100 days in a row",
  "@achievementWaterStreak100Description": {"description": "Achievement description: 100-day water streak."},
  "achievementWaterPerfectWeekTitle": "Perfect Week",
  "@achievementWaterPerfectWeekTitle": {"description": "Achievement title: water goal met every day of the last 7 days."},
  "achievementWaterPerfectWeekDescription": "Meet your water goal every day this week",
  "@achievementWaterPerfectWeekDescription": {"description": "Achievement description: water goal met every day of the last 7 days."},
  "achievementMedicineFirstDoseTitle": "First Dose",
  "@achievementMedicineFirstDoseTitle": {"description": "Achievement title: first medicine dose ever logged."},
  "achievementMedicineFirstDoseDescription": "Log your first dose as taken",
  "@achievementMedicineFirstDoseDescription": {"description": "Achievement description: first medicine dose ever logged."},
  "achievementMedicineAdherenceStreak7Title": "On Schedule",
  "@achievementMedicineAdherenceStreak7Title": {"description": "Achievement title: 7-day medicine adherence streak."},
  "achievementMedicineAdherenceStreak7Description": "Take every dose on time for 7 days in a row",
  "@achievementMedicineAdherenceStreak7Description": {"description": "Achievement description: 7-day medicine adherence streak."},
  "achievementMedicineAdherenceStreak30Title": "Model Patient",
  "@achievementMedicineAdherenceStreak30Title": {"description": "Achievement title: 30-day medicine adherence streak."},
  "achievementMedicineAdherenceStreak30Description": "Take every dose on time for 30 days in a row",
  "@achievementMedicineAdherenceStreak30Description": {"description": "Achievement description: 30-day medicine adherence streak."},
  "achievementPrayerFirstLogTitle": "First Prayer",
  "@achievementPrayerFirstLogTitle": {"description": "Achievement title: first prayer ever marked prayed."},
  "achievementPrayerFirstLogDescription": "Mark your first prayer as prayed",
  "@achievementPrayerFirstLogDescription": {"description": "Achievement description: first prayer ever marked prayed."},
  "achievementPrayerStreak7Title": "Consistent Worship",
  "@achievementPrayerStreak7Title": {"description": "Achievement title: 7-day prayer streak."},
  "achievementPrayerStreak7Description": "Complete every prayer for 7 days in a row",
  "@achievementPrayerStreak7Description": {"description": "Achievement description: 7-day prayer streak."},
  "achievementPrayerStreak30Title": "Devoted Month",
  "@achievementPrayerStreak30Title": {"description": "Achievement title: 30-day prayer streak."},
  "achievementPrayerStreak30Description": "Complete every prayer for 30 days in a row",
  "@achievementPrayerStreak30Description": {"description": "Achievement description: 30-day prayer streak."},
  "achievementPrayerStreak100Title": "Century of Salah",
  "@achievementPrayerStreak100Title": {"description": "Achievement title: 100-day prayer streak."},
  "achievementPrayerStreak100Description": "Complete every prayer for 100 days in a row",
  "@achievementPrayerStreak100Description": {"description": "Achievement description: 100-day prayer streak."},
  "achievementPrayerPerfectWeekTitle": "Perfect Week",
  "@achievementPrayerPerfectWeekTitle": {"description": "Achievement title: every prayer completed every day of the last 7 days."},
  "achievementPrayerPerfectWeekDescription": "Complete every prayer every day this week",
  "@achievementPrayerPerfectWeekDescription": {"description": "Achievement description: every prayer completed every day of the last 7 days."}
```

The leading `,` above is a placeholder for "insert before the final
`}`" — actually splice these keys in as additional entries in the
existing top-level JSON object (add a comma after the arb file's current
last key, then paste these key/`@key` pairs, ending without a trailing
comma before the final `}`), matching the exact structure already used
by every existing key in the file — do not literally write a leading
comma-then-nothing.

- [ ] **Step 2: Add the same keys' Bangla translations to `app_bn.arb`**

Add the corresponding `bn` value for every key above, same key names,
same `@key` metadata blocks omitted (per the existing `app_bn.arb`, which
— check first — may already omit `@key` blocks since English is the
template; match whatever `app_bn.arb`'s current convention already is).
Flag any term uncertain in Bangla in a code comment in the PR description
rather than guessing, per this project's established practice (see the
Prayer module's design doc note on the same point).

- [ ] **Step 3: Regenerate and replace every temporary hardcoded string**

Run: `flutter gen-l10n`

Then in `lib/features/reports/presentation/screens/reports_screen.dart`
and `lib/features/dashboard/presentation/search/app_search_delegate.dart`,
confirm every `l10n.reportsTitle`/`l10n.searchPrompt`/etc. reference from
Tasks 13/15 now resolves (they were written against these exact getter
names already — this step just confirms no typos crept in). In
`lib/features/medicine/medicine_module.dart`'s `quickActions` and
`lib/features/prayer/prayer_module.dart`'s `quickActions` (Tasks 5-6),
replace the hardcoded `const Text('Mark done')` / `const Text('Mark
prayed')` with `Text(AppLocalizations.of(context)!.medicineMarkDoneAction)`
/ `Text(AppLocalizations.of(context)!.prayerMarkPrayedAction)` — add
those two additional keys (`medicineMarkDoneAction`: "Mark done",
`prayerMarkPrayedAction`: "Mark prayed") to both arb files the same way
as Step 1, and wrap the `ActionChip`'s `label` in a `Builder` if
`context` isn't already available at that point (check each site — the
existing `Consumer` builder in both already has a `context` parameter).

- [ ] **Step 4: Verify**

Run: `flutter analyze && dart format --output=none --set-exit-if-changed .`
Expected: clean — no more raw English strings anywhere this plan added.

- [ ] **Step 5: Commit**

```bash
git add lib/core/l10n/app_en.arb lib/core/l10n/app_bn.arb \
  lib/features/reports lib/features/achievements lib/features/dashboard \
  lib/features/medicine/medicine_module.dart lib/features/prayer/prayer_module.dart
git commit -m "feat(l10n): add en/bn strings for dashboard, reports, achievements, search"
```

---

### Task 17: Documentation — FRs, decisions, roadmap, CLAUDE.md

**Files:**
- Modify: `docs/product/functional-requirements.md`
- Modify: `docs/product/decisions.md`
- Modify: `docs/engineering/phases-and-dod.md`
- Modify: `docs/product/roadmap.md`
- Modify: `docs/product/feature-breakdown.md`
- Modify: `CLAUDE.md`

**Interfaces:** none — pure documentation, per the design spec's
"Proposed `functional-requirements.md`/`decisions.md` additions" sections
and this run's DoD rule 6.

- [ ] **Step 1: Append FR-C-11..16 to `functional-requirements.md`**

Insert immediately after the existing `**FR-C-10**` entry, before the
closing of the "Common / Cross-Module (FR-C)" section, the exact text
from `docs/superpowers/specs/2026-07-19-dashboard-reports-achievements-design.md`'s
"Proposed `functional-requirements.md` additions" section (FR-C-11
through FR-C-16, copied verbatim).

- [ ] **Step 2: Append D-16..19 to `decisions.md`**

Insert after the existing `## D-15` entry, at the end of the file, the
exact text from the same spec's "Proposed `decisions.md` additions"
section (D-16 through D-19, copied verbatim).

- [ ] **Step 3: Add a Run 15 section to `phases-and-dod.md`**

Append after the existing `## Run 14` section:

```markdown
## Run 15 — Dashboard, reports, achievements

- **Entry criteria:** Run 14 merged (v1.0 shipped). This run is v1.1-class
  scope, sequenced after v1.0, not a renumbering of Run 13 (which already
  shipped dashboard aggregation + module enable/disable + PIN lock).
- **Scope in:** per
  `../superpowers/specs/2026-07-19-dashboard-reports-achievements-design.md`
  — `HabitModule` contract extensions (`dayStatus`/`nextUpcoming`/
  `quickActions`/`search`/`achievementDefinitions`), the achievement
  engine + badge gallery, weekly/monthly/yearly cross-module reports +
  longest-streak records, cross-module search, a global month calendar.
- **Scope out:** no new module, no PIN/enable-disable changes (Run 13's
  scope, untouched).
- **Feature demo checklist:** seed 4+ weeks of data across Water/
  Medicine/Prayer → dashboard shows the day-completion ring, upcoming
  strip, and quick actions → Reports shows sane week/month/year numbers
  and longest-streak records for each module → badge gallery shows a mix
  of locked/unlocked badges, unlocking one shows a snackbar, not a modal
  → global calendar's month coloring matches per-day status, day
  drill-down shows each module's individual status → search finds a
  seeded medicine by name → full Bangla pass.
- **Rollback:** unmet DoD leaves `dev` at Run 14's state — v1.0 stays
  shippable either way, since this run is additive.
```

Add matching one-paragraph "Run 15" entries to `docs/product/roadmap.md`
(its "v0.x internal milestones" table/list — add a v1.1-labeled row) and
`docs/product/feature-breakdown.md` (its per-run bullet-list format,
matching the style of its existing "## Run 14" section) — read each
file's existing Run 14 entry first and match its exact formatting rather
than inventing new structure.

- [ ] **Step 4: Update `CLAUDE.md`'s project-state paragraph**

Append one paragraph to the end of the "## Project state" section (after
the existing Prayer paragraph), summarizing this run in the same
telegraphic style as the existing text — e.g.:

```markdown
Run 15 adds a v1.1-class cross-module layer: `HabitModule` gained
`dayStatus`/`nextUpcoming`/`quickActions`/`search`/`achievementDefinitions`
(all three modules implement all five); `core/achievements/` (engine +
repository, evaluated from each module's own write path, not a periodic
sweep) now actually reads/writes the `achievements` table that's existed
schema-only since Run 06; `core/reports/` (`day_status_streaks.dart`,
`aggregate_report_usecase.dart`) backs the new Reports screen
(week/month/year, longest-streak records) and Medicine's adherence-streak
achievements; the dashboard gained a day-completion indicator, upcoming
strip, quick actions, a global month calendar (bottom sheet, not a
route), and cross-module search (`showSearch`/`SearchDelegate`, no new
dependency).
```

- [ ] **Step 5: Commit**

```bash
git add docs/product/functional-requirements.md docs/product/decisions.md \
  docs/engineering/phases-and-dod.md docs/product/roadmap.md \
  docs/product/feature-breakdown.md CLAUDE.md
git commit -m "docs: add FR-C-11..16, D-16..19, Run 15 sections for dashboard/reports/achievements"
```

---

### Task 18: Final verification

**Files:** none new — this task only runs checks across everything Tasks
1-17 produced.

**Interfaces:** none.

- [ ] **Step 1: Full static checks**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `dart format --output=none --set-exit-if-changed .`
Expected: no output, exit code 0.

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: every test file passes, including every new test from Tasks
1-15 and every pre-existing test (Water/Medicine/Prayer module/repository/
widget tests) — a regression in any of those means an earlier task
changed shared behavior it shouldn't have.

- [ ] **Step 3: Manual smoke test (per the spec's Testing section)**

Run the app (`flutter run`) against a build with 4+ weeks of seeded data
across all three modules (use each module's existing add/log/mark-done
screens to seed it, backdating entries where the UI allows — Water's
add-entry screen supports a backdated timestamp per FR-W-05). Walk
through:
1. Dashboard shows the day-completion ring, upcoming strip, and quick
   actions for all three modules.
2. Reports (app-bar icon) shows non-empty week/month/year charts and a
   longest-streak number per module; switching period/navigating
   prev-next updates the charts.
3. Achievements (app-bar icon) shows a mix of locked (progress bar) and
   unlocked (trophy icon) badges; performing an action that crosses a
   threshold shows the unlock snackbar, not a modal.
4. Global calendar (bottom sheet from the dashboard) colors days
   correctly and its day-tap dialog shows each module's status.
5. Search finds a seeded medicine name and navigates to its detail screen
   on tap.
6. Switch language to Bangla in Settings — every string on all four new
   surfaces (dashboard additions, Reports, Achievements, search) renders
   in Bangla, nothing left in English.

- [ ] **Step 4: Decoupling proof, manual half**

Comment out one line in `lib/core/modules/module_registry.dart`'s
`buildHabitModules` (e.g. remove `MedicineModule(...)` from the returned
list), run `flutter analyze` and `flutter run` — confirm the app still
builds and boots, the dashboard/reports/achievements/calendar/search all
render without that module's data, and no file under `lib/core/` needed
any change to make this work. Revert the comment-out afterward (this is
a manual check, not a permanent change).

- [ ] **Step 5: Final commit note**

No new commit needed here — Task 18 is verification only. If Step 1-4
surfaced any fixes, make those fixes as small follow-up commits on the
same branch (each with its own `git add`/`git commit`, not amended onto
an earlier task's commit) before moving to
`superpowers:finishing-a-development-branch` to merge/squash per
`docs/engineering/git-strategy.md`.

---

## Self-Review Notes (for whoever executes this plan)

- **Spec coverage:** every section of the design doc has a task —
  contract extensions (Task 2), per-module implementations (4-6),
  achievement engine (7-9), reports (3, 10, 13), dashboard (11),
  global calendar (12), achievements UI (14), search (15), localization
  (16), docs (17), decoupling proof (11 + 18 Step 4).
- **Known rough edges flagged inline, not hidden:** Task 5's first draft
  of the `medicine_first_dose` closure and Task 14's `unlockedAt` mapping
  each contain a deliberately-included mistake with an immediate
  correction shown right after — this is intentional, matching how a
  real first-pass implementation reads, not a plan error to silently
  trust; implement the corrected version.
- **Ordering dependency:** Tasks 13 and 15 reference `AppLocalizations`
  getters that don't exist until Task 16. Implement them in plan order
  (13 → 14 → 15 → 16) with temporary hardcoded English strings where
  noted, or reorder Task 16 earlier if executing with subagents in
  parallel — either works, just don't parallelize 13/15 with 16 without
  picking one of these two strategies explicitly.

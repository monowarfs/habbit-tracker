# Adaptive Quest Difficulty (Gamification Tie-In)

**Category:** AI-Powered · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
The achievements engine added in Run 15 evaluates fixed achievement
definitions per module (streak milestones, adherence thresholds, etc.),
which works well for one-time badges but doesn't yet cover recurring
weekly quests that scale to a user's own pace. A fixed weekly target is
either trivially easy for a consistent user (no motivational value) or
discouraging for someone still building the habit (feels punitive rather
than encouraging). Habitica's difficulty-scaling pattern — quests that
track your own recent baseline rather than an arbitrary fixed number —
is the direct inspiration, and ties naturally into gamification as a
retention lever this app doesn't yet have.

## Goals
- Introduce weekly quests whose target scales to each user's own recent
  rolling-average pace per module, rather than a fixed number for
  everyone.
- Let a quest feel achievable-but-not-trivial regardless of whether a
  user is just starting out or already highly consistent.
- Plug into the achievements engine's existing evaluation model (each
  module's own write path triggers evaluation, not a periodic sweep) so
  quest completion detection follows the same pattern as existing
  achievements.

## Non-goals / out of scope
- No difficulty model beyond a simple rolling-average-based target
  calculation — no machine learning, no per-user profiling beyond their
  own recent activity counts.
- Not a full RPG-style gamification layer (avatars, currencies, pets) —
  scoped strictly to the quest-difficulty-scaling mechanic itself.
- Does not change how the existing fixed achievement definitions
  (streaks, adherence badges) work — this is a new, separate quest type
  alongside them, not a replacement.

## Proposed approach (high-level)
Pure local arithmetic on top of the existing achievements engine and
each module's own log/completion history: for a given module, compute a
rolling average of recent activity (e.g. average Water logs per week
over the last several weeks, or Medicine adherence rate), and generate a
weekly quest target modestly above that baseline (a small percentage
stretch, not a fixed jump) so it's calibrated to that specific user.
Quest definitions become a new category alongside each module's existing
`achievementDefinitions`, evaluated the same way — from each module's own
write path when a qualifying action happens, not a periodic background
sweep — reusing the achievements repository's existing read/write access
to the `achievements` table (or a small sibling table for
quest-specific state, e.g. current week's target and progress, if the
existing schema doesn't naturally fit weekly-rolling quests).

## Dependencies & prerequisites
- The existing achievements engine and repository (Run 15).
- Each module's log/completion history as the input to the rolling
  average.
- A design decision on how quests are surfaced in the UI (a dedicated
  quests section vs. folded into the existing achievements/dashboard
  surfaces).

## Open questions for the implementation round
- Does quest state need its own table, or can it be modeled as a
  specialized row/type within the existing `achievements` schema?
- What stretch percentage above baseline feels motivating without
  feeling arbitrary or unfair — likely needs some manual tuning/testing
  rather than a single obviously-correct formula.
- How does a quest handle a user whose baseline is zero (never done the
  habit) — some minimum floor target is presumably needed.
- Do quests reset every week regardless of completion, or roll over
  partial progress?

## Effort & sequencing notes
Complexity M — leans heavily on infrastructure that already exists
(achievements engine, per-module history), so the net-new work is mostly
the rolling-average calculation and the quest-specific UI surface, not a
new subsystem. Reasonable to sequence after core achievements work has
had time to stabilize, since quests are additive to that system.

---

## Implementation Plan (Low-Level)

### 1. Schema changes

#### New Drift table: `weekly_quests`

**File to create:** `lib/core/database/tables/weekly_quests_table.dart`

A dedicated table is cleaner than reusing the `achievements` table because
quests are weekly-rolling, ephemeral (reset each week), and need their own
progress/target that differ from one-time achievement unlock semantics.

```dart
import 'package:drift/drift.dart';

@DataClassName('WeeklyQuestRow')
class WeeklyQuestsTable extends Table {
  @override
  String get tableName => 'weekly_quests';

  /// Row id (UUID).
  TextColumn get id => text()();

  /// Which module this quest belongs to.
  TextColumn get moduleId => text()();

  /// ISO week start date (Monday) as epoch millis — the quest's week.
  IntColumn get weekStartMillis => integer()();

  /// Target count for this week (rolling average × stretch factor).
  IntColumn get targetCount => integer()();

  /// Rolling average baseline that produced [targetCount] (for display).
  IntColumn get baselineCount => integer()();

  /// How many days of history were used to compute baseline.
  IntColumn get sampleDays => integer()();

  /// Current progress toward [targetCount].
  IntColumn get currentProgress => integer()();

  /// Whether the user completed this quest.
  BoolColumn get isCompleted => boolean()();

  /// UTC epoch millis when quest was created.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

#### Register in AppDatabase

**File to modify:** `lib/core/database/app_database.dart`

Add import + table to `@DriftDatabase(tables: [...])`:
```dart
import 'package:habit_tracker/core/database/tables/weekly_quests_table.dart';
// ...
tables: [
  // ... existing tables ...
  WeeklyQuestsTable,  // ← new
],
```

Bump `schemaVersion` from 7 to 8 and add migration:
```dart
if (from < 8) {
  await m.createTable(weeklyQuestsTable);
}
```

### 2. Domain entities

#### `WeeklyQuest`

**File to create:** `lib/features/quests/domain/entities/weekly_quest.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'weekly_quest.freezed.dart';

/// A weekly quest whose target scales to the user's rolling average.
@freezed
class WeeklyQuest with _$WeeklyQuest {
  const factory WeeklyQuest({
    required String id,
    required String moduleId,
    required DateTime weekStart,       // Monday of the quest week
    required int targetCount,          // stretch target
    required int baselineCount,        // rolling average that produced target
    required int sampleDays,           // days of history used
    required int currentProgress,
    required bool isCompleted,
  }) = _WeeklyQuest;

  /// Progress fraction 0.0–1.0 for UI display.
  double get progressFraction =>
      targetCount > 0 ? (currentProgress / targetCount).clamp(0.0, 1.0) : 0.0;
}
```

#### `QuestDefinition` (analogous to `AchievementDefinition`)

**File to create:** `lib/features/quests/domain/entities/quest_definition.dart`

```dart
/// Describes one module's weekly quest — the module provides the
/// calculation closure, the engine evaluates it.
@immutable
class QuestDefinition {
  const QuestDefinition({
    required this.moduleId,
    required this.computeWeeklyCount,
  });

  /// The module this quest tracks.
  final String moduleId;

  /// Closure returning the user's count of completed actions this
  /// current week. The engine calls this to compute progress.
  /// E.g. Water: number of days with >= goal met this week.
  /// Medicine: number of doses taken this week.
  /// Prayer: number of days where all prayers were completed this week.
  final Future<int> Function() computeWeeklyCount;
}
```

### 3. Use cases

#### `CalculateWeeklyQuestUseCase` (pure)

**File to create:** `lib/features/quests/domain/usecases/calculate_weekly_quest_usecase.dart`

```dart
/// Pure use case: computes a weekly quest target from rolling average.
class CalculateWeeklyQuestUseCase {
  const CalculateWeeklyQuestUseCase({
    this.lookbackWeeks = 4,
    this.stretchFactorPct = 15,  // 15% above baseline
    this.floorTarget = 1,         // minimum target even at zero baseline
  });

  /// Number of past weeks to average over.
  final int lookbackWeeks;

  /// Percentage above baseline for the stretch target (e.g. 15 → 1.15×).
  final int stretchFactorPct;

  /// Minimum target when baseline is zero or very low.
  final int floorTarget;

  /// Computes the quest for [moduleId] given [weeklyCounts] (most recent
  /// week first) and [currentWeekCount] (this week's live count).
  ///
  /// Returns null if fewer than 2 weeks of history exist (not enough
  /// data for a meaningful average).
  WeeklyQuest compute({
    required String moduleId,
    required List<int> weeklyCounts,  // recent weeks, index 0 = most recent
    required int currentWeekCount,
    required DateTime weekStart,
  }) {
    // 1. Compute rolling average from weeklyCounts (skip current week)
    // 2. Apply stretch: target = max(floor, round(baseline * (1 + stretchPct/100)))
    // 3. Construct WeeklyQuest with currentProgress = currentWeekCount
    // 4. Mark isCompleted = currentProgress >= targetCount
    // ...
  }
}
```

**Rolling average algorithm:**
```
baseline = average of last N weeks' counts (excluding current week)
target = max(floorTarget, round(baseline * (1 + stretchFactorPct / 100)))
```

Edge cases:
- **Zero baseline** (never done the habit): `floorTarget = 1` (do it once this week)
- **1 week of history**: use that single week as baseline
- **< 1 week of history**: return null (not enough data, no quest generated)
- **Very high baseline**: target still applies the stretch — no cap, but
  `stretchFactorPct` of 15% keeps it modest

#### `EvaluateWeeklyQuestUseCase` (wiring to achievements engine)

**File to create:** `lib/features/quests/domain/usecases/evaluate_weekly_quest_usecase.dart`

```dart
/// Evaluates one module's weekly quest and persists progress.
/// Called from the module's own write path (same pattern as AchievementEngine).
class EvaluateWeeklyQuestUseCase {
  const EvaluateWeeklyQuestUseCase({required this.questRepository});
  final WeeklyQuestRepository questRepository;

  /// Evaluates [moduleId]'s quest for the current week.
  ///
  /// 1. Get or create this week's quest row (CalculateWeeklyQuestUseCase
  ///    if no row exists yet for this week)
  /// 2. Get current progress from the quest definition's closure
  /// 3. Update progressCurrent, mark completed if >= target
  Future<void> execute({
    required String moduleId,
    required QuestDefinition definition,
  }) async { ... }
}
```

### 4. Data layer

#### Repository interface

**File to create:** `lib/features/quests/data/weekly_quest_repository.dart`

```dart
/// CRUD over the `weekly_quests` table.
class WeeklyQuestRepository {
  WeeklyQuestRepository(this._db);
  final AppDatabase _db;

  /// The quest for [moduleId] in the week starting [weekStart], or null.
  Future<WeeklyQuestRow?> byModuleAndWeek({
    required String moduleId,
    required DateTime weekStart,
  }) { ... }

  /// All quests for [moduleId], ordered by week descending.
  Stream<List<WeeklyQuestRow>> watchByModule(String moduleId) { ... }

  /// All quests across all modules, ordered by week descending.
  Stream<List<WeeklyQuestRow>> watchAll() { ... }

  /// Creates or updates the quest's progress. Called by EvaluateWeeklyQuestUseCase.
  Future<void> upsertQuest({
    required String moduleId,
    required DateTime weekStart,
    required int targetCount,
    required int baselineCount,
    required int sampleDays,
    required int currentProgress,
  }) { ... }

  /// Soft-deletes old quests (older than N weeks) during weekly reset.
  Future<void> pruneOldQuests({required int keepWeeks}) { ... }
}
```

#### Weekly reset logic

Quests reset every Monday regardless of completion. The `pruneOldQuests`
method is called on app startup (in `main.dart`'s initialization or
from a Riverpod provider) to soft-delete quests older than 12 weeks.

Partial progress does NOT roll over — each week starts fresh. This is
by design: the target adapts, so carrying over partial progress would
double-count.

### 5. Integration with achievements engine

**File to modify:** `lib/core/achievements/achievement_engine.dart`

Add a `evaluateWeeklyQuests(String moduleId)` method alongside the
existing `evaluate(String moduleId)`:

```dart
/// Re-evaluates weekly quests for [moduleId].
/// Called from the same module write path as evaluate().
Future<void> evaluateWeeklyQuests(String moduleId) async {
  final module = modules.firstWhere((m) => m.id == moduleId);
  final definition = module.questDefinition;  // new getter on HabitModule
  if (definition == null) return;
  await evaluateWeeklyQuestUseCase.execute(
    moduleId: moduleId,
    definition: definition,
  );
}
```

**File to modify:** `lib/core/modules/habit_module.dart`

Add optional getter to `HabitModule`:
```dart
/// Weekly quest definition, or null if this module doesn't support quests.
QuestDefinition? get questDefinition => null;
```

Each module that supports quests (Water, Medicine, Prayer) overrides
this to provide the `computeWeeklyCount` closure.

**File to modify:** `lib/core/achievements/achievement_providers.dart`

Add provider for `WeeklyQuestRepository` and `EvaluateWeeklyQuestUseCase`.

### 6. Module-specific quest definitions

#### Water quest

**File to modify:** `lib/features/water/water_module.dart`

```dart
@override
QuestDefinition? get questDefinition => QuestDefinition(
  moduleId: id,
  computeWeeklyCount: () async {
    // Count days this week where total logged >= goal
    final today = localDayKey(clock.now());
    final weekStart = today.addDays(-(today.toDateTimeUtc().weekday - 1));
    final range = DateRange(start: weekStart, end: today);
    final dayStatus = await _repository.dayStatus(range);
    return dayStatus.values
        .where((s) => s.kind == ModuleDayStatusKind.complete)
        .length;
  },
);
```

#### Medicine quest

**File to modify:** `lib/features/medicine/medicine_module.dart`

```dart
@override
QuestDefinition? get questDefinition => QuestDefinition(
  moduleId: id,
  computeWeeklyCount: () async {
    // Count doses taken this week
    final today = localDayKey(clock.now());
    final weekStart = today.addDays(-(today.toDateTimeUtc().weekday - 1));
    final range = DateRange(start: weekStart, end: today);
    final dayStatus = await _repository.dayStatus(range);
    return dayStatus.values
        .where((s) => s.kind == ModuleDayStatusKind.complete)
        .length;
  },
);
```

#### Prayer quest

**File to modify:** `lib/features/prayer/prayer_module.dart`

```dart
@override
QuestDefinition? get questDefinition => QuestDefinition(
  moduleId: id,
  computeWeeklyCount: () async {
    final today = localDayKey(clock.now());
    final weekStart = today.addDays(-(today.toDateTimeUtc().weekday - 1));
    final range = DateRange(start: weekStart, end: today);
    final dayStatus = await _repository.dayStatus(range);
    return dayStatus.values
        .where((s) => s.kind == ModuleDayStatusKind.complete)
        .length;
  },
);
```

### 7. Presentation layer

#### Quest progress widget (dashboard)

**File to create:** `lib/features/quests/presentation/widgets/quest_progress_card.dart`

A `Card` widget placed on the dashboard (below `_QuickActionsRow`,
above module summary cards) showing:
- Module icon + name
- "This week's quest: X/Y days" with `LinearProgressIndicator`
- Baseline note: "Based on your average of Z days/week"
- Completed state: checkmark + "Quest completed!" celebration

#### Quest section on dashboard

**File to modify:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

Add a `_QuestSection` widget between `_QuickActionsRow` and module
summaries. This widget:
1. Loads all modules' current weekly quests via a new provider
2. Renders a horizontal `ListView` of `QuestProgressCard` widgets
3. Empty state: no cards shown (quests not yet generated for new users)

#### Quest providers

**File to create:** `lib/features/quests/presentation/providers/quest_providers.dart`

```dart
/// All modules' current weekly quests, live-updating.
@riverpod
Stream<List<WeeklyQuest>> currentWeekQuests(Ref ref) {
  final repository = ref.watch(weeklyQuestRepositoryProvider);
  return repository.watchAll();
}
```

#### Quest completion celebration

**File to create:** `lib/features/quests/presentation/widgets/quest_completion_dialog.dart`

A simple `AlertDialog` with a congratulatory message when a quest is
completed mid-week. Triggered by the `WeeklyQuest` stream emitting a
row where `isCompleted` just became true.

### 8. L10n strings

**Files to modify:** `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`

New keys:
```json
"questTitle": "Weekly Quest",
"questProgress": "{current}/{target} days",
"questBaseline": "Based on your average of {baseline} days/week",
"questCompleted": "Quest completed! Great work!",
"questNoData": "Keep logging to unlock your first quest",
"questModuleName": "{module} Quest"
```

### 9. Testing strategy

| Test file | What it covers | Type |
|-----------|---------------|------|
| `test/features/quests/domain/usecases/calculate_weekly_quest_usecase_test.dart` | Rolling average: 4-week history, zero baseline (floor target), 1-week history, edge case with all zeros, stretch factor calculation | Unit |
| `test/features/quests/domain/usecases/evaluate_weekly_quest_usecase_test.dart` | Creates quest if none exists, updates progress, marks completed, handles existing quest row | Unit |
| `test/features/quests/data/weekly_quest_repository_test.dart` | byModuleAndWeek, upsert, pruneOldQuests | Unit (Drift test DB) |
| `test/features/quests/presentation/widgets/quest_progress_card_test.dart` | Renders progress bar, shows baseline, shows completed state | Widget |
| `test/features/dashboard/presentation/screens/dashboard_screen_test.dart` | (existing file, add case) Quest section appears when quests exist, hidden when none | Widget |

**Key edge cases for `CalculateWeeklyQuestUseCase` tests:**
- Baseline 0 → target = `floorTarget` (1)
- Baseline 3 → target = 4 (15% stretch, rounded)
- Baseline 7 → target = 8
- Baseline 1 → target = 1 (stretched from 1.15 rounds to 1, but floor is 1)
- Only 1 week of history → still generates quest
- Empty `weeklyCounts` → returns null (no quest)

### 10. Complete file list

**Files to create (7):**
- `lib/core/database/tables/weekly_quests_table.dart`
- `lib/features/quests/domain/entities/weekly_quest.dart`
- `lib/features/quests/domain/entities/quest_definition.dart`
- `lib/features/quests/domain/usecases/calculate_weekly_quest_usecase.dart`
- `lib/features/quests/domain/usecases/evaluate_weekly_quest_usecase.dart`
- `lib/features/quests/data/weekly_quest_repository.dart`
- `lib/features/quests/presentation/providers/quest_providers.dart`
- `lib/features/quests/presentation/widgets/quest_progress_card.dart`
- `lib/features/quests/presentation/widgets/quest_completion_dialog.dart`

**Files to modify (7):**
- `lib/core/database/app_database.dart` — add table, bump schema version to 8
- `lib/core/modules/habit_module.dart` — add `questDefinition` getter
- `lib/core/achievements/achievement_engine.dart` — add `evaluateWeeklyQuests` method
- `lib/core/achievements/achievement_providers.dart` — add quest repository/use case providers
- `lib/features/water/water_module.dart` — implement `questDefinition`
- `lib/features/medicine/medicine_module.dart` — implement `questDefinition`
- `lib/features/prayer/prayer_module.dart` — implement `questDefinition`
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` — add quest section
- `lib/core/l10n/app_en.arb` — add quest strings
- `lib/core/l10n/app_bn.arb` — add Bangla quest strings

**Test files to create (4):**
- `test/features/quests/domain/usecases/calculate_weekly_quest_usecase_test.dart`
- `test/features/quests/domain/usecases/evaluate_weekly_quest_usecase_test.dart`
- `test/features/quests/data/weekly_quest_repository_test.dart`
- `test/features/quests/presentation/widgets/quest_progress_card_test.dart`

### 11. Sequencing and effort estimates

| # | Task | Depends on | Effort |
|---|------|-----------|--------|
| 1 | Create `WeeklyQuestsTable` Drift table definition | — | S |
| 2 | Register table in `AppDatabase`, bump schema, add migration | 1 | S |
| 3 | Create `WeeklyQuest` freezed entity | — | S |
| 4 | Create `QuestDefinition` entity | — | S |
| 5 | Create `CalculateWeeklyQuestUseCase` (pure, heavily tested) | 3 | M |
| 6 | Create `WeeklyQuestRepository` | 1, 2 | M |
| 7 | Create `EvaluateWeeklyQuestUseCase` | 5, 6 | M |
| 8 | Add `questDefinition` to `HabitModule` contract | 4 | S |
| 9 | Implement `questDefinition` in Water, Medicine, Prayer | 8 | M |
| 10 | Add `evaluateWeeklyQuests` to `AchievementEngine` | 7 | S |
| 11 | Add quest providers (`quest_providers.dart`) | 6 | S |
| 12 | Create `QuestProgressCard` widget | 3 | S |
| 13 | Create `QuestCompletionDialog` widget | 3 | S |
| 14 | Add quest section to dashboard | 11, 12 | M |
| 15 | Add L10n strings (en/bn) | — | S |
| 16 | Write unit tests for `CalculateWeeklyQuestUseCase` | 5 | M |
| 17 | Write unit tests for `EvaluateWeeklyQuestUseCase` | 7 | S |
| 18 | Write widget tests for quest cards | 12 | S |
| 19 | Run `build_runner build`, verify no analysis errors | all | S |

**Total effort: L** (19 tasks, new table + new feature module + engine integration)
**Estimated duration: 2–3 focused sessions**

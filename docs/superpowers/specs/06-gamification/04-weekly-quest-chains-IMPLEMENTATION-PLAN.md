# Implementation Plan: Weekly Quest Chains

**Spec:** 04-weekly-quest-chains-design.md
**Complexity:** M | **Estimated effort:** 3 days
**Dependencies:** Achievements engine, each module's achievement definitions

---

## Overview

Recurring weekly objectives per module (e.g. "hit water goal 5 of 7 days") with automatic Monday reset. Extends the achievements engine's evaluation pattern with a weekly reset window. Quests are auto-generated from a curated set per module.

---

## Implementation Tasks

### Task 1: Weekly Quest Drift Table

**Files to create/modify:**
- `lib/core/database/tables/weekly_quests_table.dart` (create)
- `lib/core/database/app_database.dart` (modify)

**Drift table:**
```dart
@DataClassName('WeeklyQuestRow')
class WeeklyQuestsTable extends Table {
  @override
  String get tableName => 'weekly_quests';

  TextColumn get id => text()();
  TextColumn get questKey => text()();           // e.g. 'water_goal_5_of_7'
  TextColumn get moduleId => text()();
  TextColumn get weekKey => text()();            // 'YYYY-Www' ISO week format
  IntColumn get progressCurrent => integer()();
  IntColumn get progressTarget => integer()();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get rewardClaimed => integer()();    // bool: 0 or 1
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {questKey, weekKey},
  ];
}
```

**Migration:** `if (from < 20)` (or next available). Bump `schemaVersion`.

---

### Task 2: Quest Definitions

**Files to create:**
- `lib/core/gamification/quests/quest_definition.dart`

```dart
class QuestDefinition {
  const QuestDefinition({
    required this.questKey,
    required this.moduleId,
    required this.titleKey,
    required this.descriptionKey,
    required this.target,
    required this.progressEvaluator,
  });

  final String questKey;
  final String moduleId;
  final String titleKey;
  final String descriptionKey;
  final int target;
  final Future<int> Function() progressEvaluator;
}
```

**Files to create (per module):**
- `lib/core/gamification/quests/water_quests.dart`
- `lib/core/gamification/quests/medicine_quests.dart`
- `lib/core/gamification/quests/prayer_quests.dart`

**Quest catalog (v1, fixed):**
| Module | Quest | Target |
|---|---|---|
| Water | `water_goal_5_of_7` | 5 days with goal met |
| Water | `water_no_skip_week` | 7 days with any log |
| Medicine | `medicine_perfect_week` | 7/7 days all doses taken |
| Medicine | `medicine_90_percent` | 90% adherence this week |
| Prayer | `prayer_5_of_7` | 5 days with all 5 prayers |
| Prayer | `prayer_no_skip_week` | 7 days with at least 1 prayer |

---

### Task 3: Week Key Utility

**Files to create:**
- `lib/core/gamification/quests/week_utils.dart`

```dart
/// Returns the ISO 8601 week key ('YYYY-Www') for the given date.
/// Uses localDayKey() for DST safety.
String weekKeyForDate(LocalDate date);

/// Returns the Monday of the current week.
LocalDate mondayOfWeek(LocalDate date);

/// Returns true if [date] is in the same ISO week as [weekKey].
bool isInWeek(LocalDate date, String weekKey);
```

---

### Task 4: Quest Repository

**Files to create:**
- `lib/core/gamification/quests/quest_repository.dart`

```dart
class QuestRepository {
  QuestRepository(this._db);
  final AppDatabase _db;

  /// Ensures quests for the current week exist for all modules.
  /// Generates from [QuestDefinition] catalog if not already present.
  Future<void> ensureCurrentWeekQuests({
    required List<QuestDefinition> definitions,
    required DateTime now,
  });

  /// Updates progress for a specific quest.
  Future<void> updateProgress({
    required String questKey,
    required String weekKey,
    required int current,
    required DateTime now,
  });

  /// Marks a quest as completed and reward as claimed.
  Future<void> claimReward(String questKey, String weekKey, {required DateTime now});

  /// All quests for the current week, grouped by module.
  Stream<List<WeeklyQuestRow>> watchCurrentWeek({required String weekKey});
}
```

---

### Task 5: Quest Engine

**Files to create:**
- `lib/core/gamification/quests/quest_engine.dart`

```dart
class QuestEngine {
  QuestEngine({
    required this.repository,
    required this.definitions,
  });

  final QuestRepository repository;
  final List<QuestDefinition> definitions;

  /// Called after each module write to update quest progress.
  /// Finds quests matching [moduleId] and re-evaluates their progress.
  Future<void> evaluateModule(String moduleId, {required DateTime now});

  /// Generates quests for a new week (called on Monday or first app open).
  Future<void> generateWeek({required DateTime now});
}
```

**Integration:** `QuestEngine.evaluateModule()` is called from each module's controller after a write, similar to `AchievementEngine.evaluate()`. The engine checks if the current week's quests exist, generates them if not, then re-evaluates progress for the affected module's quests.

---

### Task 6: Quest Progress Provider

**Files to create:**
- `lib/core/gamification/quests/quest_providers.dart`

```dart
@riverpod
Stream<List<WeeklyQuestRow>> currentWeekQuests(Ref ref) {
  final weekKey = weekKeyForDate(localDayKey(clock.now()));
  return questRepository.watchCurrentWeek(weekKey: weekKey);
}

@riverpod
List<WeeklyQuestRow> activeQuests(Ref ref) {
  final quests = ref.watch(currentWeekQuestsProvider).valueOrNull ?? [];
  return quests.where((q) => q.completedAt == null).toList();
}
```

---

### Task 7: Quest List UI

**Files to create:**
- `lib/features/dashboard/presentation/widgets/weekly_quest_list.dart`

```dart
class WeeklyQuestList extends ConsumerWidget {
  /// Shows current week's quests with progress bars.
  /// Displays per-module quests with "{current}/{target}" progress.
  /// Completed quests show a checkmark and "Claim" button.
}
```

**Dashboard integration:** Insert `WeeklyQuestList` in `DashboardScreen` after `XpLevelDisplay`.

---

### Task 8: Quest Completion Celebration

**Files to create:**
- `lib/core/gamification/quests/quest_completion_celebration.dart`

```dart
Future<void> showQuestCompletionCelebration(BuildContext context, {
  required WeeklyQuestRow quest,
  required int xpReward,
});
```

**Integration:** When `QuestEngine` detects `progressCurrent >= progressTarget` and `completedAt` was null, trigger celebration + award XP via `XpRepository`.

---

### Task 9: Auto-Reset on Week Boundary

**Files to create:**
- `lib/core/gamification/quests/weekly_quest_reset_handler.dart`

```dart
/// Checks on app resume if the current week key differs from the last
/// evaluated week. If so, generates new quests for the new week.
class WeeklyQuestResetHandler {
  Future<void> checkAndReset({required DateTime now});
}
```

**Integration:** Called from `HabitTrackerApp`'s `WidgetsBindingObserver.didChangeAppLifecycleState` (same place notifications are re-planned on resume).

---

### Task 10: Localization

**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**ARB keys:**
```
"weeklyQuestTitle": "This Week's Quests",
"weeklyQuestProgress": "{current}/{target} days",
"weeklyQuestComplete": "Quest complete! Claim your reward.",
"weeklyQuestReset": "New quests available every Monday.",
"weeklyQuestClaimButton": "Claim Reward",
"weeklyQuestClaimed": "Reward claimed",
"questWater5of7": "Meet your water goal 5 of 7 days",
"questWaterNoSkip": "Log water every day this week",
"questMedicinePerfect": "Take all doses every day this week",
"questMedicine90": "90% medicine adherence this week",
"questPrayer5of7": "Complete all 5 prayers 5 of 7 days",
"questPrayerNoSkip": "Pray at least once every day this week"
```

---

## Performance Considerations

- **Caching:** Quest definitions are static — no runtime cost. Week key is computed once per app session.
- **Lazy loading:** Quest progress is evaluated on module writes, not periodically. No background scanning.
- **Memory:** Max 6 quest rows per week (2 per module × 3 modules).

---

## Testing

**Files to create:**
- `test/core/gamification/quests/week_utils_test.dart`
- `test/core/gamification/quests/quest_repository_test.dart`
- `test/core/gamification/quests/quest_engine_test.dart`
- `test/core/gamification/quests/quest_definitions_test.dart`
- `test/features/dashboard/presentation/widgets/weekly_quest_list_test.dart`

**Coverage:**
| Test | Covers |
|---|---|
| `week_utils_test.dart` | ISO week key computation, DST edge cases, Monday boundary |
| `quest_repository_test.dart` | Quest generation, progress update, completion, dedup |
| `quest_engine_test.dart` | Module write triggers re-evaluation, new week generation |
| `quest_definitions_test.dart` | All modules return valid definitions, target values |
| `weekly_quest_list_test.dart` | Progress bar renders, completion state, claim button |

---

## Edge Cases

- **Week boundary DST:** ISO 8601 weeks are timezone-agnostic (Monday 00:00 UTC). Use `localDayKey()` to determine local Monday.
- **Quest completion timing:** Last required action on Sunday 23:59 → quest complete. Monday after midnight → new week.
- **Missed week:** Quests expire silently — no penalty, no carryover.
- **Multiple modules:** Each module gets 1-2 quests per week. Cross-module quests deferred to Spec 06 (combo bonus).
- **First app open of week:** `WeeklyQuestResetHandler` generates new quests.

# Implementation Plan: Cross-Module XP / Level System

**Spec:** 02-cross-module-xp-level-system-design.md
**Complexity:** M | **Estimated effort:** 3 days
**Dependencies:** Achievements engine event stream (`AchievementEngine.events`), dashboard

---

## Overview

A unified XP total across all three modules with a deterministic level curve. XP is awarded on meaningful completions (actions, day-completion, streak milestones) via the achievements engine's existing event stream. Level is derived from total XP at read time, not persisted.

---

## Implementation Tasks

### Task 1: XP Ledger Drift Table

**Files to create/modify:**
- `lib/core/database/tables/xp_ledger_table.dart` (create)
- `lib/core/database/tables/xp_balance_table.dart` (create)
- `lib/core/database/app_database.dart` (modify)

**Drift table definitions:**
```dart
@DataClassName('XpLedgerRow')
class XpLedgerTable extends Table {
  @override
  String get tableName => 'xp_ledger';

  TextColumn get id => text()();
  TextColumn get moduleId => text()();
  TextColumn get eventType => text()();   // 'action' | 'day_complete' | 'streak_milestone'
  IntColumn get xpAmount => integer()();
  TextColumn get sourceId => text().nullable()(); // dose_id, prayer_record_id, etc.
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('XpBalanceRow')
class XpBalanceTable extends Table {
  @override
  String get tableName => 'xp_balance';

  TextColumn get id => text()();
  IntColumn get totalXp => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Database migration:** Add `if (from < 19)` in `app_database.dart` with `m.createTable(xpLedgerTable)` and `m.createTable(xpBalanceTable)`. Seed singleton row in `xp_balance` with `id: 'singleton', totalXp: 0`. Bump `schemaVersion` to 19.

---

### Task 2: XP Repository

**Files to create:**
- `lib/core/gamification/xp_repository.dart`

**Classes/methods:**
```dart
class XpRepository {
  XpRepository(this._db);
  final AppDatabase _db;

  /// Awards XP: inserts ledger row and increments balance atomically.
  Future<void> awardXp({
    required String moduleId,
    required String eventType,
    required int amount,
    String? sourceId,
    required DateTime now,
  });

  /// Returns current total XP (singleton row).
  Future<int> totalXp();

  /// Stream of total XP for reactive UI.
  Stream<int> watchTotalXp();

  /// Ledger history (for XP breakdown screen).
  Future<List<XpLedgerRow>> recentLedger({int limit = 50});
}
```

**Integration:** Uses `generateId()` for ledger row IDs. Balance row always has `id: 'singleton'`.

---

### Task 3: Level Curve Formula

**Files to create:**
- `lib/core/gamification/level_curve.dart`

```dart
/// Quadratic level curve: each level requires more XP than the last.
/// Level 1 = 0 XP, Level 2 = 100 XP, Level 3 = 300 XP, etc.
/// Formula: threshold(level) = 100 * level * (level - 1) / 2
class LevelCurve {
  /// Returns the level for the given total XP.
  static int levelForXp(int totalXp);

  /// Returns the XP threshold for the given level.
  static int thresholdForLevel(int level);

  /// Returns XP progress within the current level.
  /// [0, nextThreshold - currentThreshold).
  static int xpInCurrentLevel(int totalXp);

  /// Returns XP needed for next level.
  static int xpToNextLevel(int totalXp);
}
```

**Level values (recommended):**
| Level | Total XP Required |
|---|---|
| 1 | 0 |
| 2 | 100 |
| 3 | 300 |
| 4 | 600 |
| 5 | 1,000 |
| ... | `100 * L * (L-1) / 2` |

---

### Task 4: XP Values Per Action Type

**Files to create:**
- `lib/core/gamification/xp_values.dart`

```dart
/// XP awarded per action type per module.
/// Designed so all three modules contribute roughly equally over a week.
class XpValues {
  // Water: ~3 actions/day (quick-add, full log) × 7 = 21 actions/week
  static const waterAction = 5;       // per water log entry
  static const waterDayComplete = 15; // full day goal met

  // Medicine: ~2-4 doses/day × 7 = 14-28 doses/week
  static const medicineAction = 3;    // per dose marked done
  static const medicineDayComplete = 10; // all doses taken in a day

  // Prayer: 5 prayers/day × 7 = 35 prayers/week
  static const prayerAction = 2;      // per prayer checked off
  static const prayerDayComplete = 10; // all 5 prayers done

  // Universal bonuses
  static const streakMilestone = 25;  // any streak-length achievement unlock
  static const comboBonus = 30;       // all modules complete same day (Spec 06)
  static const weeklyQuestComplete = 50; // quest completed (Spec 04)
  static const bossCleared = 100;     // boss challenge cleared (Spec 09)

  /// Returns XP for a given module + event type.
  static int forEvent(String moduleId, String eventType);
}
```

---

### Task 5: XP Award Listener (Achievement Engine Integration)

**Files to create:**
- `lib/core/gamification/xp_award_listener.dart`

**Integration with achievement engine:**
```dart
class XpAwardListener {
  XpAwardListener({
    required this.achievementEngine,
    required this.xpRepository,
    required this.modules,
  });

  final AchievementEngine achievementEngine;
  final XpRepository xpRepository;
  final List<HabitModule> modules;

  /// Subscribes to achievementEngine.events and awards XP for qualifying events.
  StreamSubscription<AchievementEvent> listen() {
    return achievementEngine.events.listen((event) {
      if (event.justUnlocked && isStreakMilestoneKey(event.key)) {
        xpRepository.awardXp(
          moduleId: event.moduleId,
          eventType: 'streak_milestone',
          amount: XpValues.streakMilestone,
          sourceId: event.key,
          now: clock.now(),
        );
      }
    });
  }
}
```

**Module write-path integration:**
Each module's controller must also call `xpRepository.awardXp()` directly after a successful write:
- Water controller: after `LogWaterEntryUseCase` → award `waterAction`
- Medicine controller: after dose marked done → award `medicineAction`
- Prayer controller: after prayer checked → award `prayerAction`
- Day-completion detection (in `dayStatus` or a post-write hook): award `*DayComplete`

**Riverpod provider:**
```dart
@riverpod
XpAwardListener xpAwardListener(Ref ref) { ... }
```

---

### Task 6: Dashboard Level/XP Display

**Files to create/modify:**
- `lib/features/dashboard/presentation/widgets/xp_level_display.dart` (create)
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` (modify)

**New widget:**
```dart
class XpLevelDisplay extends ConsumerWidget {
  /// Compact level/XP progress widget for the dashboard.
  /// Shows: "Level {level}" text + LinearProgressIndicator toward next level.
}
```

**Dashboard integration:**
Insert `XpLevelDisplay` between `_DayCompletionIndicator` and `_UpcomingStrip` in `DashboardScreen`:
```dart
const XpLevelDisplay(),
const SizedBox(height: 16),
```

---

### Task 7: Level-Up Celebration

**Files to create:**
- `lib/core/gamification/level_up_celebration.dart`

**Widget:**
```dart
Future<void> showLevelUpCelebration(BuildContext context, {
  required int newLevel,
  required int xpGained,
});
```

**Integration:** The `XpRepository` or `XpAwardListener` detects a level-up (comparing level before/after award) and triggers the celebration dialog/animation.

---

### Task 8: XP Toast on Action

**Files to create:**
- `lib/core/gamification/xp_toast.dart`

```dart
void showXpGainToast(BuildContext context, {required int amount});
```

**Integration:** Called from each module's controller after `xpRepository.awardXp()` to show "+{amount} XP" toast.

---

### Task 9: Localization

**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**ARB keys:**
```
"xpGainToast": "+{amount} XP",
"levelUpTitle": "Level Up!",
"levelUpBody": "You reached Level {level}!",
"levelDisplay": "Level {level}",
"xpProgress": "{current}/{next} XP to next level",
"xpLevelDashboardLabel": "Your Level",
"xpHistoryTitle": "XP History",
"xpHistoryEmpty": "No XP earned yet"
```

---

## Performance Considerations

- **Caching:** `totalXp` singleton row is tiny — a single-row query. Cache in memory via Riverpod `StreamProvider` (reactive to DB writes).
- **Level computation:** Pure math on `totalXp` — no DB query needed after reading the total.
- **Ledger writes:** Append-only, no indexing needed beyond primary key. Old rows can be pruned after 90 days if needed.
- **Memory:** Ledger history is paginated (50 rows at a time).

---

## Testing

**Files to create:**
- `test/core/gamification/xp_repository_test.dart`
- `test/core/gamification/level_curve_test.dart`
- `test/core/gamification/xp_values_test.dart`
- `test/core/gamification/xp_award_listener_test.dart`
- `test/features/dashboard/presentation/widgets/xp_level_display_test.dart`

**Coverage:**
| Test | Covers |
|---|---|
| `xp_repository_test.dart` | XP award, balance increment, ledger insert, stream reactivity |
| `level_curve_test.dart` | Level 1 boundary, level transitions, overflow safety |
| `xp_values_test.dart` | All module/event combinations return expected values |
| `xp_award_listener_test.dart` | Streak milestone events award correct XP, non-milestone events ignored |
| `xp_level_display_test.dart` | Correct level text, progress bar value, zero-XP state |

---

## Edge Cases

- **XP normalization:** Medicine earns less per-dose (3 XP) vs Water per-log (5 XP) because Medicine has more daily actions. Weekly totals roughly equalize.
- **Retroactivity:** XP starts from zero at feature launch. No backfill.
- **Negative XP:** Not supported. Missed days earn 0, never negative.
- **Overflow:** `totalXp` is Dart `int` (64-bit) — no practical overflow risk.
- **XP after level-up display:** Level derived at read time, so no stale-state issue.

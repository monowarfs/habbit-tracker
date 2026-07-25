# Implementation Plan: Weekly "Boss" Milestone Challenge

**Spec:** 09-weekly-boss-milestone-challenge-design.md
**Complexity:** M | **Estimated effort:** 2 days
**Dependencies:** Spec 04 (Weekly Quest Chains) — hard dependency, Spec 02 (XP System) for reward scaling

---

## Overview

A single harder-than-usual weekly challenge per week (the "boss"), mechanically a weekly quest variant with a higher threshold, distinct presentation, and bigger reward. Reuses `weekly_quests` table with an `is_boss` flag.

---

## Implementation Tasks

### Task 1: Add `is_boss` Column to Weekly Quests Table

**Files to modify:**
- `lib/core/database/tables/weekly_quests_table.dart`

**Changes:**
```dart
/// Whether this is a boss challenge (higher threshold, bigger reward).
IntColumn get isBoss => integer().withDefault(const Constant(0))();
```

**Migration:** `if (from < N)` adds the column with default `0`. Existing rows remain non-boss.

---

### Task 2: Boss Quest Definitions

**Files to create:**
- `lib/core/gamification/boss/boss_quest_definitions.dart`

```dart
class BossQuestDefinition {
  const BossQuestDefinition({
    required this.questKey,
    required this.moduleId,
    required this.titleKey,
    required this.descriptionKey,
    required this.target,
    required this.xpReward,
    required this.progressEvaluator,
  });

  final String questKey;
  final String moduleId;
  final String titleKey;
  final String descriptionKey;
  final int target;
  final int xpReward;
  final Future<int> Function() progressEvaluator;
}

/// Boss quest catalog — rotates through modules weekly.
const bossQuestCatalog = [
  BossQuestDefinition(
    questKey: 'boss_water_6_of_7',
    moduleId: 'water',
    titleKey: 'bossQuestWater6of7',
    descriptionKey: 'bossQuestWater6of7Desc',
    target: 6,
    xpReward: 150,
    // progressEvaluator: count days with goal met this week
  ),
  BossQuestDefinition(
    questKey: 'boss_medicine_perfect_week',
    moduleId: 'medicine',
    titleKey: 'bossQuestMedicinePerfect',
    descriptionKey: 'bossQuestMedicinePerfectDesc',
    target: 7,
    xpReward: 150,
    // progressEvaluator: count days with 100% adherence
  ),
  BossQuestDefinition(
    questKey: 'boss_prayer_5_of_5_5days',
    moduleId: 'prayer',
    titleKey: 'bossQuestPrayer5of5',
    descriptionKey: 'bossQuestPrayer5of5Desc',
    target: 5,
    xpReward: 150,
    // progressEvaluator: count days with all 5 prayers
  ),
];
```

---

### Task 3: Boss Rotation Logic

**Files to create:**
- `lib/core/gamification/boss/boss_rotation.dart`

```dart
/// Determines which module gets the boss spotlight this week.
/// Rotates: Water → Medicine → Prayer → repeat.
String bossModuleForWeek(String weekKey) {
  // Use week key hash to determine rotation position
  final hash = weekKey.hashCode;
  final modules = ['water', 'medicine', 'prayer'];
  return modules[hash % modules.length];
}
```

**Integration:** `QuestEngine.generateWeek()` calls `bossModuleForWeek()` to select which module's boss quest to include.

---

### Task 4: Extend Quest Engine for Boss

**Files to modify:**
- `lib/core/gamification/quests/quest_engine.dart`

**Changes:**
```dart
Future<void> generateWeek({required DateTime now}) async {
  // ... existing regular quest generation ...

  // Generate boss quest for the spotlighted module
  final weekKey = weekKeyForDate(localDayKey(now));
  final bossModuleId = bossModuleForWeek(weekKey);
  final bossDef = bossQuestCatalog.firstWhere(
    (b) => b.moduleId == bossModuleId,
  );

  // Insert boss quest with isBoss = 1
  await repository.ensureBossQuest(bossDef, weekKey: weekKey, now: now);
}
```

---

### Task 5: Boss Quest Repository Method

**Files to modify:**
- `lib/core/gamification/quests/quest_repository.dart`

**Add method:**
```dart
/// Ensures the boss quest for the current week exists.
Future<void> ensureBossQuest(
  BossQuestDefinition definition, {
  required String weekKey,
  required DateTime now,
});
```

---

### Task 6: Boss Challenge UI

**Files to create:**
- `lib/features/dashboard/presentation/widgets/boss_challenge_card.dart`

```dart
class BossChallengeCard extends ConsumerWidget {
  /// Shows the current week's boss challenge with:
  /// - "Boss Challenge" header with dramatic styling
  /// - Module spotlight (e.g. "Water Week")
  /// - Progress bar with countdown ("5 days remaining")
  /// - Cleared/failed state with reward info
}
```

**Dashboard integration:** Insert `BossChallengeCard` in `DashboardScreen` after `WeeklyQuestList`.

**Visual treatment:** Distinct from regular quests — uses a darker card background, bold accent color, countdown timer, "BOSS" badge.

---

### Task 7: Boss Cleared Notification

**Files to create:**
- `lib/core/gamification/boss/boss_notification.dart`

```dart
Future<void> sendBossClearedNotification({
  required String moduleName,
  required int xpReward,
});
```

**Integration:** Uses existing `NotificationService` from `lib/core/notifications/notification_service.dart`. Fires when boss quest `progressCurrent >= progressTarget`.

---

### Task 8: Boss Challenge Certificate (Optional)

**Files to modify:**
- `lib/core/gamification/certificate/certificate_generator.dart`

**Changes:**
Add boss-cleared as a certificate-eligible milestone:
```dart
bool qualifiesForBossCertificate(String questKey) {
  return questKey.startsWith('boss_');
}
```

---

### Task 9: Localization

**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**ARB keys:**
```
"bossChallengeTitle": "Boss Challenge",
"bossChallengeModuleWeek": "{module} Week",
"bossChallengeDescription": "Complete {threshold} {module} actions this week!",
"bossChallengeCountdown": "{days} days remaining",
"bossChallengeCleared": "Boss Cleared! +{xp} XP",
"bossChallengeFailed": "Boss escaped... try again next week!",
"bossQuestWater6of7": "Hit water goal 6 of 7 days",
"bossQuestWater6of7Desc": "An intense week of hydration!",
"bossQuestMedicinePerfect": "Perfect adherence all 7 days",
"bossQuestMedicinePerfectDesc": "Every dose, every day!",
"bossQuestPrayer5of5": "All 5 prayers for 5 days",
"bossQuestPrayer5of5Desc": "A week of complete devotion!"
```

---

## Performance Considerations

- **Caching:** Boss quest is a single row per week — trivial query.
- **Lazy loading:** Boss UI loads with the rest of the dashboard's quest list.
- **Memory:** One boss card widget — no additional overhead.

---

## Testing

**Files to create:**
- `test/core/gamification/boss/boss_rotation_test.dart`
- `test/core/gamification/boss/boss_quest_definitions_test.dart`
- `test/features/dashboard/presentation/widgets/boss_challenge_card_test.dart`

**Coverage:**
| Test | Covers |
|---|---|
| `boss_rotation_test.dart` | Rotation cycles through all 3 modules, deterministic by week |
| `boss_quest_definitions_test.dart` | All 3 modules have boss definitions, targets > regular quests |
| `boss_challenge_card_test.dart` | Cleared state, failed state, countdown display |

---

## Edge Cases

- **Boss selection:** Rotates Water → Medicine → Prayer weekly. Deterministic by week key.
- **Difficulty:** Fixed thresholds for v1 (6/7 water, 7/7 medicine adherence, 5/5 prayers 5 days).
- **Boss cleared notification:** Uses existing `NotificationService`.
- **Failed boss:** Expires silently like regular quests. No penalty.
- **Overlap with regular quests:** Boss is an additional quest, not a replacement. Both appear.

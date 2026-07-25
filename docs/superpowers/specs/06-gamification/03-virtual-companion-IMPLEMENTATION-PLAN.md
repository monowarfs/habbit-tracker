# Implementation Plan: Virtual Companion

**Spec:** 03-virtual-companion-design.md
**Complexity:** L | **Estimated effort:** 3 days (+ art asset production)
**Dependencies:** Dashboard day-completion indicator, Lottie animation assets

---

## Overview

An animated creature on the dashboard whose mood reflects recent day-completion history (last 5-7 days). Derived at read time from existing `dayStatus()` data — no new tracking concept. Requires art/animation assets (Lottie) as the dominant cost driver.

---

## Implementation Tasks

### Task 1: Companion Mood State Machine

**Files to create:**
- `lib/core/gamification/companion/companion_mood.dart`

```dart
enum CompanionMood {
  thriving,  // 5-7 of last 7 days complete
  happy,     // 3-4 of last 7 days complete
  neutral,   // 1-2 of last 7 days complete OR < 3 days of data
  worried,   // 0 of last 7 days complete (shown instead of 'sad' for emotional safety)
  sad,       // not used in v1 — 'worried' is the floor
}

/// Derives mood from recent day completion data.
CompanionMood deriveCompanionMood(List<ModuleDayStatus> recentDays) {
  if (recentDays.length < 3) return CompanionMood.neutral;
  final completeCount = recentDays
      .where((d) => d.kind == ModuleDayStatusKind.complete)
      .length;
  return switch (completeCount) {
    >= 5 => CompanionMood.thriving,
    >= 3 => CompanionMood.happy,
    >= 1 => CompanionMood.neutral,
    _ => CompanionMood.worried,
  };
}
```

**Emotional safety:** After 7+ consecutive incomplete days, stay at `worried` — never show `sad`. The companion always looks like it wants to help.

---

### Task 2: Companion Mood Log (Optional)

**Files to create/modify:**
- `lib/core/database/tables/companion_mood_log_table.dart` (create)
- `lib/core/database/app_database.dart` (modify)

**Drift table (optional — for "companion growth" narrative):**
```dart
@DataClassName('CompanionMoodRow')
class CompanionMoodLogTable extends Table {
  @override
  String get tableName => 'companion_mood_log';

  TextColumn get id => text()();
  TextColumn get moodState => text()(); // 'thriving' | 'happy' | 'neutral' | 'worried'
  IntColumn get computedAt => integer()();
  IntColumn get inputDaysComplete => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Migration:** `if (from < 20)` in `app_database.dart`. Bump to 20.

---

### Task 3: Companion Repository

**Files to create:**
- `lib/core/gamification/companion/companion_repository.dart`

```dart
class CompanionRepository {
  CompanionRepository(this._db);
  final AppDatabase _db;

  /// Records a mood state snapshot.
  Future<void> logMood({
    required CompanionMood mood,
    required int daysComplete,
    required DateTime now,
  });

  /// Recent mood history (for growth narrative).
  Future<List<CompanionMoodRow>> recentMoods({int limit = 30});
}
```

---

### Task 4: Companion Provider

**Files to create:**
- `lib/core/gamification/companion/companion_provider.dart`

```dart
@riverpod
Future<CompanionMood> companionMood(Ref ref) async {
  final modules = ref.watch(habitModulesProvider);
  final now = clock.now();
  final today = localDayKey(now);
  final sevenDaysAgo = today.addDays(-6);

  // Query last 7 days of dayStatus from all modules
  final allStatuses = <ModuleDayStatus>[];
  for (final module in modules) {
    final status = await module.dayStatus(
      DateRange(start: sevenDaysAgo, end: today),
    );
    allStatuses.addAll(status.values);
  }

  return deriveCompanionMood(allStatuses);
}
```

**Integration:** Uses existing `HabitModule.dayStatus()` — no new data source.

---

### Task 5: Companion Widget

**Files to create:**
- `lib/features/dashboard/presentation/widgets/virtual_companion.dart`

```dart
class VirtualCompanion extends ConsumerWidget {
  /// Renders the companion based on current mood.
  /// Uses Lottie for animated states, static fallback for Reduce-Motion.
}

class _CompanionAnimator extends StatefulWidget {
  /// Manages Lottie animation transitions between mood states.
  /// Respects MediaQuery.disableAnimations for static fallback.
}
```

**Lottie assets to create (external):**
- `assets/companion/thriving.json` — happy, bouncy animation
- `assets/companion/happy.json` — content animation
- `assets/companion/neutral.json` — idle animation
- `assets/companion/worried.json` — slightly droopy animation

**pubspec.yaml:** Add `lottie` dependency.

**Dashboard integration:** Insert `VirtualCompanion` widget in `DashboardScreen` after `_DayCompletionIndicator`.

---

### Task 6: Reduce-Motion Respect

**Files to modify:**
- `lib/features/dashboard/presentation/widgets/virtual_companion.dart`

**Changes:**
```dart
@override
Widget build(BuildContext context) {
  final reduceMotion = MediaQuery.disableAnimations(context);
  if (reduceMotion) {
    return _StaticCompanionImage(mood: mood);
  }
  return _LottieCompanion(mood: mood);
}
```

---

### Task 7: Accessibility

**Files to modify:**
- `lib/features/dashboard/presentation/widgets/virtual_companion.dart`

**Changes:**
- Wrap companion in `Semantics` widget with label from `companionTapHint` ARB key.
- Each mood state has a distinct semantic label (e.g. "Your companion is thriving").

---

### Task 8: Localization

**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**ARB keys:**
```
"companionName": "Habitree",
"companionStatusThriving": "Thriving",
"companionStatusHappy": "Happy",
"companionStatusNeutral": "Neutral",
"companionStatusWorried": "Needs attention",
"companionTapHint": "Your companion reflects your recent habits",
"companionNoData": "Your companion is waiting to get to know you"
```

---

## Performance Considerations

- **Caching:** Companion mood is derived from `dayStatus()` which already exists. Cache the last computed mood for 5 minutes to avoid re-querying on every scroll.
- **Lazy loading:** Lottie animations are loaded once and cached by the `lottie` package.
- **Memory:** One Lottie controller per mood state — don't load all 4 simultaneously; swap on mood change.

---

## Testing

**Files to create:**
- `test/core/gamification/companion/companion_mood_test.dart`
- `test/core/gamification/companion/companion_repository_test.dart`
- `test/features/dashboard/presentation/widgets/virtual_companion_test.dart`

**Coverage:**
| Test | Covers |
|---|---|
| `companion_mood_test.dart` | Mood derivation for all thresholds, < 3 days of data, emotional safety floor |
| `companion_repository_test.dart` | Mood logging, recent history retrieval |
| `virtual_companion_test.dart` | Correct mood renders, Reduce-Motion fallback, accessibility labels |

---

## Edge Cases

- **No data yet:** Show companion in "neutral" state until at least 3 days of data exist.
- **Emotional safety:** After 7+ consecutive incomplete days, stay at "worried" — never show "sad".
- **Asset format:** Lottie for animated states. Static fallback for Reduce-Motion users.
- **Overlap with Spec 10 (avatar):** Companion is autonomous character; avatar is user-customized self-portrait. Both coexist on dashboard.
- **Asset loading failure:** Fall back to static image if Lottie fails to load.

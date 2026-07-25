# Implementation Plan: Achievement "Almost There" Progress Bars

**Spec:** 11-achievement-almost-there-progress-bars-design.md
**Complexity:** S | **Estimated effort:** 1 day
**Dependencies:** Achievements engine (`AchievementDefinition.currentProgress`), badge gallery UI

---

## Overview

Show unearned achievements in the gallery with a visible progress bar. Progress data comes from the existing `achievements` table's `progress_current`/`progress_target` columns and each definition's `currentProgress` closure. No new DB tables.

---

## Implementation Tasks

### Task 1: Progress Data Source

**Files to modify:**
- `lib/core/achievements/achievement_engine.dart`

**Changes:**
Add a method to evaluate a single achievement's current progress without persisting:
```dart
/// Returns the current progress for a single achievement definition.
/// Used by the gallery to show "almost there" bars.
Future<int> currentProgressFor(AchievementDefinition definition) {
  return definition.currentProgress();
}
```

**Files to modify:**
- `lib/core/achievements/achievement_repository.dart`

**Add method:**
```dart
/// Returns all achievement rows across all modules with progress data.
/// Used by the gallery for progress bar display.
Future<List<AchievementRow>> allWithProgress();
```

This is essentially `watchAll()` but as a one-shot `Future` for the gallery.

---

### Task 2: Progress Bar Widget

**Files to create:**
- `lib/features/achievements/presentation/widgets/achievement_progress_bar.dart`

```dart
class AchievementProgressBar extends StatelessWidget {
  const AchievementProgressBar({
    required this.current,
    required this.target,
    required this.rarity,
  });

  final int current;
  final int target;
  final BadgeRarity rarity;

  @override
  Widget build(BuildContext context) {
    if (target <= 1) return const SizedBox.shrink(); // Binary achievements

    final progress = current / target;
    final isClose = progress >= 0.8;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 4,
          color: isClose
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
        ),
        if (isClose) Text(l10n.achievementAlmostThere),
        Text('${current}/${target}'),
      ],
    );
  }
}
```

---

### Task 3: Enhanced Badge Gallery Card

**Files to modify:**
- `lib/features/achievements/presentation/widgets/badge_card.dart` (or equivalent)

**Changes:**
- For unearned badges: show `AchievementProgressBar` below the badge icon.
- For earned badges: show the existing unlocked treatment.
- Integrate with Spec 05 (rarity tiers) — same card redesign.

```dart
class BadgeCard extends StatelessWidget {
  const BadgeCard({
    required this.definition,
    required this.row, // AchievementRow from DB
  });

  final AchievementDefinition definition;
  final AchievementRow? row;

  @override
  Widget build(BuildContext context) {
    final isUnlocked = row?.unlockedAt != null;
    final current = row?.progressCurrent ?? 0;

    return Card(
      child: Column(
        children: [
          // Badge icon with rarity treatment
          BadgeRarityIndicator(
            rarity: definition.rarity,
            child: BadgeIcon(unlocked: isUnlocked),
          ),
          // Title + description
          Text(definition.titleKey),
          if (!isUnlocked)
            AchievementProgressBar(
              current: current,
              target: definition.target,
              rarity: definition.rarity,
            ),
        ],
      ),
    );
  }
}
```

---

### Task 4: Gallery Sorting by Proximity

**Files to modify:**
- `lib/features/achievements/presentation/screens/` (badge gallery screen)

**Changes:**
- Default sort: unearned achievements by proximity to unlocking (closest first).
- Earned achievements stay in original order at the bottom.

```dart
List<BadgeDisplayItem> _sortedItems(List<AchievementRow> rows) {
  final unlocked = rows.where((r) => r.unlockedAt != null).toList();
  final locked = rows.where((r) => r.unlockedAt == null).toList();

  // Sort locked by proximity (closest to target first)
  locked.sort((a, b) {
    final aProgress = a.progressCurrent / a.progressTarget;
    final bProgress = b.progressCurrent / b.progressTarget;
    return bProgress.compareTo(aProgress); // descending
  });

  return [...locked, ...unlocked];
}
```

---

### Task 5: Progress Caching

**Files to create:**
- `lib/features/achievements/presentation/achievement_progress_cache.dart`

```dart
/// Caches progress evaluation results for 60 seconds to avoid
/// repeated DB queries during gallery scrolling.
class AchievementProgressCache {
  final _cache = <String, _CachedProgress>{};

  int? getCachedProgress(String key);
  void cacheProgress(String key, int current);
  void invalidate(String key);
  void clear();
}

class _CachedProgress {
  _CachedProgress(this.value);
  final int value;
  final DateTime computedAt = clock.now();

  bool get isStale => clock.now().difference(computedAt).inSeconds > 60;
}
```

---

### Task 6: Localization

**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**ARB keys:**
```
"achievementProgress": "{current}/{target}",
"achievementAlmostThere": "Almost there!",
"achievementProgressPercent": "{percent}%",
"achievementNoProgress": "Not yet"
```

---

## Performance Considerations

- **Caching:** Progress values are cached for 60 seconds per achievement key. Avoids re-evaluating `currentProgress()` closures on every scroll frame.
- **Lazy loading:** Gallery already lazy-loads badge cards. Progress bars are lightweight widgets.
- **Memory:** Cache is a simple `Map<String, int>` — negligible overhead.

---

## Testing

**Files to create:**
- `test/features/achievements/presentation/widgets/achievement_progress_bar_test.dart`
- `test/features/achievements/presentation/achievement_progress_cache_test.dart`
- `test/features/achievements/presentation/screens/badge_gallery_sort_test.dart`

**Coverage:**
| Test | Covers |
|---|---|
| `achievement_progress_bar_test.dart` | Progress bar renders, binary achievement hides bar, "Almost there" at 80%+ |
| `achievement_progress_cache_test.dart` | Cache hit, 60s expiry, invalidation |
| `badge_gallery_sort_test.dart` | Unearned sorted by proximity, earned stay in order |

---

## Edge Cases

- **Binary achievements:** If `target <= 1`, no progress bar — show "Not yet / Unlocked" indicator.
- **Progress accuracy:** `currentProgress` closure called on gallery open, cached for 60s.
- **Sorting:** Default sort by proximity to unlocking for unearned. Earned stay at bottom.
- **Pairing with Spec 05:** Progress bars and rarity treatment render on the same card redesign.

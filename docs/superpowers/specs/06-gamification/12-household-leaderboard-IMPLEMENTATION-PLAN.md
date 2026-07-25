# Implementation Plan: Household Leaderboard (Post Multi-Profile)

**Spec:** 12-household-leaderboard-design.md
**Complexity:** M | **Estimated effort:** 2 days
**Dependencies:** Spec 04-premium/03 (Multi-Profile) — hard dependency, Spec 02 (XP/Level) for ranking metric

---

## Overview

A read-only aggregation screen that ranks household members (multiple local profiles on the same device) by a chosen metric. Computed at read time from each profile's existing stats. No new tracking infrastructure — only cross-profile reads and a ranked display. Blocked on multi-profile support.

---

## Implementation Tasks

### Task 1: Leaderboard Ranking Provider

**Files to create:**
- `lib/core/gamification/leaderboard/leaderboard_provider.dart`

**Note:** This depends on multi-profile support existing. The provider queries each profile's data via the `profile_id` column added by Spec 04-premium/03.

```dart
@riverpod
Future<List<LeaderboardEntry>> householdLeaderboard(
  Ref ref, {
  required LeaderboardMetric metric,
}) async {
  final profiles = ref.watch(profilesProvider); // from multi-profile spec
  final entries = <LeaderboardEntry>[];

  for (final profile in profiles) {
    if (profile.leaderboardOptedOut) continue;

    final score = await _computeScore(profile, metric);
    entries.add(LeaderboardEntry(
      profileName: profile.name,
      score: score,
      isCurrentUser: profile.id == currentProfileId,
    ));
  }

  // Sort by score descending
  entries.sort((a, b) => b.score.compareTo(a.score));
  return entries;
}
```

---

### Task 2: Leaderboard Data Model

**Files to create:**
- `lib/core/gamification/leaderboard/leaderboard_entry.dart`

```dart
enum LeaderboardMetric {
  currentStreak,      // longest current streak across modules
  weeklyCompletion,   // % of days with all modules complete this week
  level,              // XP/level from Spec 02
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.profileName,
    required this.score,
    required this.isCurrentUser,
    this.rank = 0,
  });

  final String profileName;
  final num score;
  final bool isCurrentUser;
  final int rank;
}
```

---

### Task 3: Score Computation

**Files to create:**
- `lib/core/gamification/leaderboard/score_computer.dart`

```dart
class ScoreComputer {
  /// Computes the leaderboard score for a profile based on the metric.
  Future<num> computeScore({
    required String profileId,
    required LeaderboardMetric metric,
    required List<HabitModule> modules,
  });

  /// For currentStreak: returns the longest current streak across modules.
  Future<int> _computeStreakScore(String profileId, List<HabitModule> modules);

  /// For weeklyCompletion: returns % of days this week with all modules complete.
  Future<double> _computeWeeklyCompletion(String profileId, List<HabitModule> modules);

  /// For level: returns the XP/level from the profile's xp_balance.
  Future<int> _computeLevelScore(String profileId);
}
```

**Integration:** Uses existing `dayStatus()`, streak calculators, and XP system to compute scores per profile.

---

### Task 4: Leaderboard Screen

**Files to create:**
- `lib/features/leaderboard/presentation/screens/leaderboard_screen.dart`
- `lib/features/leaderboard/presentation/widgets/leaderboard_entry_card.dart`
- `lib/features/leaderboard/presentation/widgets/metric_selector.dart`

```dart
class LeaderboardScreen extends ConsumerWidget {
  /// Shows household leaderboard ranked by selected metric.
  /// Metric selector at top (streak / weekly completion / level).
  /// Each entry shows: rank, name, score, "(You)" for current user.
}

class LeaderboardEntryCard extends StatelessWidget {
  /// Single leaderboard row with rank badge, name, score.
  /// Current user highlighted.
  /// Tied profiles share the same rank number.
}

class MetricSelector extends ConsumerWidget {
  /// Toggle between ranking metrics.
}
```

**Router integration:** Add `/leaderboard` route (accessible from Settings or dashboard).

---

### Task 5: Privacy Opt-Out

**Files to modify:**
- Multi-profile settings screen (from Spec 04-premium/03)

**Changes:**
- Each profile has a `leaderboardOptedOut` boolean setting.
- Opted-out profiles don't appear in the ranking.

**Integration:** Query the profile's opt-out setting before including in leaderboard results.

---

### Task 6: Single-Profile Hidden

**Files to modify:**
- `lib/features/leaderboard/presentation/screens/leaderboard_screen.dart`

**Logic:**
```dart
if (profiles.length < 2) {
  return Center(child: Text(l10n.leaderboardNoData));
}
```

Leaderboard is hidden when only 1 profile exists.

---

### Task 7: Module Overlap Detection

**Files to modify:**
- `lib/core/gamification/leaderboard/score_computer.dart`

**Logic:**
```dart
/// If Parent tracks Water and Child tracks Medicine,
/// compare only modules both profiles use.
/// If no overlap, show "No comparable data."
Future<List<String>> commonModules(String profileA, String profileB);
```

---

### Task 8: Localization

**Files to modify:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_bn.arb`

**ARB keys:**
```
"leaderboardTitle": "Household Leaderboard",
"leaderboardRank": "Rank #{position}",
"leaderboardYouLabel": "(You)",
"leaderboardNoData": "No data yet for {profileName}",
"leaderboardOptOut": "Hide from leaderboard",
"leaderboardSingleProfile": "Add another profile to compare",
"leaderboardNoOverlap": "No comparable data between profiles",
"leaderboardMetricStreak": "Current Streak",
"leaderboardMetricWeekly": "Weekly Completion",
"leaderboardMetricLevel": "Level",
"leaderboardTied": "Tied"
```

---

## Performance Considerations

- **Caching:** Leaderboard is computed on screen open — no background refresh. Cache results for 5 minutes.
- **Lazy loading:** Score computation queries each profile's existing streak/XP data — no new DB tables.
- **Memory:** One leaderboard entry per profile — trivial overhead.

---

## Testing

**Files to create:**
- `test/core/gamification/leaderboard/score_computer_test.dart`
- `test/core/gamification/leaderboard/leaderboard_provider_test.dart`
- `test/features/leaderboard/presentation/screens/leaderboard_screen_test.dart`

**Coverage:**
| Test | Covers |
|---|---|
| `score_computer_test.dart` | All 3 metrics compute correctly, no-overlap detection |
| `leaderboard_provider_test.dart` | Ranking order, opt-out filtering, single-profile hidden |
| `leaderboard_screen_test.dart` | Rank display, tied scores, "(You)" label, metric switching |

---

## Edge Cases

- **Privacy opt-out:** Opted-out profiles don't appear in ranking.
- **Different modules per profile:** Compare only overlapping modules. If no overlap, show "No comparable data."
- **Single profile:** Leaderboard hidden (no one to compare against).
- **Tied scores:** Profiles with same metric value share the rank number.
- **Blocked on multi-profile:** Do not schedule before multi-profile support is planned and scoped.

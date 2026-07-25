# Implementation Plan: Household Shared-Device Leaderboard

**Spec:** `04-household-shared-device-leaderboard-design.md`
**Complexity:** M · **Estimated effort:** 2 days
**Depends on:** Spec 04-premium/03 (multi-profile) — HARD PREREQUISITE

---

## BLOCKED

This spec cannot be implemented until multi-profile support (Spec
04-premium/03) ships. The implementation plan below assumes multi-profile
is already in place with a `profile_id` column on all module tables.

---

## Task 1: Create leaderboard aggregation use case

**File:** `lib/features/community/domain/usecases/leaderboard_use_case.dart`

```dart
class LeaderboardUseCase {
  final AppDatabase db;

  Future<List<LeaderboardEntry>> computeLeaderboard({
    required String metric, // 'streak' | 'completion' | 'xp'
  }) async {
    // 1. Get all profiles from the profiles table
    // 2. For each profile, query their streak/completion data
    // 3. Filter out opted-out profiles
    // 4. Sort by metric value (descending)
    // 5. Assign ranks (handling ties)
    // 6. Return sorted list with rank, profile name, metric value
  }
}
```

Key: the aggregation is a simple sort — no new domain logic, just
reading existing per-profile stats.

---

## Task 2: Create leaderboard entry model

**File:** `lib/features/community/domain/entities/leaderboard_entry.dart`

```dart
@freezed
class LeaderboardEntry with _$LeaderboardEntry {
  const factory LeaderboardEntry({
    required String profileId,
    required String profileName,
    required String avatarColor,
    required int rank,
    required num metricValue,
    required bool isCurrentUser,
  }) = _LeaderboardEntry;
}
```

---

## Task 3: Create leaderboard provider

**File:** `lib/features/community/presentation/providers/leaderboard_provider.dart`

```dart
@riverpod
Future<List<LeaderboardEntry>> leaderboard(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final activeProfile = ref.watch(activeProfileProvider);
  final useCase = LeaderboardUseCase(db);
  final entries = await useCase.computeLeaderboard(metric: 'streak');
  // Mark current user
  return entries.map((e) => e.copyWith(
    isCurrentUser: e.profileId == activeProfile.id,
  )).toList();
}
```

---

## Task 4: Create leaderboard screen

**File:** `lib/features/community/presentation/screens/leaderboard_screen.dart`

A simple ranked list:

```dart
class LeaderboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(leaderboardProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaderboardTitle)),
      body: entries.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => LeaderboardTile(entry: list[index]),
        ),
        loading: () => const CircularProgressIndicator(),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }
}
```

---

## Task 5: Create leaderboard tile widget

**File:** `lib/features/community/presentation/widgets/leaderboard_tile.dart`

```dart
class LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(int.parse(entry.avatarColor.replaceFirst('#', '0xFF'))),
        child: Text('#${entry.rank}'),
      ),
      title: Text('${entry.profileName} ${entry.isCurrentUser ? "(You)" : ""}'),
      trailing: Text('${entry.metricValue}'),
    );
  }
}
```

---

## Task 6: Add leaderboard entry to Dashboard

**File:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

Add a "Leaderboard" card or section below the day-completion indicator.
Only visible when 2+ profiles exist.

---

## Task 7: Add opt-out setting per profile

**File:** `lib/features/settings/presentation/screens/manage_profiles_screen.dart`

Add a "Hide from leaderboard" toggle for each profile in the
"Manage Profiles" screen.

---

## Task 8: Add localization strings

**Files:** `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_bn.arb`

```json
"leaderboardTitle": "Household Leaderboard",
"leaderboardRank": "Rank #{position}",
"leaderboardYouLabel": "(You)",
"leaderboardNoData": "No data yet for {profileName}",
"leaderboardOptOut": "Hide from leaderboard",
"leaderboardNoProfiles": "Add more profiles to compare",
"leaderboardNoOverlap": "No comparable data"
```

Run `flutter gen-l10n`.

---

## Performance considerations

- **Cross-profile query:** for 2-5 profiles, the query is trivial.
  No indexing needed beyond the existing `profile_id` index.
- **Caching:** cache the leaderboard result for 30 seconds to avoid
  recomputing on every scroll. Invalidate on profile switch.

## Testing

- `test/features/community/leaderboard_use_case_test.dart` — unit tests
  for aggregation, sorting, tie handling, opt-out filtering.
- `test/features/community/leaderboard_screen_test.dart` — widget test
  for display with mock data.
- Unit test: single-profile hides leaderboard.
- Unit test: no overlapping modules shows "No comparable data."

## Localization

ARB keys listed in Task 8. The leaderboard is purely numerical — no
complex localization needed.

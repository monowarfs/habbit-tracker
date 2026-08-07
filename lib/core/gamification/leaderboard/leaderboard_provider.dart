import 'package:clock/clock.dart';
import 'package:habit_tracker/core/gamification/leaderboard/leaderboard_entry.dart';
import 'package:habit_tracker/core/gamification/leaderboard/leaderboard_metric.dart';
import 'package:habit_tracker/core/gamification/leaderboard/score_computer.dart';
import 'package:habit_tracker/core/gamification/xp_providers.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/profiles/profile.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'leaderboard_provider.g.dart';

/// Ranks every non-opted-out profile by [metric] (merges `docs/superpowers/
/// specs/05-community/04-household-shared-device-leaderboard-design.md`
/// and `06-gamification/12-household-leaderboard-design.md`).
///
/// Comparable-data profiles are sorted descending and given a competition
/// rank (ties share a rank — 1, 2, 2, 4, never 1, 2, 2, 3). A profile
/// with no data, or whose active modules don't overlap with any other
/// ranked profile's, is appended at the end with `rank: 0` and
/// `hasData: false` — the screen shows "no comparable data" for these
/// instead of a rank/score. [LeaderboardMetric.level] is always
/// comparable (XP is cross-module by construction), so this overlap
/// check only applies to [LeaderboardMetric.currentStreak] and
/// [LeaderboardMetric.weeklyCompletion].
///
/// Single-profile-hidden is the caller's (the screen's) concern, not
/// this provider's — it always returns whatever profiles exist.
@riverpod
Future<List<LeaderboardEntry>> householdLeaderboard(
  Ref ref,
  LeaderboardMetric metric,
) async {
  final allProfiles = await ref.watch(profileListProvider.future);
  final liveProfiles = allProfiles
      .where((p) => !p.leaderboardOptedOut)
      .toList();
  final activeProfile = await ref.watch(activeProfileProvider.future);
  final modules = ref.watch(visibleHabitModulesProvider);
  final xpRepository = ref.watch(xpRepositoryProvider);
  final computer = ScoreComputer(modules: modules, xpRepository: xpRepository);
  final today = localDayKey(clock.now());

  final results = <(Profile, ScoreResult)>[
    for (final profile in liveProfiles)
      (
        profile,
        await computer.computeScore(
          profileId: profile.id,
          metric: metric,
          today: today,
        ),
      ),
  ];

  bool hasComparableData((Profile, ScoreResult) entry) {
    if (metric == LeaderboardMetric.level) return true;
    final mine = entry.$2.activeModuleIds;
    if (mine.isEmpty) return false;
    final othersUnion = <String>{
      for (final other in results)
        if (other.$1.id != entry.$1.id) ...other.$2.activeModuleIds,
    };
    return mine.intersection(othersUnion).isNotEmpty;
  }

  final ranked = results.where(hasComparableData).toList()
    ..sort((a, b) => b.$2.value.compareTo(a.$2.value));

  final entries = <LeaderboardEntry>[];
  int? prevRank;
  num? prevValue;
  for (var i = 0; i < ranked.length; i++) {
    final (profile, result) = ranked[i];
    final rank = (prevValue == result.value) ? prevRank! : i + 1;
    entries.add(
      LeaderboardEntry(
        profileId: profile.id,
        profileName: profile.displayName,
        avatarColor: profile.avatarColor,
        isCurrentUser: profile.id == activeProfile.id,
        rank: rank,
        score: result.value,
        hasData: true,
      ),
    );
    prevRank = rank;
    prevValue = result.value;
  }
  for (final entry in results) {
    if (hasComparableData(entry)) continue;
    final (profile, result) = entry;
    entries.add(
      LeaderboardEntry(
        profileId: profile.id,
        profileName: profile.displayName,
        avatarColor: profile.avatarColor,
        isCurrentUser: profile.id == activeProfile.id,
        rank: 0,
        score: result.value,
        hasData: false,
      ),
    );
  }
  return entries;
}

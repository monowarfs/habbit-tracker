import 'package:freezed_annotation/freezed_annotation.dart';

part 'leaderboard_entry.freezed.dart';

/// One ranked row on the household leaderboard (merges `docs/superpowers/
/// specs/05-community/04-household-shared-device-leaderboard-design.md`
/// and `06-gamification/12-household-leaderboard-design.md`).
@freezed
sealed class LeaderboardEntry with _$LeaderboardEntry {
  /// Creates an entry.
  const factory LeaderboardEntry({
    required String profileId,
    required String profileName,
    required String avatarColor,
    required bool isCurrentUser,

    /// 1-based competition rank; tied scores share a rank (1, 2, 2, 4 —
    /// never 1, 2, 2, 3). `0` when [hasData] is false — there's nothing
    /// to rank.
    required int rank,
    required num score,

    /// False when this profile has no module data comparable to the
    /// rest of the household for the selected metric (either no data at
    /// all, or zero module overlap with every other ranked profile).
    /// The screen shows a "no comparable data" message instead of
    /// [score]/[rank] for these entries.
    required bool hasData,
  }) = _LeaderboardEntry;
}

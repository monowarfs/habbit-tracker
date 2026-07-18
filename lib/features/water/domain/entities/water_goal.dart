import 'package:freezed_annotation/freezed_annotation.dart';

part 'water_goal.freezed.dart';

/// One row of the append-only goal history (`technical/database-design.md`)
/// — a goal change never rewrites a past day's applicable goal (FR-W-04).
@freezed
sealed class WaterGoal with _$WaterGoal {
  /// Creates a water goal entry.
  const factory WaterGoal({
    required String id,
    required int goalMl,
    required DateTime effectiveFrom,
  }) = _WaterGoal;
}

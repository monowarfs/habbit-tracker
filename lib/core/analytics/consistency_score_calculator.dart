import 'package:habit_tracker/core/modules/habit_module.dart';

/// Computes the 0-100 composite "Consistency Score" blending every enabled
/// module's own day-completion status for a single day
/// (`docs/superpowers/specs/08-analytics/05-consistency-score-design.md`).
/// Purely a function of already-computed [ModuleDayStatus] data — nothing
/// is persisted, matching the codebase's treatment of other derived-not-
/// stored status (e.g. Medicine's lazily-derived dose status).
class ConsistencyScoreCalculator {
  /// Calculates a 0-100 composite score from per-module completion.
  static int calculate({
    required Map<String, ModuleDayStatus> moduleStatuses,
    Map<String, double> weights = const {},
  }) {
    if (moduleStatuses.isEmpty) return 0;

    final defaultWeights = {'water': 1.0, 'medicine': 1.5, 'prayer': 1.2};
    final w = weights.isEmpty ? defaultWeights : weights;

    double totalScore = 0;
    double totalWeight = 0;

    for (final entry in moduleStatuses.entries) {
      final moduleWeight = w[entry.key] ?? 1.0;
      final moduleScore = _scoreForStatus(entry.value.kind);
      totalScore += moduleScore * moduleWeight;
      totalWeight += moduleWeight;
    }

    return (totalScore / totalWeight * 100).round().clamp(0, 100);
  }

  static double _scoreForStatus(ModuleDayStatusKind kind) {
    switch (kind) {
      case ModuleDayStatusKind.complete:
        return 1.0;
      case ModuleDayStatusKind.partial:
        return 0.5;
      case ModuleDayStatusKind.missed:
        return 0.0;
      case ModuleDayStatusKind.none:
        return 0.0;
      case ModuleDayStatusKind.paused:
        return 0.0;
    }
  }
}

import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

part 'year_summary.freezed.dart';

/// A complete year's worth of aggregated stats, serialized as JSON
/// and stored in the `recaps` table.
@freezed
sealed class YearSummary with _$YearSummary {
  /// Creates a year summary.
  const factory YearSummary({
    required int yearNumber,
    required LocalDate installDate,
    required int activeDays,
    required List<ModuleYearStats> modules,
  }) = _YearSummary;
}

/// Per-module stats for one year.
@freezed
sealed class ModuleYearStats with _$ModuleYearStats {
  /// Creates module year stats.
  const factory ModuleYearStats({
    required String moduleId,
    required String displayName,
    required int accentColorValue,
    // Water-specific
    int? totalMl,
    double? averageDailyMl,
    int? daysGoalMet,
    // Medicine-specific
    int? totalDoses,
    int? dosesTaken,
    double? adherencePercent,
    int? longestConsecutiveStreak,
    // Prayer-specific
    int? totalPrayers,
    int? prayersCompleted,
    double? onTimePercent,
    int? longestStreak,
    // Shared
    int? longestStreakAll,
    int? bestDayValue,
    // Pause tracking
    int? monthsActive,
    int? monthsTotal,
  }) = _ModuleYearStats;
}

/// Helper to create [ModuleYearStats] from a [Color] accent.
ModuleYearStats moduleYearStatsFromColor({
  required String moduleId,
  required String displayName,
  required Color accentColor,
  int? totalMl,
  double? averageDailyMl,
  int? daysGoalMet,
  int? totalDoses,
  int? dosesTaken,
  double? adherencePercent,
  int? longestConsecutiveStreak,
  int? totalPrayers,
  int? prayersCompleted,
  double? onTimePercent,
  int? longestStreak,
  int? longestStreakAll,
  int? bestDayValue,
  int? monthsActive,
  int? monthsTotal,
}) {
  return ModuleYearStats(
    moduleId: moduleId,
    displayName: displayName,
    accentColorValue: accentColor.toARGB32(),
    totalMl: totalMl,
    averageDailyMl: averageDailyMl,
    daysGoalMet: daysGoalMet,
    totalDoses: totalDoses,
    dosesTaken: dosesTaken,
    adherencePercent: adherencePercent,
    longestConsecutiveStreak: longestConsecutiveStreak,
    totalPrayers: totalPrayers,
    prayersCompleted: prayersCompleted,
    onTimePercent: onTimePercent,
    longestStreak: longestStreak,
    longestStreakAll: longestStreakAll,
    bestDayValue: bestDayValue,
    monthsActive: monthsActive,
    monthsTotal: monthsTotal,
  );
}

/// Extension to get the accent color as a [Color].
extension ModuleYearStatsColor on ModuleYearStats {
  /// The accent color as a [Color].
  Color get accentColor => Color(accentColorValue);
}

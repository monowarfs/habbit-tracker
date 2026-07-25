import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/recaps/recap_repository.dart';
import 'package:habit_tracker/core/recaps/year_summary.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';

/// Generates a yearly recap by aggregating stats from all modules.
class YearRecapGeneratorUseCase {
  /// Creates the generator.
  const YearRecapGeneratorUseCase({
    required this.recapRepository,
    required this.modules,
    required this.settingsRepository,
    required this.db,
  });

  /// Repository for storing and retrieving recaps.
  final RecapRepository recapRepository;

  /// All registered habit modules to aggregate stats from.
  final List<HabitModule> modules;

  /// Settings repository for reading install date and updating recap year.
  final SettingsRepository settingsRepository;

  /// The app's database instance.
  final AppDatabase db;

  /// Generates the recap for [yearNumber]. Returns the stored
  /// [YearSummary] or null if not enough data.
  Future<YearSummary?> execute(
    int yearNumber, {
    required LocalDate today,
  }) async {
    final settings = await settingsRepository.watchSettings().first;
    final installDate = settings.installDate;
    if (installDate == null) return null;

    final installLocal = LocalDate.fromDateTime(installDate.toLocal());
    final yearStart = installLocal.addDays((yearNumber - 1) * 365);
    final yearEnd = yearStart.addDays(364);
    final range = DateRange(start: yearStart, end: yearEnd);

    var totalActiveDays = 0;
    final moduleStats = <ModuleYearStats>[];

    for (final module in modules) {
      final stats = await module.yearAggregation(range);
      if (stats != null) {
        moduleStats.add(stats);
        totalActiveDays += stats.monthsActive ?? 0;
      }
    }

    // At least 3 months of activity across all modules.
    if (totalActiveDays < 3) return null;

    final summary = YearSummary(
      yearNumber: yearNumber,
      installDate: installLocal,
      activeDays: totalActiveDays,
      modules: moduleStats,
    );

    // Serialize summary to JSON manually.
    final summaryJson = jsonEncode({
      'yearNumber': summary.yearNumber,
      'installDate': summary.installDate.toIso(),
      'activeDays': summary.activeDays,
      'modules': summary.modules
          .map(
            (m) => {
              'moduleId': m.moduleId,
              'displayName': m.displayName,
              'accentColorValue': m.accentColorValue,
              if (m.totalMl != null) 'totalMl': m.totalMl,
              if (m.averageDailyMl != null) 'averageDailyMl': m.averageDailyMl,
              if (m.daysGoalMet != null) 'daysGoalMet': m.daysGoalMet,
              if (m.totalDoses != null) 'totalDoses': m.totalDoses,
              if (m.dosesTaken != null) 'dosesTaken': m.dosesTaken,
              if (m.adherencePercent != null)
                'adherencePercent': m.adherencePercent,
              if (m.longestConsecutiveStreak != null)
                'longestConsecutiveStreak': m.longestConsecutiveStreak,
              if (m.totalPrayers != null) 'totalPrayers': m.totalPrayers,
              if (m.prayersCompleted != null)
                'prayersCompleted': m.prayersCompleted,
              if (m.onTimePercent != null) 'onTimePercent': m.onTimePercent,
              if (m.longestStreak != null) 'longestStreak': m.longestStreak,
              if (m.longestStreakAll != null)
                'longestStreakAll': m.longestStreakAll,
              if (m.bestDayValue != null) 'bestDayValue': m.bestDayValue,
              if (m.monthsActive != null) 'monthsActive': m.monthsActive,
              if (m.monthsTotal != null) 'monthsTotal': m.monthsTotal,
            },
          )
          .toList(),
    });

    // Store the recap.
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.recapsTable)
        .insertOnConflictUpdate(
          RecapsTableCompanion.insert(
            id: 'year_$yearNumber',
            yearNumber: yearNumber,
            installYear: installLocal.year,
            generatedAt: now,
            summaryJson: summaryJson,
          ),
        );

    // Update lastRecapYear in settings.
    await settingsRepository.updateLastRecapYear(yearNumber);

    return summary;
  }
}

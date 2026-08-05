import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:habit_tracker/core/backup/drive_backup_table.dart';
import 'package:habit_tracker/core/database/tables/achievements_table.dart';
import 'package:habit_tracker/core/database/tables/app_settings_table.dart';
import 'package:habit_tracker/core/database/tables/avatar_equipped_table.dart';
import 'package:habit_tracker/core/database/tables/cosmetic_unlocks_table.dart';
import 'package:habit_tracker/core/database/tables/habit_stack_suggestions_table.dart';
import 'package:habit_tracker/core/database/tables/module_settings_table.dart';
import 'package:habit_tracker/core/database/tables/notification_ledger_table.dart';
import 'package:habit_tracker/core/database/tables/onboarding_progress_table.dart';
import 'package:habit_tracker/core/database/tables/pause_ranges_table.dart';
import 'package:habit_tracker/core/database/tables/recalibration_markers_table.dart';
import 'package:habit_tracker/core/database/tables/recaps_table.dart';
import 'package:habit_tracker/core/database/tables/weekly_quests_table.dart';
import 'package:habit_tracker/core/premium/entitlement_table.dart';
import 'package:habit_tracker/features/blood_pressure/data/tables/bp_logs_table.dart';
import 'package:habit_tracker/features/exercise/data/tables/exercise_logs_table.dart';
import 'package:habit_tracker/features/medicine/data/tables/medicine_doses_table.dart';
import 'package:habit_tracker/features/medicine/data/tables/medicine_schedules_table.dart';
import 'package:habit_tracker/features/medicine/data/tables/medicine_stock_events_table.dart';
import 'package:habit_tracker/features/medicine/data/tables/medicines_table.dart';
import 'package:habit_tracker/features/mood/data/tables/mood_logs_table.dart';
import 'package:habit_tracker/features/prayer/data/tables/prayer_qadha_counters_table.dart';
import 'package:habit_tracker/features/prayer/data/tables/prayer_records_table.dart';
import 'package:habit_tracker/features/prayer/data/tables/prayer_settings_table.dart';
import 'package:habit_tracker/features/sleep/data/tables/sleep_logs_table.dart';
import 'package:habit_tracker/features/water/data/tables/water_goals_table.dart';
import 'package:habit_tracker/features/water/data/tables/water_logs_table.dart';
import 'package:habit_tracker/features/water/data/tables/water_settings_table.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// The app's single Drift database.
///
/// Drift requires every table, from every module, to be listed in this one
/// `@DriftDatabase(tables: [...])` annotation — unlike the `HabitModule`
/// registry, this is a Drift code-generation constraint, not a design
/// choice. Each module run adds exactly one line here (its own table
/// classes) and nothing else in `core/database/`
/// (`../technical/database-design.md`).
@DriftDatabase(
  tables: [
    AppSettingsTable,
    NotificationLedgerTable,
    AchievementsTable,
    HabitStackSuggestionsTable,
    WaterGoalsTable,
    WaterLogsTable,
    WaterSettingsTable,
    MedicinesTable,
    MedicineSchedulesTable,
    MedicineDosesTable,
    MedicineStockEventsTable,
    PrayerSettingsTable,
    PrayerRecordsTable,
    PrayerQadhaCountersTable,
    RecapsTable,
    PauseRangesTable,
    RecalibrationMarkersTable,
    ModuleSettingsTable,
    OnboardingProgressTable,
    CosmeticUnlocksTable,
    DriveBackupsTable,
    PremiumEntitlements,
    AvatarEquippedTable,
    SleepLogsTable,
    BpLogsTable,
    MoodLogsTable,
    ExerciseLogsTable,
    WeeklyQuestsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the real on-disk database, or wraps [executor] (tests pass an
  /// in-memory or temp-file executor here instead).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 27;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Medicine + Prayer tables added after the initial release.
        await m.createTable(medicinesTable);
        await m.createTable(medicineSchedulesTable);
        await m.createTable(medicineDosesTable);
        await m.createTable(medicineStockEventsTable);
        await m.createTable(prayerSettingsTable);
        await m.createTable(prayerRecordsTable);
        await m.createTable(prayerQadhaCountersTable);
      }
      if (from < 3) {
        // Biometric-unlock and screen-privacy toggles.
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.biometricEnabled,
        );
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.screenPrivacyEnabled,
        );
      }
      if (from < 4) {
        // Free-text notes on log entries (water logs, medicine doses,
        // prayer records).
        await m.addColumn(waterLogsTable, waterLogsTable.notes);
        await m.addColumn(medicineDosesTable, medicineDosesTable.notes);
        await m.addColumn(prayerRecordsTable, prayerRecordsTable.notes);
      }
      if (from < 5) {
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.lastSeenAppVersion,
        );
      }
      if (from < 6) {
        // Quiet-hours-aware notification scheduling.
        await m.addColumn(appSettingsTable, appSettingsTable.quietHoursEnabled);
        await m.addColumn(appSettingsTable, appSettingsTable.quietHoursStart);
        await m.addColumn(appSettingsTable, appSettingsTable.quietHoursEnd);
      }
      if (from < 7) {
        // Per-weekday water reminder window overrides.
        await m.addColumn(
          waterSettingsTable,
          waterSettingsTable.reminderWindowOverrides,
        );
      }
      if (from < 8) {
        // Dashboard greeting's optional display name.
        await m.addColumn(appSettingsTable, appSettingsTable.displayName);
        // Optional dose-done completion chime, off by default.
        await m.addColumn(appSettingsTable, appSettingsTable.soundEnabled);

        // Seasonal theme accent opt-out.
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.seasonalAccentsEnabled,
        );

        // "Why this matters" micro-education card dismissal flags.
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.waterHydrationHintSeenAt,
        );
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.prayerQadhaHintSeenAt,
        );

        // Ramadan mode (`docs/superpowers/specs/02-delightful/
        // 01-ramadan-mode-design.md`).
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.ramadanModeManualOverride,
        );
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.ramadanAutoDetectEnabled,
        );

        // Habit-stacking suggestions (medicine/prayer -> water).
        await m.createTable(habitStackSuggestionsTable);

        // Weather-aware water reminder copy (`docs/superpowers/specs/
        // 02-delightful/07-weather-aware-water-nudge-copy-design.md`).
        await m.addColumn(
          waterSettingsTable,
          waterSettingsTable.weatherNudgeEnabled,
        );
        await m.addColumn(
          waterSettingsTable,
          waterSettingsTable.lastWeatherTemperatureCelsius,
        );
        await m.addColumn(
          waterSettingsTable,
          waterSettingsTable.lastWeatherFetchedAtMillis,
        );
      }
      if (from < 9) {
        // Adaptive reminder timing opt-in (`docs/superpowers/plans/
        // ai-powered/01-adaptive-reminder-timing-impl-plan.md`).
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.adaptiveReminderEnabled,
        );
        await m.addColumn(
          notificationLedgerTable,
          notificationLedgerTable.originalScheduledFor,
        );
      }
      if (from < 10) {
        // installDate + lastRecapYear + lastActivityAt + nudgeSentAfter
        // + recapEnabled for retention features (Specs 01, 02).
        await m.addColumn(appSettingsTable, appSettingsTable.installDate);
        await m.addColumn(appSettingsTable, appSettingsTable.lastRecapYear);
        await m.addColumn(appSettingsTable, appSettingsTable.lastActivityAt);
        await m.addColumn(appSettingsTable, appSettingsTable.nudgeSentAfter);
        await m.addColumn(appSettingsTable, appSettingsTable.recapEnabled);

        // Recaps table for yearly wrapped summaries.
        await m.createTable(recapsTable);

        // Seed installDate for existing installs: reuse createdAt as best
        // proxy for actual install time.
        await customUpdate(
          'UPDATE app_settings SET install_date = created_at '
          'WHERE install_date IS NULL',
        );
      }
      if (from < 11) {
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.reengagementNudgeEnabled,
        );
      }
      if (from < 12) {
        await m.addColumn(
          waterGoalsTable,
          waterGoalsTable.archivedAt,
        );
      }
      if (from < 13) {
        await m.createTable(pauseRangesTable);
      }
      if (from < 14) {
        await m.createTable(recalibrationMarkersTable);
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.recalibrationPromptsEnabled,
        );
      }
      if (from < 15) {
        await m.addColumn(
          achievementsTable,
          achievementsTable.milestoneValue,
        );
      }
      if (from < 16) {
        await m.createTable(moduleSettingsTable);
        await m.createTable(onboardingProgressTable);
        // Seed Water as enabled by default (backward-compatible).
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        await into(moduleSettingsTable).insert(
          ModuleSettingsTableCompanion.insert(
            moduleId: 'water',
            createdAt: now,
            updatedAt: now,
          ),
        );
        // Mark onboarding as completed for existing users.
        await into(onboardingProgressTable).insert(
          OnboardingProgressTableCompanion.insert(
            id: 'singleton',
            completedAt: Value(now),
          ),
        );
      }
      if (from < 17) {
        await m.createTable(cosmeticUnlocksTable);
      }
      if (from < 18) {
        await m.createTable(driveBackupsTable);
      }
      if (from < 19) {
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.driveBackupReminderEnabled,
        );
      }
      if (from < 20) {
        await m.createTable(premiumEntitlements);
      }
      if (from < 21) {
        await m.addColumn(appSettingsTable, appSettingsTable.activePaletteId);
        await m.addColumn(appSettingsTable, appSettingsTable.activeIconPackId);
      }
      if (from < 22) {
        await m.addColumn(cosmeticUnlocksTable, cosmeticUnlocksTable.slot);
        await m.createTable(avatarEquippedTable);
      }
      if (from < 23) {
        await m.createTable(sleepLogsTable);
      }
      if (from < 24) {
        await m.createTable(bpLogsTable);
      }
      if (from < 25) {
        await m.createTable(exerciseLogsTable);
      }
      if (from < 26) {
        await m.createTable(moodLogsTable);
      }
      if (from < 27) {
        await m.createTable(weeklyQuestsTable);
      }
      // Seam: when schemaVersion increments further, add
      // `if (from < N) ...` blocks here — no other file needs to
      // change for a schema migration.
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'habit_tracker.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

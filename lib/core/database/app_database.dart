import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:habit_tracker/core/database/tables/achievements_table.dart';
import 'package:habit_tracker/core/database/tables/app_settings_table.dart';
import 'package:habit_tracker/core/database/tables/notification_ledger_table.dart';
import 'package:habit_tracker/features/medicine/data/tables/medicine_doses_table.dart';
import 'package:habit_tracker/features/medicine/data/tables/medicine_schedules_table.dart';
import 'package:habit_tracker/features/medicine/data/tables/medicine_stock_events_table.dart';
import 'package:habit_tracker/features/medicine/data/tables/medicines_table.dart';
import 'package:habit_tracker/features/prayer/data/tables/prayer_qadha_counters_table.dart';
import 'package:habit_tracker/features/prayer/data/tables/prayer_records_table.dart';
import 'package:habit_tracker/features/prayer/data/tables/prayer_settings_table.dart';
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
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the real on-disk database, or wraps [executor] (tests pass an
  /// in-memory or temp-file executor here instead).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

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
        // Manual drag-to-reorder display order for the medicine list.
        await m.addColumn(medicinesTable, medicinesTable.sortOrder);
        // Backfill: preserve today's de-facto order (createdAt ascending)
        // instead of leaving every existing row tied at 0, which would
        // look like a random shuffle to an upgrading user.
        final existing = await (select(
          medicinesTable,
        )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
        for (var i = 0; i < existing.length; i++) {
          await (update(
            medicinesTable,
          )..where((t) => t.id.equals(existing[i].id))).write(
            MedicinesTableCompanion(sortOrder: Value(i)),
          );
        }
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

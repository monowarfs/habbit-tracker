import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/backup/export_orchestrator.dart';
import 'package:habit_tracker/core/backup/import_orchestrator.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/features/medicine/medicine_module.dart';
import 'package:habit_tracker/features/prayer/prayer_module.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/water/water_module.dart';

void main() {
  group('validateImport', () {
    test('rejects malformed JSON', () async {
      final result = await validateImport('{not json');
      expect(result, isA<Failure<ImportPreview>>());
    });

    test('rejects a newer-than-supported schema version', () async {
      final json = jsonEncode({
        'schemaVersion': 999,
        'exportedAt': '2026-06-01T00:00:00.000Z',
        'appVersion': '1.0.0',
        'modules': <String, Object?>{},
        'common': <String, Object?>{},
      });
      final result = await validateImport(json);
      expect(result, isA<Failure<ImportPreview>>());
      final failure = result as Failure<ImportPreview>;
      expect(failure.error, isA<ValidationException>());
    });

    test('rejects a truncated file missing required fields', () async {
      final result = await validateImport(jsonEncode({'schemaVersion': 1}));
      expect(result, isA<Failure<ImportPreview>>());
    });

    test(
      'accepts a well-formed envelope and counts rows per module',
      () async {
        final json = jsonEncode({
          'schemaVersion': 1,
          'exportedAt': '2026-06-01T00:00:00.000Z',
          'appVersion': '1.0.0',
          'modules': {
            'water': {
              'goals': [1],
              'logs': [1, 2],
            },
          },
          'common': <String, Object?>{},
        });
        final result = await validateImport(json);
        expect(result, isA<Success<ImportPreview>>());
        final preview = (result as Success<ImportPreview>).value;
        expect(preview.countsByModule['water'], 3);
      },
    );
  });

  group('applyImport round trip', () {
    test('export -> wipe -> import restores every module exactly', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final modules = buildHabitModules(db);
      final settingsRepository = SettingsRepositoryImpl(db);
      final achievementRepository = AchievementRepository(db);
      final water = modules.whereType<WaterModule>().first;
      final medicine = modules.whereType<MedicineModule>().first;
      final prayer = modules.whereType<PrayerModule>().first;

      await water.importData(
        const ModuleExport({
          'goals': [
            {'goalMl': 2500, 'effectiveFrom': '2026-06-01T00:00:00.000Z'},
          ],
          'logs': [
            {
              'amountMl': 300,
              'loggedAt': '2026-06-01T08:00:00.000Z',
              'source': 'quick',
            },
          ],
        }),
      );
      await _seedMedicine(medicine);
      await _seedPrayer(prayer);

      final beforeWater = (await water.exportData()).payload;
      final beforeMedicine = (await medicine.exportData()).payload;
      final beforePrayer = (await prayer.exportData()).payload;

      final envelope = await buildExport(
        modules: modules,
        settingsRepository: settingsRepository,
        achievementRepository: achievementRepository,
        appVersion: '1.0.0',
      );

      final applied = await applyImport(
        envelope: envelope,
        modules: modules,
        db: db,
        settingsRepository: settingsRepository,
      );
      expect(applied, isA<Success<void>>());

      // Import always generates fresh row ids (every module's existing
      // create/restore convention, never preserving the exported id) —
      // equality here is on content, with `id` fields stripped, not on
      // identity.
      expect(
        _stripIds((await water.exportData()).payload),
        _stripIds(beforeWater),
      );
      expect(
        _stripIds((await medicine.exportData()).payload),
        _stripIds(beforeMedicine),
      );
      expect(
        _stripIds((await prayer.exportData()).payload),
        _stripIds(beforePrayer),
      );
    });

    test('a failed import leaves existing data untouched', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final modules = buildHabitModules(db);
      final settingsRepository = SettingsRepositoryImpl(db);
      final water = modules.whereType<WaterModule>().first;
      await water.importData(
        const ModuleExport({
          'goals': <Object?>[],
          'logs': [
            {
              'amountMl': 500,
              'loggedAt': '2026-06-01T08:00:00.000Z',
              'source': 'quick',
            },
          ],
        }),
      );
      final before = (await water.exportData()).payload;

      final brokenEnvelope = await buildExport(
        modules: modules,
        settingsRepository: settingsRepository,
        achievementRepository: AchievementRepository(db),
        appVersion: '1.0.0',
      );
      brokenEnvelope.modules['water']!['goals'] = [
        {'goalMl': 1000, 'effectiveFrom': 'not-a-date'},
      ];

      final result = await applyImport(
        envelope: brokenEnvelope,
        modules: modules,
        db: db,
        settingsRepository: settingsRepository,
      );
      expect(result, isA<Failure<void>>());
      expect((await water.exportData()).payload, before);
    });
  });
}

/// Recursively strips `id` and any `*Id` reference field (`medicineId`,
/// `scheduleId`, `doseId`) from an export payload — import always
/// generates fresh ids and remaps every reference to match (every
/// module's existing create/restore convention), so a round-trip
/// equality check only makes sense on content, never on identity.
Object? _stripIds(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key != 'id' && !(entry.key as String).endsWith('Id'))
          entry.key: _stripIds(entry.value),
    };
  }
  if (value is List) {
    return value.map(_stripIds).toList();
  }
  return value;
}

Future<void> _seedMedicine(MedicineModule medicine) async {
  await medicine.importData(
    const ModuleExport({
      'medicines': [
        {
          'id': 'seed-med',
          'name': 'Vitamin D',
          'dosageNote': null,
          'stockEnabled': false,
          'stockCount': null,
          'stockThreshold': null,
          'stopWhenStockDepleted': false,
          'consumptionPerDose': 1,
        },
      ],
      'schedules': [
        {
          'id': 'seed-sched',
          'medicineId': 'seed-med',
          'frequencyType': 'fixed_daily',
          'intervalDays': null,
          'weekdaysMask': null,
          'timesOfDay': ['08:00'],
          'startDate': '2026-06-01',
          'endDate': null,
          'graceWindowMinutes': 30,
        },
      ],
      'doses': <Object?>[],
      'stockEvents': <Object?>[],
    }),
  );
}

Future<void> _seedPrayer(PrayerModule prayer) async {
  await prayer.importData(
    const ModuleExport({
      'settings': null,
      'records': [
        {
          'prayerDate': '2026-06-01',
          'prayerName': 'fajr',
          'scheduledFor': '2026-06-01T05:00:00.000Z',
          'status': 'prayed',
          'statusChangedAt': null,
        },
      ],
      'qadhaCounters': [
        {'prayerName': 'dhuhr', 'count': 1},
      ],
    }),
  );
}

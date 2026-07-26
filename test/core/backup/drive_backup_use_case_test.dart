import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/backup/backup_envelope.dart';
import 'package:habit_tracker/core/backup/drive_backup_repository.dart';
import 'package:habit_tracker/core/backup/drive_backup_use_case.dart';
import 'package:habit_tracker/core/backup/google_drive_backup_target.dart';
import 'package:habit_tracker/core/backup/import_orchestrator.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockDriveTarget extends Mock implements GoogleDriveBackupTarget {}

void main() {
  setUpAll(() {
    registerFallbackValue(File('fallback'));
  });

  late AppDatabase db;
  late _MockDriveTarget driveTarget;
  late DriveBackupRepository backupRepository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    driveTarget = _MockDriveTarget();
    backupRepository = DriveBackupRepository(db);
  });

  tearDown(() => db.close());

  group('performBackup', () {
    test('uploads the envelope and records success', () async {
      when(() => driveTarget.upload(any())).thenAnswer((_) async {});

      final result = await performBackup(
        modules: buildHabitModules(db),
        settingsRepository: SettingsRepositoryImpl(db),
        achievementRepository: AchievementRepository(db),
        appVersion: '1.0.0',
        driveTarget: driveTarget,
        backupRepository: backupRepository,
      );

      expect(result, isA<Success<void>>());
      final latest = await backupRepository.latestBackup();
      expect(latest, isNotNull);
      expect(latest!.status, 'success');

      final captured =
          verify(() => driveTarget.upload(captureAny())).captured.single
              as File;
      final uploaded =
          jsonDecode(await captured.readAsString()) as Map<String, dynamic>;
      expect(uploaded['schemaVersion'], BackupEnvelope.currentSchemaVersion);
    });

    test('records failure when the upload throws', () async {
      when(() => driveTarget.upload(any())).thenThrow(Exception('network'));

      final result = await performBackup(
        modules: buildHabitModules(db),
        settingsRepository: SettingsRepositoryImpl(db),
        achievementRepository: AchievementRepository(db),
        appVersion: '1.0.0',
        driveTarget: driveTarget,
        backupRepository: backupRepository,
      );

      expect(result, isA<Failure<void>>());
      final latest = await backupRepository.latestBackup();
      expect(latest, isNull);
    });
  });

  group('previewDriveRestore', () {
    test('fails when Drive has no backup', () async {
      when(() => driveTarget.download()).thenAnswer((_) async => null);

      final result = await previewDriveRestore(driveTarget: driveTarget);

      expect(result, isA<Failure<ImportPreview>>());
    });

    test('validates a downloaded envelope', () async {
      final envelope = BackupEnvelope(
        schemaVersion: BackupEnvelope.currentSchemaVersion,
        exportedAt: DateTime.utc(2026, 7, 26),
        appVersion: '1.0.0',
        modules: const {'water': {}},
        common: const {},
      );
      final file = await File(
        '${Directory.systemTemp.path}/drive_backup_test.json',
      ).writeAsString(jsonEncode(envelope.toJson()));
      when(() => driveTarget.download()).thenAnswer((_) async => file);

      final result = await previewDriveRestore(driveTarget: driveTarget);

      expect(result, isA<Success<ImportPreview>>());
      final preview = (result as Success<ImportPreview>).value;
      expect(preview.envelope.appVersion, '1.0.0');
    });
  });

  group('applyDriveRestore', () {
    test('writes a safety copy and applies the import', () async {
      final modules = buildHabitModules(db);
      final settingsRepository = SettingsRepositoryImpl(db);
      final achievementRepository = AchievementRepository(db);
      final envelope = BackupEnvelope(
        schemaVersion: BackupEnvelope.currentSchemaVersion,
        exportedAt: DateTime.utc(2026, 7, 26),
        appVersion: '1.0.0',
        modules: const {},
        common: const {},
      );
      final validated = await validateImport(jsonEncode(envelope.toJson()));
      final preview = (validated as Success<ImportPreview>).value;

      final result = await applyDriveRestore(
        preview: preview,
        modules: modules,
        db: db,
        settingsRepository: settingsRepository,
        achievementRepository: achievementRepository,
        appVersion: '1.0.0',
      );

      expect(result, isA<Success<void>>());
    });
  });
}

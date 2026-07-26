import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/backup/drive_backup_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late DriveBackupRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriveBackupRepository(db);
  });

  tearDown(() => db.close());

  test('latestBackup returns null when no backups exist', () async {
    expect(await repo.latestBackup(), isNull);
  });

  test('markInProgress then markComplete records a success', () async {
    final id = await repo.markInProgress(
      backupFileName: 'habit_tracker_backup.json',
      schemaVersion: 1,
      backedUpAt: DateTime.utc(2026, 7, 26),
    );
    await repo.markComplete(id, 1234);

    final latest = await repo.latestBackup();
    expect(latest, isNotNull);
    expect(latest!.status, 'success');
    expect(latest.fileSizeBytes, 1234);
  });

  test('markFailed does not surface as latestBackup', () async {
    final id = await repo.markInProgress(
      backupFileName: 'habit_tracker_backup.json',
      schemaVersion: 1,
      backedUpAt: DateTime.utc(2026, 7, 26),
    );
    await repo.markFailed(id);

    expect(await repo.latestBackup(), isNull);
  });

  test('latestBackup returns the most recent success', () async {
    final older = await repo.markInProgress(
      backupFileName: 'older.json',
      schemaVersion: 1,
      backedUpAt: DateTime.utc(2026, 7, 24),
    );
    await repo.markComplete(older, 100);
    final newer = await repo.markInProgress(
      backupFileName: 'newer.json',
      schemaVersion: 1,
      backedUpAt: DateTime.utc(2026, 7, 25),
    );
    await repo.markComplete(newer, 200);

    final latest = await repo.latestBackup();
    expect(latest!.backupFileName, 'newer.json');
  });
}

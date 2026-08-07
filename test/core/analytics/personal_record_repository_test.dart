import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/personal_record_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late PersonalRecordRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PersonalRecordRepository(db);
  });

  tearDown(() => db.close());

  test('getRecord returns null when no record exists', () async {
    expect(
      await repo.getRecord(moduleId: 'water', recordType: 'longest_streak'),
      isNull,
    );
  });

  test('setRecord creates a row when none exists', () async {
    await repo.setRecord(
      moduleId: 'water',
      recordType: 'longest_streak',
      value: 5,
    );
    final record = await repo.getRecord(
      moduleId: 'water',
      recordType: 'longest_streak',
    );
    expect(record, isNotNull);
    expect(record!.recordValue, 5);
  });

  test('setRecord overwrites an existing row for the same key', () async {
    await repo.setRecord(
      moduleId: 'water',
      recordType: 'longest_streak',
      value: 5,
    );
    await repo.setRecord(
      moduleId: 'water',
      recordType: 'longest_streak',
      value: 9,
    );
    final records = await db.select(db.personalRecordsTable).get();
    expect(records, hasLength(1));
    expect(records.single.recordValue, 9);
  });

  test(
    'checkAndUpdate creates the record and returns true when none exists',
    () async {
      final updated = await repo.checkAndUpdate(
        moduleId: 'medicine',
        recordType: 'longest_streak',
        newValue: 3,
      );
      expect(updated, isTrue);
      final record = await repo.getRecord(
        moduleId: 'medicine',
        recordType: 'longest_streak',
      );
      expect(record!.recordValue, 3);
    },
  );

  test('checkAndUpdate returns false and leaves the record untouched when '
      'newValue does not beat it', () async {
    await repo.setRecord(
      moduleId: 'prayer',
      recordType: 'longest_streak',
      value: 10,
    );
    final updated = await repo.checkAndUpdate(
      moduleId: 'prayer',
      recordType: 'longest_streak',
      newValue: 7,
    );
    expect(updated, isFalse);
    final record = await repo.getRecord(
      moduleId: 'prayer',
      recordType: 'longest_streak',
    );
    expect(record!.recordValue, 10);
  });

  test('checkAndUpdate returns false on a tie', () async {
    await repo.setRecord(
      moduleId: 'prayer',
      recordType: 'longest_streak',
      value: 10,
    );
    final updated = await repo.checkAndUpdate(
      moduleId: 'prayer',
      recordType: 'longest_streak',
      newValue: 10,
    );
    expect(updated, isFalse);
  });

  test(
    'checkAndUpdate updates and returns true when newValue beats it',
    () async {
      await repo.setRecord(
        moduleId: 'prayer',
        recordType: 'longest_streak',
        value: 10,
      );
      final updated = await repo.checkAndUpdate(
        moduleId: 'prayer',
        recordType: 'longest_streak',
        newValue: 12,
      );
      expect(updated, isTrue);
      final record = await repo.getRecord(
        moduleId: 'prayer',
        recordType: 'longest_streak',
      );
      expect(record!.recordValue, 12);
    },
  );

  test('records are scoped independently per moduleId/recordType', () async {
    await repo.setRecord(
      moduleId: 'water',
      recordType: 'longest_streak',
      value: 5,
    );
    await repo.setRecord(
      moduleId: 'water',
      recordType: 'best_adherence',
      value: 90,
    );
    await repo.setRecord(
      moduleId: 'medicine',
      recordType: 'longest_streak',
      value: 3,
    );
    expect(
      (await repo.getRecord(
        moduleId: 'water',
        recordType: 'longest_streak',
      ))!.recordValue,
      5,
    );
    expect(
      (await repo.getRecord(
        moduleId: 'water',
        recordType: 'best_adherence',
      ))!.recordValue,
      90,
    );
    expect(
      (await repo.getRecord(
        moduleId: 'medicine',
        recordType: 'longest_streak',
      ))!.recordValue,
      3,
    );
  });
}

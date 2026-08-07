import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/personal_record_repository.dart';
import 'package:habit_tracker/core/analytics/record_detection_use_case.dart';
import 'package:habit_tracker/core/database/app_database.dart';

const _profileId = 'system';

void main() {
  late AppDatabase db;
  late RecordDetectionUseCase useCase;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    useCase = RecordDetectionUseCase(repo: PersonalRecordRepository(db));
  });

  tearDown(() => db.close());

  test('checkRecord returns an event and persists on a new record', () async {
    final event = await useCase.checkRecord(
      profileId: _profileId,
      moduleId: 'water',
      recordType: 'longest_streak',
      currentValue: 14,
    );
    expect(event, isNotNull);
    expect(event!.moduleId, 'water');
    expect(event.recordType, 'longest_streak');
    expect(event.newValue, 14);
  });

  test(
    'checkRecord returns null when the value does not beat the record',
    () async {
      await useCase.checkRecord(
        profileId: _profileId,
        moduleId: 'water',
        recordType: 'longest_streak',
        currentValue: 14,
      );
      final event = await useCase.checkRecord(
        profileId: _profileId,
        moduleId: 'water',
        recordType: 'longest_streak',
        currentValue: 10,
      );
      expect(event, isNull);
    },
  );

  test(
    'checkRecord returns an event again when a later value beats it',
    () async {
      await useCase.checkRecord(
        profileId: _profileId,
        moduleId: 'water',
        recordType: 'longest_streak',
        currentValue: 14,
      );
      final event = await useCase.checkRecord(
        profileId: _profileId,
        moduleId: 'water',
        recordType: 'longest_streak',
        currentValue: 20,
      );
      expect(event, isNotNull);
      expect(event!.newValue, 20);
    },
  );
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/personal_record_repository.dart';
import 'package:habit_tracker/core/analytics/record_detection_use_case.dart';
import 'package:habit_tracker/core/analytics/record_integration.dart';
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

  test('checkRecordsAfterStreak returns an event for a new record', () async {
    final event = await checkRecordsAfterStreak(
      profileId: _profileId,
      recordDetectionUseCase: useCase,
      moduleId: 'medicine',
      currentStreak: 30,
    );
    expect(event, isNotNull);
    expect(event!.moduleId, 'medicine');
    expect(event.recordType, 'longest_streak');
    expect(event.newValue, 30);
  });

  test('checkRecordsAfterStreak returns null when the streak does not beat '
      'the persisted record', () async {
    await checkRecordsAfterStreak(
      profileId: _profileId,
      recordDetectionUseCase: useCase,
      moduleId: 'medicine',
      currentStreak: 30,
    );
    final event = await checkRecordsAfterStreak(
      profileId: _profileId,
      recordDetectionUseCase: useCase,
      moduleId: 'medicine',
      currentStreak: 12,
    );
    expect(event, isNull);
  });
}

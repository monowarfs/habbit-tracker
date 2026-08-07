import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/blood_pressure/data/repositories/bp_repository_impl.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_classification.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_log.dart';

void main() {
  late AppDatabase db;
  late BpRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = BpRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('addLog classifies and round-trips through allLogs', () async {
    final result = await repository.addLog(
      systolic: 150,
      diastolic: 70,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
      profileId: 'system',
    );
    final log = (result as Success<BpLog>).value;
    expect(log.classification, BpClassification.hypertension2);

    final logs = await repository.allLogs(profileId: 'system');
    expect(logs, hasLength(1));
    expect(logs.first.classification, BpClassification.hypertension2);
  });

  test('watchLogsForDay finds a reading by its logged day', () async {
    await repository.addLog(
      systolic: 118,
      diastolic: 76,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
      profileId: 'system',
    );

    final logs = await repository
        .watchLogsForDay(const LocalDate(2026, 6, 15), profileId: 'system')
        .first;
    expect(logs, hasLength(1));

    final emptyDay = await repository
        .watchLogsForDay(const LocalDate(2026, 6, 14), profileId: 'system')
        .first;
    expect(emptyDay, isEmpty);
  });

  test('deleteLog soft-deletes so it no longer appears in reads', () async {
    final added = await repository.addLog(
      systolic: 118,
      diastolic: 76,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
      profileId: 'system',
    );
    final id = (added as Success<BpLog>).value.id;

    final deleteResult = await repository.deleteLog(id, profileId: 'system');
    expect(deleteResult, isA<Success<void>>());

    expect(await repository.logById(id, profileId: 'system'), isNull);
    expect(await repository.allLogs(profileId: 'system'), isEmpty);
  });

  test('deleteLog on an unknown or already-deleted id fails', () async {
    final result = await repository.deleteLog('nope', profileId: 'system');
    expect(result, isA<Failure<void>>());

    final added = await repository.addLog(
      systolic: 118,
      diastolic: 76,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
      profileId: 'system',
    );
    final id = (added as Success<BpLog>).value.id;
    await repository.deleteLog(id, profileId: 'system');
    final secondDelete = await repository.deleteLog(id, profileId: 'system');
    expect(secondDelete, isA<Failure<void>>());
  });

  test('wipeAll removes every reading', () async {
    await repository.addLog(
      systolic: 118,
      diastolic: 76,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
      profileId: 'system',
    );
    await repository.wipeAll(profileId: 'system');
    expect(await repository.allLogs(profileId: 'system'), isEmpty);
  });

  test('BpClassificationDb round-trips every value through toDb/fromDb', () {
    for (final classification in BpClassification.values) {
      expect(
        BpClassificationDb.fromDb(classification.toDb()),
        classification,
      );
    }
  });

  test('BpClassificationDb.fromDb throws on an unrecognized value', () {
    expect(
      () => BpClassificationDb.fromDb('not_a_real_classification'),
      throwsStateError,
    );
  });
}

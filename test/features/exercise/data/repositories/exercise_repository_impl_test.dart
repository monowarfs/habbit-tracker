import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/exercise/data/repositories/exercise_repository_impl.dart';
import 'package:habit_tracker/features/exercise/domain/entities/exercise_log.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = ExerciseRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('addLog round-trips through allLogs', () async {
    final result = await repository.addLog(
      exerciseType: 'Running',
      durationMinutes: 30,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
      calories: 250,
      profileId: 'system',
    );
    final log = (result as Success<ExerciseLog>).value;
    expect(log.exerciseType, 'Running');
    expect(log.calories, 250);

    final logs = await repository.allLogs(profileId: 'system');
    expect(logs, hasLength(1));
    expect(logs.first.durationMinutes, 30);
  });

  test('watchLogsForDay finds a workout by its logged day', () async {
    await repository.addLog(
      exerciseType: 'Yoga',
      durationMinutes: 45,
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
      exerciseType: 'Cycling',
      durationMinutes: 60,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
      profileId: 'system',
    );
    final id = (added as Success<ExerciseLog>).value.id;

    final deleteResult = await repository.deleteLog(id, profileId: 'system');
    expect(deleteResult, isA<Success<void>>());

    expect(await repository.logById(id, profileId: 'system'), isNull);
    expect(await repository.allLogs(profileId: 'system'), isEmpty);
  });

  test('deleteLog on an unknown or already-deleted id fails', () async {
    final result = await repository.deleteLog('nope', profileId: 'system');
    expect(result, isA<Failure<void>>());

    final added = await repository.addLog(
      exerciseType: 'Cycling',
      durationMinutes: 60,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
      profileId: 'system',
    );
    final id = (added as Success<ExerciseLog>).value.id;
    await repository.deleteLog(id, profileId: 'system');
    final secondDelete = await repository.deleteLog(id, profileId: 'system');
    expect(secondDelete, isA<Failure<void>>());
  });

  test('wipeAll removes every workout', () async {
    await repository.addLog(
      exerciseType: 'Cycling',
      durationMinutes: 60,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
      profileId: 'system',
    );
    await repository.wipeAll(profileId: 'system');
    expect(await repository.allLogs(profileId: 'system'), isEmpty);
  });
}

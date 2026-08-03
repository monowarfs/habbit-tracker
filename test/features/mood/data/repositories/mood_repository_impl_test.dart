import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/mood/data/repositories/mood_repository_impl.dart';
import 'package:habit_tracker/features/mood/domain/entities/mood_log.dart';

void main() {
  late AppDatabase db;
  late MoodRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = MoodRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('addLog round-trips through allLogs', () async {
    final result = await repository.addLog(
      moodValue: 4,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
    );
    final log = (result as Success<MoodLog>).value;
    expect(log.moodValue, 4);

    final logs = await repository.allLogs();
    expect(logs, hasLength(1));
    expect(logs.first.moodValue, 4);
  });

  test('watchLogsForDay finds a check-in by its logged day', () async {
    await repository.addLog(
      moodValue: 3,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
    );

    final logs = await repository
        .watchLogsForDay(const LocalDate(2026, 6, 15))
        .first;
    expect(logs, hasLength(1));

    final emptyDay = await repository
        .watchLogsForDay(const LocalDate(2026, 6, 14))
        .first;
    expect(emptyDay, isEmpty);
  });

  test('deleteLog soft-deletes so it no longer appears in reads', () async {
    final added = await repository.addLog(
      moodValue: 3,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
    );
    final id = (added as Success<MoodLog>).value.id;

    final deleteResult = await repository.deleteLog(id);
    expect(deleteResult, isA<Success<void>>());

    expect(await repository.logById(id), isNull);
    expect(await repository.allLogs(), isEmpty);
  });

  test('deleteLog on an unknown or already-deleted id fails', () async {
    final result = await repository.deleteLog('nope');
    expect(result, isA<Failure<void>>());

    final added = await repository.addLog(
      moodValue: 3,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
    );
    final id = (added as Success<MoodLog>).value.id;
    await repository.deleteLog(id);
    final secondDelete = await repository.deleteLog(id);
    expect(secondDelete, isA<Failure<void>>());
  });

  test('wipeAll removes every check-in', () async {
    await repository.addLog(
      moodValue: 3,
      loggedAt: DateTime.utc(2026, 6, 15, 8),
    );
    await repository.wipeAll();
    expect(await repository.allLogs(), isEmpty);
  });
}

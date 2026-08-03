import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/sleep/data/repositories/sleep_repository_impl.dart';
import 'package:habit_tracker/features/sleep/domain/entities/sleep_log.dart';

void main() {
  late AppDatabase db;
  late SleepRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = SleepRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('addLog computes duration and round-trips through allLogs', () async {
    final result = await repository.addLog(
      bedTime: DateTime.utc(2026, 6, 14, 22),
      wakeTime: DateTime.utc(2026, 6, 15, 6, 30),
    );
    final log = (result as Success<SleepLog>).value;
    expect(log.durationMinutes, 8 * 60 + 30);

    final logs = await repository.allLogs();
    expect(logs, hasLength(1));
    expect(logs.first.durationMinutes, 8 * 60 + 30);
  });

  test('watchLogsForDay finds a log by its wake day', () async {
    await repository.addLog(
      bedTime: DateTime.utc(2026, 6, 14, 22),
      wakeTime: DateTime.utc(2026, 6, 15, 6),
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
      bedTime: DateTime.utc(2026, 6, 14, 22),
      wakeTime: DateTime.utc(2026, 6, 15, 6),
    );
    final id = (added as Success<SleepLog>).value.id;

    final deleteResult = await repository.deleteLog(id);
    expect(deleteResult, isA<Success<void>>());

    expect(await repository.logById(id), isNull);
    expect(await repository.allLogs(), isEmpty);
  });

  test('deleteLog on an unknown id fails', () async {
    final result = await repository.deleteLog('nope');
    expect(result, isA<Failure<void>>());
  });

  test('wipeAll removes every log', () async {
    await repository.addLog(
      bedTime: DateTime.utc(2026, 6, 14, 22),
      wakeTime: DateTime.utc(2026, 6, 15, 6),
    );
    await repository.wipeAll();
    expect(await repository.allLogs(), isEmpty);
  });
}

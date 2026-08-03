import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/sleep/domain/entities/sleep_log.dart';
import 'package:habit_tracker/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:habit_tracker/features/sleep/domain/usecases/log_sleep_use_case.dart';

class _FakeSleepRepository implements SleepRepository {
  DateTime? capturedBedTime;
  DateTime? capturedWakeTime;

  @override
  Future<Result<SleepLog>> addLog({
    required DateTime bedTime,
    required DateTime wakeTime,
    int? quality,
    String? notes,
  }) async {
    capturedBedTime = bedTime;
    capturedWakeTime = wakeTime;
    return Result.success(
      SleepLog(
        id: 'x',
        bedTime: bedTime,
        wakeTime: wakeTime,
        durationMinutes: wakeTime.difference(bedTime).inMinutes,
        quality: quality,
        notes: notes,
      ),
    );
  }

  @override
  Future<List<SleepLog>> allLogs() async => [];

  @override
  Future<Result<void>> deleteLog(String id) async => const Result.success(null);

  @override
  Future<SleepLog?> logById(String id) async => null;

  @override
  Stream<List<SleepLog>> watchLogsForDay(LocalDate day) => const Stream.empty();

  @override
  Stream<List<SleepLog>> watchLogsInRange(LocalDate start, LocalDate end) =>
      const Stream.empty();

  @override
  Future<void> wipeAll() async {}
}

void main() {
  final fixedNow = DateTime.utc(2026, 6, 15, 8);

  test('rejects wakeTime before bedTime', () async {
    final useCase = LogSleepUseCase(_FakeSleepRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(
        bedTime: DateTime.utc(2026, 6, 15),
        wakeTime: DateTime.utc(2026, 6, 14),
      );
    });
    expect(result, isA<Failure<SleepLog>>());
  });

  test('rejects a future wake time', () async {
    final useCase = LogSleepUseCase(_FakeSleepRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(
        bedTime: DateTime.utc(2026, 6, 15),
        wakeTime: DateTime.utc(2026, 6, 16),
      );
    });
    expect(result, isA<Failure<SleepLog>>());
  });

  test('rejects quality outside 1-5', () async {
    final useCase = LogSleepUseCase(_FakeSleepRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(
        bedTime: DateTime.utc(2026, 6, 14, 22),
        wakeTime: DateTime.utc(2026, 6, 15, 6),
        quality: 6,
      );
    });
    expect(result, isA<Failure<SleepLog>>());
  });

  test('logs a valid night and computes duration', () async {
    final repository = _FakeSleepRepository();
    final useCase = LogSleepUseCase(repository);
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(
        bedTime: DateTime.utc(2026, 6, 14, 22),
        wakeTime: DateTime.utc(2026, 6, 15, 6),
        quality: 4,
      );
    });
    expect(result, isA<Success<SleepLog>>());
    final log = (result as Success<SleepLog>).value;
    expect(log.durationMinutes, 8 * 60);
    expect(repository.capturedBedTime, DateTime.utc(2026, 6, 14, 22));
  });
}

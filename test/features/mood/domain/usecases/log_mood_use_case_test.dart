import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/mood/domain/entities/mood_log.dart';
import 'package:habit_tracker/features/mood/domain/repositories/mood_repository.dart';
import 'package:habit_tracker/features/mood/domain/usecases/log_mood_use_case.dart';

class _FakeMoodRepository implements MoodRepository {
  int? capturedMoodValue;

  @override
  Future<Result<MoodLog>> addLog({
    required int moodValue,
    required DateTime loggedAt,
    String? notes,
  }) async {
    capturedMoodValue = moodValue;
    return Result.success(
      MoodLog(id: 'x', moodValue: moodValue, loggedAt: loggedAt, notes: notes),
    );
  }

  @override
  Future<List<MoodLog>> allLogs() async => [];

  @override
  Future<Result<void>> deleteLog(String id) async => const Result.success(null);

  @override
  Future<MoodLog?> logById(String id) async => null;

  @override
  Stream<List<MoodLog>> watchLogsForDay(LocalDate day) => const Stream.empty();

  @override
  Stream<List<MoodLog>> watchLogsInRange(LocalDate start, LocalDate end) =>
      const Stream.empty();

  @override
  Future<void> wipeAll() async {}
}

void main() {
  final fixedNow = DateTime.utc(2026, 6, 15, 8);

  test('rejects a mood value below 1', () async {
    final useCase = LogMoodUseCase(_FakeMoodRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(moodValue: 0);
    });
    expect(result, isA<Failure<MoodLog>>());
  });

  test('rejects a mood value above 5', () async {
    final useCase = LogMoodUseCase(_FakeMoodRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(moodValue: 6);
    });
    expect(result, isA<Failure<MoodLog>>());
  });

  test('rejects a future check-in time', () async {
    final useCase = LogMoodUseCase(_FakeMoodRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(
        moodValue: 3,
        loggedAt: fixedNow.add(const Duration(hours: 1)),
      );
    });
    expect(result, isA<Failure<MoodLog>>());
  });

  test('logs a valid check-in', () async {
    final repository = _FakeMoodRepository();
    final useCase = LogMoodUseCase(repository);
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(moodValue: 4);
    });
    expect(result, isA<Success<MoodLog>>());
    expect(repository.capturedMoodValue, 4);
  });
}

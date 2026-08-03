import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/exercise/domain/entities/exercise_log.dart';
import 'package:habit_tracker/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:habit_tracker/features/exercise/domain/usecases/log_exercise_use_case.dart';

class _FakeExerciseRepository implements ExerciseRepository {
  int? capturedDurationMinutes;

  @override
  Future<Result<ExerciseLog>> addLog({
    required String exerciseType,
    required int durationMinutes,
    required DateTime loggedAt,
    int? calories,
    String? notes,
  }) async {
    capturedDurationMinutes = durationMinutes;
    return Result.success(
      ExerciseLog(
        id: 'x',
        exerciseType: exerciseType,
        durationMinutes: durationMinutes,
        loggedAt: loggedAt,
        calories: calories,
        notes: notes,
      ),
    );
  }

  @override
  Future<List<ExerciseLog>> allLogs() async => [];

  @override
  Future<Result<void>> deleteLog(String id) async => const Result.success(null);

  @override
  Future<ExerciseLog?> logById(String id) async => null;

  @override
  Stream<List<ExerciseLog>> watchLogsForDay(LocalDate day) =>
      const Stream.empty();

  @override
  Stream<List<ExerciseLog>> watchLogsInRange(LocalDate start, LocalDate end) =>
      const Stream.empty();

  @override
  Future<void> wipeAll() async {}
}

void main() {
  final fixedNow = DateTime.utc(2026, 6, 15, 8);

  test('rejects an empty exercise type', () async {
    final useCase = LogExerciseUseCase(_FakeExerciseRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(exerciseType: '   ', durationMinutes: 30);
    });
    expect(result, isA<Failure<ExerciseLog>>());
  });

  test('rejects a zero or negative duration', () async {
    final useCase = LogExerciseUseCase(_FakeExerciseRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(exerciseType: 'Running', durationMinutes: 0);
    });
    expect(result, isA<Failure<ExerciseLog>>());
  });

  test('rejects a duration over 24 hours', () async {
    final useCase = LogExerciseUseCase(_FakeExerciseRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(exerciseType: 'Running', durationMinutes: 1441);
    });
    expect(result, isA<Failure<ExerciseLog>>());
  });

  test('rejects out-of-range calories', () async {
    final useCase = LogExerciseUseCase(_FakeExerciseRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(
        exerciseType: 'Running',
        durationMinutes: 30,
        calories: -5,
      );
    });
    expect(result, isA<Failure<ExerciseLog>>());
  });

  test('rejects a future workout time', () async {
    final useCase = LogExerciseUseCase(_FakeExerciseRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(
        exerciseType: 'Running',
        durationMinutes: 30,
        loggedAt: fixedNow.add(const Duration(hours: 1)),
      );
    });
    expect(result, isA<Failure<ExerciseLog>>());
  });

  test('logs a valid workout', () async {
    final repository = _FakeExerciseRepository();
    final useCase = LogExerciseUseCase(repository);
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(exerciseType: 'Cycling', durationMinutes: 45);
    });
    expect(result, isA<Success<ExerciseLog>>());
    expect(repository.capturedDurationMinutes, 45);
  });
}

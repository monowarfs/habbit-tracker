import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_classification.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_log.dart';
import 'package:habit_tracker/features/blood_pressure/domain/repositories/bp_repository.dart';
import 'package:habit_tracker/features/blood_pressure/domain/usecases/log_bp_use_case.dart';

class _FakeBpRepository implements BpRepository {
  int? capturedSystolic;

  @override
  Future<Result<BpLog>> addLog({
    required int systolic,
    required int diastolic,
    required DateTime loggedAt,
    int? pulse,
    String? notes,
  }) async {
    capturedSystolic = systolic;
    return Result.success(
      BpLog(
        id: 'x',
        systolic: systolic,
        diastolic: diastolic,
        loggedAt: loggedAt,
        classification: BpClassification.normal,
        pulse: pulse,
        notes: notes,
      ),
    );
  }

  @override
  Future<List<BpLog>> allLogs() async => [];

  @override
  Future<Result<void>> deleteLog(String id) async => const Result.success(null);

  @override
  Future<BpLog?> logById(String id) async => null;

  @override
  Stream<List<BpLog>> watchLogsForDay(LocalDate day) => const Stream.empty();

  @override
  Stream<List<BpLog>> watchLogsInRange(LocalDate start, LocalDate end) =>
      const Stream.empty();

  @override
  Future<void> wipeAll() async {}
}

void main() {
  final fixedNow = DateTime.utc(2026, 6, 15, 8);

  test('rejects diastolic >= systolic', () async {
    final useCase = LogBpUseCase(_FakeBpRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(systolic: 110, diastolic: 115);
    });
    expect(result, isA<Failure<BpLog>>());
  });

  test('rejects out-of-range systolic', () async {
    final useCase = LogBpUseCase(_FakeBpRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(systolic: 20, diastolic: 10);
    });
    expect(result, isA<Failure<BpLog>>());
  });

  test('rejects out-of-range pulse', () async {
    final useCase = LogBpUseCase(_FakeBpRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(systolic: 120, diastolic: 80, pulse: 400);
    });
    expect(result, isA<Failure<BpLog>>());
  });

  test('rejects a future reading time', () async {
    final useCase = LogBpUseCase(_FakeBpRepository());
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(
        systolic: 120,
        diastolic: 80,
        loggedAt: fixedNow.add(const Duration(hours: 1)),
      );
    });
    expect(result, isA<Failure<BpLog>>());
  });

  test('logs a valid reading', () async {
    final repository = _FakeBpRepository();
    final useCase = LogBpUseCase(repository);
    final result = await withClock(Clock.fixed(fixedNow), () {
      return useCase.execute(systolic: 118, diastolic: 76, pulse: 68);
    });
    expect(result, isA<Success<BpLog>>());
    expect(repository.capturedSystolic, 118);
  });
}

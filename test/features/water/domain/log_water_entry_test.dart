import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/repositories/water_repository.dart';
import 'package:habit_tracker/features/water/domain/usecases/log_water_entry.dart';

class _FakeWaterRepository extends Fake implements WaterRepository {
  int? capturedAmountMl;
  DateTime? capturedLoggedAt;
  WaterEntrySource? capturedSource;

  @override
  Future<Result<WaterEntry>> addEntry({
    required int amountMl,
    required DateTime loggedAt,
    required WaterEntrySource source,
    required String profileId,
    String? notes,
  }) async {
    capturedAmountMl = amountMl;
    capturedLoggedAt = loggedAt;
    capturedSource = source;
    return Result.success(
      WaterEntry(
        id: 'x',
        amountMl: amountMl,
        loggedAt: loggedAt,
        source: source,
      ),
    );
  }
}

void main() {
  test(
    'rejects a non-positive amount without touching the repository',
    () async {
      final repo = _FakeWaterRepository();
      final useCase = LogWaterEntryUseCase(repo);

      final result = await useCase.execute(
        amountMl: 0,
        source: WaterEntrySource.custom,
        profileId: 'system',
      );

      expect(
        result,
        const Result<WaterEntry>.failure(
          AppException.validation('amountMl', 'Amount must be greater than 0'),
        ),
      );
      expect(repo.capturedAmountMl, isNull);
    },
  );

  test('rejects a future timestamp without touching the repository', () async {
    final repo = _FakeWaterRepository();
    final useCase = LogWaterEntryUseCase(repo);

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 12)), () async {
      final result = await useCase.execute(
        amountMl: 250,
        source: WaterEntrySource.custom,
        loggedAt: DateTime.utc(2026, 6, 1, 13),
        profileId: 'system',
      );
      expect(
        result,
        const Result<WaterEntry>.failure(
          AppException.validation('loggedAt', 'Cannot log a future entry'),
        ),
      );
    });
    expect(repo.capturedAmountMl, isNull);
  });

  test('logs a valid quick-add entry through the repository', () async {
    final repo = _FakeWaterRepository();
    final useCase = LogWaterEntryUseCase(repo);

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 12)), () async {
      final result = await useCase.execute(
        amountMl: 250,
        source: WaterEntrySource.quick,
        profileId: 'system',
      );
      expect(result, isA<Success<WaterEntry>>());
    });

    expect(repo.capturedAmountMl, 250);
    expect(repo.capturedSource, WaterEntrySource.quick);
    expect(repo.capturedLoggedAt, DateTime.utc(2026, 6, 1, 12));
  });
}

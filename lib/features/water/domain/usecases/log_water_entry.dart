import 'package:clock/clock.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/repositories/water_repository.dart';

/// Logs a water entry, enforcing FR-W-05's "no future timestamp" rule and
/// a positive amount before it ever reaches storage.
class LogWaterEntryUseCase {
  /// Creates the use case backed by [_repository].
  const LogWaterEntryUseCase(this._repository);

  final WaterRepository _repository;

  /// Logs [amountMl] at [loggedAt] (defaults to now) via [source].
  Future<Result<WaterEntry>> execute({
    required int amountMl,
    required WaterEntrySource source,
    DateTime? loggedAt,
    String? notes,
  }) async {
    if (amountMl <= 0) {
      return const Result.failure(
        AppException.validation('amountMl', 'Amount must be greater than 0'),
      );
    }
    final at = loggedAt ?? clock.now();
    if (at.isAfter(clock.now())) {
      return const Result.failure(
        AppException.validation('loggedAt', 'Cannot log a future entry'),
      );
    }
    return _repository.addEntry(
      amountMl: amountMl,
      loggedAt: at,
      source: source,
      notes: notes,
    );
  }
}

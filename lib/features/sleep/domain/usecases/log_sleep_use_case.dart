import 'package:clock/clock.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/sleep/domain/entities/sleep_log.dart';
import 'package:habit_tracker/features/sleep/domain/repositories/sleep_repository.dart';

/// Logs a night's sleep, enforcing that `wakeTime` is after `bedTime` and
/// neither is in the future before it ever reaches storage.
class LogSleepUseCase {
  /// Creates the use case backed by [_repository].
  const LogSleepUseCase(this._repository);

  final SleepRepository _repository;

  /// Logs sleep from [bedTime] to [wakeTime].
  Future<Result<SleepLog>> execute({
    required DateTime bedTime,
    required DateTime wakeTime,
    int? quality,
    String? notes,
  }) async {
    if (!wakeTime.isAfter(bedTime)) {
      return const Result.failure(
        AppException.validation('wakeTime', 'Wake time must be after bed time'),
      );
    }
    final now = clock.now();
    if (wakeTime.isAfter(now)) {
      return const Result.failure(
        AppException.validation('wakeTime', 'Cannot log a future wake time'),
      );
    }
    if (quality != null && (quality < 1 || quality > 5)) {
      return const Result.failure(
        AppException.validation('quality', 'Quality must be between 1 and 5'),
      );
    }
    return _repository.addLog(
      bedTime: bedTime,
      wakeTime: wakeTime,
      quality: quality,
      notes: notes,
    );
  }
}

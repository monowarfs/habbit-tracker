import 'package:clock/clock.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_log.dart';
import 'package:habit_tracker/features/blood_pressure/domain/repositories/bp_repository.dart';

/// Logs a blood-pressure reading, validating physiologically-plausible
/// ranges and no future timestamp before it ever reaches storage.
class LogBpUseCase {
  /// Creates the use case backed by [_repository].
  const LogBpUseCase(this._repository);

  final BpRepository _repository;

  /// Logs [systolic]/[diastolic] (and optional [pulse]) at [loggedAt]
  /// (defaults to now).
  Future<Result<BpLog>> execute({
    required int systolic,
    required int diastolic,
    DateTime? loggedAt,
    int? pulse,
    String? notes,
  }) async {
    if (systolic < 50 || systolic > 300) {
      return const Result.failure(
        AppException.validation(
          'systolic',
          'Systolic must be between 50 and 300',
        ),
      );
    }
    if (diastolic < 30 || diastolic > 200) {
      return const Result.failure(
        AppException.validation(
          'diastolic',
          'Diastolic must be between 30 and 200',
        ),
      );
    }
    if (diastolic >= systolic) {
      return const Result.failure(
        AppException.validation(
          'diastolic',
          'Diastolic must be lower than systolic',
        ),
      );
    }
    if (pulse != null && (pulse < 20 || pulse > 300)) {
      return const Result.failure(
        AppException.validation('pulse', 'Pulse must be between 20 and 300'),
      );
    }
    final at = loggedAt ?? clock.now();
    if (at.isAfter(clock.now())) {
      return const Result.failure(
        AppException.validation('loggedAt', 'Cannot log a future reading'),
      );
    }
    return _repository.addLog(
      systolic: systolic,
      diastolic: diastolic,
      loggedAt: at,
      pulse: pulse,
      notes: notes,
    );
  }
}

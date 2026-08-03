import 'package:clock/clock.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/exercise/domain/entities/exercise_log.dart';
import 'package:habit_tracker/features/exercise/domain/repositories/exercise_repository.dart';

/// Logs a workout, validating a non-empty type, a plausible duration,
/// and no future timestamp before it ever reaches storage.
class LogExerciseUseCase {
  /// Creates the use case backed by [_repository].
  const LogExerciseUseCase(this._repository);

  final ExerciseRepository _repository;

  /// Logs a [exerciseType] workout lasting [durationMinutes] at
  /// [loggedAt] (defaults to now).
  Future<Result<ExerciseLog>> execute({
    required String exerciseType,
    required int durationMinutes,
    DateTime? loggedAt,
    int? calories,
    String? notes,
  }) async {
    if (exerciseType.trim().isEmpty) {
      return const Result.failure(
        AppException.validation('exerciseType', 'Exercise type is required'),
      );
    }
    if (durationMinutes <= 0 || durationMinutes > 1440) {
      return const Result.failure(
        AppException.validation(
          'durationMinutes',
          'Duration must be between 1 and 1440 minutes',
        ),
      );
    }
    if (calories != null && (calories < 0 || calories > 10000)) {
      return const Result.failure(
        AppException.validation(
          'calories',
          'Calories must be between 0 and 10000',
        ),
      );
    }
    final at = loggedAt ?? clock.now();
    if (at.isAfter(clock.now())) {
      return const Result.failure(
        AppException.validation('loggedAt', 'Cannot log a future workout'),
      );
    }
    return _repository.addLog(
      exerciseType: exerciseType.trim(),
      durationMinutes: durationMinutes,
      loggedAt: at,
      calories: calories,
      notes: notes,
    );
  }
}

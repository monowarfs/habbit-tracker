import 'package:clock/clock.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/mood/domain/entities/mood_log.dart';
import 'package:habit_tracker/features/mood/domain/repositories/mood_repository.dart';

/// Logs a mood check-in, validating the mood value is in range and no
/// future timestamp before it ever reaches storage.
class LogMoodUseCase {
  /// Creates the use case backed by [_repository].
  const LogMoodUseCase(this._repository);

  final MoodRepository _repository;

  /// Logs [moodValue] (1-5) at [loggedAt] (defaults to now).
  Future<Result<MoodLog>> execute({
    required int moodValue,
    DateTime? loggedAt,
    String? notes,
  }) async {
    if (moodValue < 1 || moodValue > 5) {
      return const Result.failure(
        AppException.validation('moodValue', 'Mood value must be 1-5'),
      );
    }
    final at = loggedAt ?? clock.now();
    if (at.isAfter(clock.now())) {
      return const Result.failure(
        AppException.validation('loggedAt', 'Cannot log a future check-in'),
      );
    }
    return _repository.addLog(moodValue: moodValue, loggedAt: at, notes: notes);
  }
}

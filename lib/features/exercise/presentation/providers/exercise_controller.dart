import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/features/exercise/domain/entities/exercise_log.dart';
import 'package:habit_tracker/features/exercise/domain/usecases/log_exercise_use_case.dart';
import 'package:habit_tracker/features/exercise/presentation/providers/exercise_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'exercise_controller.g.dart';

/// Mutation surface for the Exercise module — a pure command controller
/// (see `SleepController`'s doc comment for why `keepAlive: true` is
/// required here too).
@Riverpod(keepAlive: true)
class ExerciseController extends _$ExerciseController {
  @override
  void build() {}

  /// Logs a workout. Returns the [Result] so the screen can show the
  /// specific validation message instead of closing as if it had
  /// actually saved, or showing a generic error for every failure reason.
  Future<Result<ExerciseLog>> logWorkout({
    required String exerciseType,
    required int durationMinutes,
    DateTime? loggedAt,
    int? calories,
    String? notes,
  }) async {
    final repository = ref.read(exerciseRepositoryProvider);
    final result = await LogExerciseUseCase(repository).execute(
      exerciseType: exerciseType,
      durationMinutes: durationMinutes,
      loggedAt: loggedAt,
      calories: calories,
      notes: notes,
    );
    if (result case Failure(:final error)) {
      logException(error);
      return result;
    }
    await ref.read(achievementEngineProvider).evaluate('exercise');
    return result;
  }

  /// Deletes a workout.
  Future<bool> deleteLog(String id) async {
    final result = await ref.read(exerciseRepositoryProvider).deleteLog(id);
    if (result case Failure(:final error)) {
      logException(error);
      return false;
    }
    return true;
  }
}

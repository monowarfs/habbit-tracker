import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_log.freezed.dart';

/// A single logged workout.
@freezed
sealed class ExerciseLog with _$ExerciseLog {
  const factory ExerciseLog({
    required String id,
    required String exerciseType,
    required int durationMinutes,
    required DateTime loggedAt,
    int? calories,
    String? notes,
  }) = _ExerciseLog;
}

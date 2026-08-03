import 'package:freezed_annotation/freezed_annotation.dart';

part 'mood_log.freezed.dart';

/// A single mood check-in.
@freezed
sealed class MoodLog with _$MoodLog {
  const factory MoodLog({
    required String id,
    required int moodValue, // 1-5
    required DateTime loggedAt,
    String? notes,
  }) = _MoodLog;
}

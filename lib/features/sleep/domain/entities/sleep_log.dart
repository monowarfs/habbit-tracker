import 'package:freezed_annotation/freezed_annotation.dart';

part 'sleep_log.freezed.dart';

/// A single night's sleep entry.
@freezed
sealed class SleepLog with _$SleepLog {
  const factory SleepLog({
    required String id,
    required DateTime bedTime,
    required DateTime wakeTime,
    required int durationMinutes,
    int? quality, // 1-5
    String? notes,
  }) = _SleepLog;
}

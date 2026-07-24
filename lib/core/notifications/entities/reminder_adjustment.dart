import 'package:freezed_annotation/freezed_annotation.dart';

part 'reminder_adjustment.freezed.dart';

/// A per-module (optionally per-source-type) reminder-time offset derived
/// from historical `done`-action response times
/// (`docs/superpowers/plans/ai-powered/
/// 01-adaptive-reminder-timing-impl-plan.md`).
@freezed
sealed class ReminderAdjustment with _$ReminderAdjustment {
  /// Creates a [ReminderAdjustment].
  const factory ReminderAdjustment({
    required String moduleId,
    String? sourceType,
    required int offsetMinutes,
    required int sampleCount,
    required String confidence,
    required int windowDays,
  }) = _ReminderAdjustment;
}

import 'package:habit_tracker/core/notifications/entities/reminder_adjustment.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:habit_tracker/core/utils/stats.dart';

/// Derives per-`(moduleId, sourceType)` reminder-time offsets from
/// historical `done`-action response times
/// (`docs/superpowers/plans/ai-powered/
/// 01-adaptive-reminder-timing-impl-plan.md`). Median is used over mean —
/// robust against outliers like an overnight Snooze chain skewing the
/// average.
class CalculateAdaptiveOffsetUseCase {
  /// Creates the use case backed by [_ledgerRepository].
  const CalculateAdaptiveOffsetUseCase(
    this._ledgerRepository, {
    this.windowDays = 30,
    this.minSamples = 10,
    this.maxOffsetMinutes = 120,
  });

  final NotificationLedgerRepository _ledgerRepository;

  /// Rolling lookback window for ledger history.
  final int windowDays;

  /// Groups below this sample count are skipped entirely — too little
  /// data to trust a suggestion.
  final int minSamples;

  /// Hard clamp on the returned offset, in either direction — prevents an
  /// absurd shift (e.g. the user missed two weeks of reminders on
  /// vacation).
  final int maxOffsetMinutes;

  /// Computes one [ReminderAdjustment] per `(moduleId, sourceType)` group
  /// with enough samples, as of [now].
  Future<List<ReminderAdjustment>> execute({
    required DateTime now,
    required String profileId,
  }) async {
    final rows = await _ledgerRepository.actionedDoneRows(
      windowDays: windowDays,
      now: now,
      profileId: profileId,
    );

    final offsetsByGroup = <(String, String), List<int>>{};
    for (final row in rows) {
      final actionAt = row.actionAt;
      if (actionAt == null) continue;
      // Measure against the module's own unshifted time, never the
      // (possibly already-adjusted) scheduledFor — otherwise a successful
      // shift reads as "no lag" and the learned offset decays back toward
      // zero as pre-shift samples age out of the rolling window.
      final baseline = row.originalScheduledFor ?? row.scheduledFor;
      final offsetMinutes = DateTime.fromMillisecondsSinceEpoch(
        actionAt,
      ).difference(DateTime.fromMillisecondsSinceEpoch(baseline)).inMinutes;
      offsetsByGroup
          .putIfAbsent((row.moduleId, row.sourceType), () => [])
          .add(offsetMinutes);
    }

    final adjustments = <ReminderAdjustment>[];
    for (final entry in offsetsByGroup.entries) {
      final samples = entry.value;
      if (samples.length < minSamples) continue;

      final (moduleId, sourceType) = entry.key;
      final clamped = median(
        samples,
      ).clamp(-maxOffsetMinutes, maxOffsetMinutes);

      adjustments.add(
        ReminderAdjustment(
          moduleId: moduleId,
          sourceType: sourceType,
          offsetMinutes: clamped,
          sampleCount: samples.length,
          confidence: samples.length >= 20 ? 'high' : 'medium',
          windowDays: windowDays,
        ),
      );
    }
    return adjustments;
  }
}

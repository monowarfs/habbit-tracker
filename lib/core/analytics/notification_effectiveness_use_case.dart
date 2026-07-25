import 'package:habit_tracker/core/database/app_database.dart';

/// Result of an effectiveness calculation over a set of ledger rows.
class EffectivenessResult {
  /// Creates an effectiveness result.
  const EffectivenessResult({
    required this.total,
    required this.acted,
    required this.rate,
  });

  /// Reminders whose scheduled time has already passed — a proxy for
  /// "actually fired" (see `NotificationLedgerRepository.firedRows`'s doc
  /// comment: nothing in the notification stack confirms real OS
  /// delivery, so this can overcount reminders an OEM battery-killer
  /// silently dropped).
  final int total;

  /// Of [total], the ones acted on (`done`) within the attribution window.
  final int acted;

  /// Effectiveness rate, `acted / total` (0.0 to 1.0).
  final double rate;
}

/// Measures how often a reminder actually led to a logged action
/// (`docs/superpowers/specs/08-analytics/07-notification-effectiveness-
/// design.md`) — the self-metric surfaced on the notification settings
/// screen so reminders that aren't working can be tuned or turned off.
class NotificationEffectivenessUseCase {
  /// Creates the use case.
  const NotificationEffectivenessUseCase();

  /// Calculates the effectiveness rate from already-fired ledger [entries]
  /// (e.g. from `NotificationLedgerRepository.firedRows`) — this method
  /// trusts its caller to have already decided what counts as "fired";
  /// every entry passed in counts toward the denominator.
  ///
  /// A fired notification counts as "acted on" only if its `done` action
  /// landed within [attributionWindow] of firing — a Done recorded hours
  /// later is more likely unrelated to that specific reminder. Falls back
  /// to `scheduledFor` as the fire instant when `firedAt` is unset (see
  /// `firedRows`'s doc comment for why that's usually the case).
  ///
  /// Known limitation: a snoozed reminder's `scheduledFor` is overwritten
  /// in place with the re-fire time (`recordSnooze`), so a reminder that
  /// actually fired, got snoozed, then acted on is attributed to the
  /// *last* snooze time rather than the original fire — undercounting the
  /// engagement of exactly the reminders a user snoozes instead of
  /// ignoring outright. Fixing this needs a "first fired" timestamp that
  /// survives snoozes, which isn't in scope here (touches the same
  /// `original_scheduled_for` column the adaptive-reminder-offset feature
  /// already uses for a different purpose).
  EffectivenessResult calculate({
    required List<NotificationLedgerRow> entries,
    Duration attributionWindow = const Duration(hours: 4),
  }) {
    final acted = entries.where((e) {
      if (e.action != 'done' || e.actionAt == null) return false;
      final firedAtMillis = e.firedAt ?? e.scheduledFor;
      final delay = Duration(milliseconds: e.actionAt! - firedAtMillis);
      return !delay.isNegative && delay <= attributionWindow;
    }).length;

    return EffectivenessResult(
      total: entries.length,
      acted: acted,
      rate: entries.isEmpty ? 0 : acted / entries.length,
    );
  }
}

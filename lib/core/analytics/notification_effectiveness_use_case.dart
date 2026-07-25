import 'package:habit_tracker/core/database/app_database.dart';

/// Result of an effectiveness calculation over a set of ledger rows.
class EffectivenessResult {
  /// Creates an effectiveness result.
  const EffectivenessResult({
    required this.total,
    required this.acted,
    required this.rate,
  });

  /// Notifications that actually fired.
  final int total;

  /// Fired notifications acted on (`done`) within the attribution window.
  final int acted;

  /// Effectiveness rate, `acted / total` (0.0 to 1.0).
  final double rate;
}

/// Measures how often a fired reminder actually led to a logged action
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

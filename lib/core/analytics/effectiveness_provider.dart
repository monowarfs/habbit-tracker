import 'package:clock/clock.dart';
import 'package:habit_tracker/core/analytics/notification_effectiveness_use_case.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'effectiveness_provider.g.dart';

/// Per-module [EffectivenessResult] over the last 90 days, keyed by
/// `moduleId` — backs the "Reminder Effectiveness" section on the
/// notification settings screen (07-notification-effectiveness spec).
///
/// `keepAlive: true` so re-opening the settings screen within the same
/// session doesn't re-query the ledger every time — there's no
/// finer-grained TTL invalidation here since nothing else in the app
/// evicts these providers on a timer either.
@Riverpod(keepAlive: true)
Future<Map<String, EffectivenessResult>> notificationEffectiveness(
  Ref ref,
) async {
  final db = ref.watch(databaseProvider);
  final repository = NotificationLedgerRepository(db);
  final rows = await repository.firedRows(windowDays: 90, now: clock.now());

  final byModule = <String, List<NotificationLedgerRow>>{};
  for (final row in rows) {
    byModule.putIfAbsent(row.moduleId, () => []).add(row);
  }

  const useCase = NotificationEffectivenessUseCase();
  return {
    for (final entry in byModule.entries)
      entry.key: useCase.calculate(entries: entry.value),
  };
}

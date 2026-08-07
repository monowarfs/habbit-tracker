import 'dart:async';

import 'package:clock/clock.dart';
import 'package:habit_tracker/core/analytics/notification_effectiveness_use_case.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'effectiveness_provider.g.dart';

/// Per-module [EffectivenessResult] over the last 90 days, keyed by
/// `moduleId` — backs the "Reminder Effectiveness" section on the
/// notification settings screen (07-notification-effectiveness spec).
///
/// Uses `ref.keepAlive()` plus a 1-hour timer that closes the link, per
/// the plan's "cache effectiveness calculation for 1 hour" — re-opening
/// the settings screen within that hour doesn't re-query the ledger. This
/// (rather than `@Riverpod(keepAlive: true)`) also lets the provider
/// actually dispose once nobody's watching it and the hour has elapsed,
/// instead of re-querying the ledger every hour forever for the rest of
/// the app session even after the user never revisits this screen.
@riverpod
Future<Map<String, EffectivenessResult>> notificationEffectiveness(
  Ref ref,
) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(hours: 1), link.close);
  ref.onDispose(timer.cancel);

  final db = ref.watch(databaseProvider);
  final repository = NotificationLedgerRepository(db);
  final profile = await ref.watch(activeProfileProvider.future);
  final rows = await repository.firedRows(
    windowDays: 90,
    now: clock.now(),
    profileId: profile.id,
  );

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

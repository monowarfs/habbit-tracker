import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:habit_tracker/core/notifications/notification_planner.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';

/// Processes a Done/Snooze/Skip action tapped on a notification
/// (`../../strategies/notifications.md`). Runs both from the foreground
/// (an existing [database] is passed in) and from the notification
/// background isolate (`notification_background_handler.dart`, no engine —
/// [database] is `null` and a fresh connection is opened and closed here,
/// which Drift's `NativeDatabase.createInBackground` is designed to allow
/// concurrently with the main app's own connection).
Future<void> handleNotificationAction({
  required String ledgerId,
  required String moduleId,
  required String actionId,
  AppDatabase? database,
}) async {
  final db = database ?? AppDatabase();
  try {
    final ledger = NotificationLedgerRepository(db);
    final row = await ledger.rowById(ledgerId);
    if (row == null) return;
    final now = clock.now();

    switch (actionId) {
      case kNotificationActionDone:
        await ledger.markActioned(ledgerId, action: 'done', actionAt: now);
        await _dispatch(
          db,
          moduleId,
          row.sourceId,
          NotificationActionType.done,
        );
      case kNotificationActionSkip:
        await ledger.markActioned(ledgerId, action: 'skip', actionAt: now);
        await _dispatch(
          db,
          moduleId,
          row.sourceId,
          NotificationActionType.skip,
        );
      case kNotificationActionSnooze:
        await _dispatch(
          db,
          moduleId,
          row.sourceId,
          NotificationActionType.snooze,
        );
        if (row.snoozeCount < 3) {
          final rescheduled = now.add(const Duration(minutes: 10));
          await ledger.recordSnooze(ledgerId, rescheduledFor: rescheduled);
          await NotificationService.instance.schedule(
            PendingNotification(
              id: ledgerId,
              scheduledAt: rescheduled,
              title: row.title,
              body: row.body,
              sourceType: row.sourceType,
              deepLinkRoute: row.deepLinkRoute,
              quietHoursSuppressible: true,
            ),
            moduleId: moduleId,
            snoozeCount: row.snoozeCount + 1,
          );
        }
      default:
        return;
    }

    // Conveyor belt (`../../strategies/notifications.md` trigger 2): a
    // Done/Skip removed a row from "pending", so re-running the planner
    // immediately tops the window back up with the next not-yet-scheduled
    // instance. A Snooze doesn't change what's "pending" (same ids), so
    // this is a harmless no-op in that case rather than special-cased away.
    await planAndApplyNotifications(db: db, now: now);
  } finally {
    if (database == null) await db.close();
  }
}

Future<void> _dispatch(
  AppDatabase db,
  String moduleId,
  String sourceId,
  NotificationActionType action,
) async {
  final modules = buildHabitModules(db);
  for (final module in modules) {
    if (module.id == moduleId) {
      await module.onNotificationAction(sourceId, action);
      return;
    }
  }
}

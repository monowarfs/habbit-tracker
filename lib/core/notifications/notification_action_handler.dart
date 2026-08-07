import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/notifications/audio_cue_service.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:habit_tracker/core/notifications/notification_planner.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';

/// Processes a Done/Snooze/Skip action tapped on a notification
/// (`../../strategies/notifications.md`). Runs both from the foreground
/// (an existing [database] is passed in) and from the notification
/// background isolate (`notification_background_handler.dart`, no engine —
/// [database] is `null` and a fresh connection is opened and closed here,
/// which Drift's `NativeDatabase.createInBackground` is designed to allow
/// concurrently with the main app's own connection). [audioCueService] is
/// a test seam — production always falls back to [AudioCueService.instance]
/// (`docs/superpowers/specs/07-accessibility/
/// 08-AUDIO-CUE-ALTERNATIVE-NOTIFICATION-ACTIONS-IMPLEMENTATION-PLAN.md`).
Future<void> handleNotificationAction({
  required String ledgerId,
  required String moduleId,
  required String actionId,
  AppDatabase? database,
  AudioCueService? audioCueService,
}) async {
  // Runs from the foreground or a fresh background isolate, no Ref — same
  // fixed-profile stopgap as `WaterModule`'s own non-Ref methods
  // (`notification_planner.dart`'s `planAndApplyNotifications` doc comment).
  const profileId = 'system';
  final db = database ?? AppDatabase();
  final audioCue = audioCueService ?? AudioCueService.instance;
  try {
    final ledger = NotificationLedgerRepository(db);
    final row = await ledger.rowById(ledgerId, profileId: profileId);
    if (row == null) return;
    final now = clock.now();
    NotificationActionType? actionTaken;

    switch (actionId) {
      case kNotificationActionDone:
        await ledger.markActioned(
          ledgerId,
          action: 'done',
          actionAt: now,
          profileId: profileId,
        );
        await _dispatch(
          db,
          moduleId,
          row.sourceId,
          NotificationActionType.done,
        );
        actionTaken = NotificationActionType.done;
      case kNotificationActionSkip:
        await ledger.markActioned(
          ledgerId,
          action: 'skip',
          actionAt: now,
          profileId: profileId,
        );
        await _dispatch(
          db,
          moduleId,
          row.sourceId,
          NotificationActionType.skip,
        );
        actionTaken = NotificationActionType.skip;
      case kNotificationActionSnooze:
        await _dispatch(
          db,
          moduleId,
          row.sourceId,
          NotificationActionType.snooze,
        );
        actionTaken = NotificationActionType.snooze;
        if (row.snoozeCount < 3) {
          final rescheduled = now.add(const Duration(minutes: 10));
          await ledger.recordSnooze(
            ledgerId,
            rescheduledFor: rescheduled,
            profileId: profileId,
          );
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

    // Gated on AppSettings.audioCuesEnabled (`docs/superpowers/specs/
    // 07-accessibility/
    // 08-AUDIO-CUE-ALTERNATIVE-NOTIFICATION-ACTIONS-IMPLEMENTATION-
    // PLAN.md`'s "AudioCueService checks this setting before playing" —
    // done here, not inside AudioCueService itself, since that class has
    // no DB/settings access of its own).
    final settings = await SettingsRepositoryImpl(db).watchSettings().first;
    if (settings.audioCuesEnabled) {
      await audioCue.playEarcon(actionTaken);
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

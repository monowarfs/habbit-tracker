import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';

/// One module's pending notification, paired with its owning module id.
typedef ModulePendingNotification = ({
  String moduleId,
  PendingNotification pending,
});

/// What the planner decided needs to change to bring the OS's registered
/// notifications in line with every module's current
/// [HabitModule.pendingNotifications] (`../../strategies/notifications.md`).
class NotificationPlan {
  /// Creates a plan.
  const NotificationPlan({required this.toSchedule, required this.toCancel});

  /// Notifications that should be scheduled (not already registered).
  final List<ModulePendingNotification> toSchedule;

  /// Ledger row ids that are currently registered but fell out of the
  /// window/cap and should be cancelled.
  final List<String> toCancel;
}

/// A local wall-clock suppression window (`AppSettings.quietHours*`).
/// [start]/[end] may wrap past midnight (`start > end`).
class QuietHours {
  /// Creates a quiet-hours window.
  const QuietHours({required this.start, required this.end});

  /// Window start (wall-clock time).
  final LocalTime start;

  /// Window end (wall-clock time).
  final LocalTime end;

  /// Whether local wall-clock time [instant] falls inside this window.
  bool contains(DateTime instant) {
    final t = LocalTime(instant.hour, instant.minute);
    if (start.compareTo(end) <= 0) {
      return t.compareTo(start) >= 0 && t.compareTo(end) < 0;
    }
    return t.compareTo(start) >= 0 || t.compareTo(end) < 0;
  }
}

/// Materializes "Window 2" (`../../strategies/notifications.md`): every
/// module's pending notifications, clipped to [windowDays] ahead of [now]
/// and capped at [iosPendingCap] total across every module combined (the
/// hard iOS ceiling the strategy doc's N=3 was derived against). Pure and
/// synchronous — no plugin/DB dependency — so it's unit-testable on its
/// own.
NotificationPlan planNotifications({
  required Map<String, List<PendingNotification>> pendingByModule,
  required List<NotificationLedgerRow> existingPending,
  required DateTime now,
  int windowDays = 3,
  int iosPendingCap = 64,
  QuietHours? quietHours,
}) {
  final windowEnd = now.add(Duration(days: windowDays));
  final flattened = <ModulePendingNotification>[];
  pendingByModule.forEach((moduleId, list) {
    for (final pending in list) {
      final inWindow = pending.scheduledAt.isAfter(now) &&
          pending.scheduledAt.isBefore(windowEnd);
      if (!inWindow) continue;
      final suppressed = pending.quietHoursSuppressible &&
          (quietHours?.contains(pending.scheduledAt) ?? false);
      if (suppressed) continue;
      flattened.add((moduleId: moduleId, pending: pending));
    }
  });
  flattened.sort(
    (a, b) => a.pending.scheduledAt.compareTo(b.pending.scheduledAt),
  );
  final capped = flattened.take(iosPendingCap).toList();

  final cappedIds = capped.map((e) => e.pending.id).toSet();
  final existingIds = existingPending.map((r) => r.id).toSet();

  final toSchedule = capped
      .where((e) => !existingIds.contains(e.pending.id))
      .toList();
  final toCancel = existingPending
      .where((r) => !cappedIds.contains(r.id))
      .map((r) => r.id)
      .toList();

  return NotificationPlan(toSchedule: toSchedule, toCancel: toCancel);
}

/// Runs [planNotifications] against every registered module's live data and
/// applies it: cancels what fell out of the window, schedules what's newly
/// due. This is what every re-planning trigger
/// (`../../strategies/notifications.md`: app resume, post-action conveyor
/// belt, the Android WorkManager top-up) ultimately calls.
Future<void> planAndApplyNotifications({
  required AppDatabase db,
  DateTime? now,
}) async {
  final modules = buildHabitModules(db);
  final ledger = NotificationLedgerRepository(db);
  final existingPending = await ledger.pendingRows();
  final pendingByModule = <String, List<PendingNotification>>{};
  for (final module in modules) {
    pendingByModule[module.id] = await module.pendingNotifications();
  }
  final settings = await SettingsRepositoryImpl(db).watchSettings().first;
  final plan = planNotifications(
    pendingByModule: pendingByModule,
    existingPending: existingPending,
    now: now ?? clock.now(),
    quietHours: settings.quietHoursEnabled
        ? QuietHours(
            start: settings.quietHoursStart,
            end: settings.quietHoursEnd,
          )
        : null,
  );
  for (final id in plan.toCancel) {
    await NotificationService.instance.cancel(id);
    await ledger.cancel(id);
  }
  for (final entry in plan.toSchedule) {
    await ledger.insertScheduled(
      id: entry.pending.id,
      moduleId: entry.moduleId,
      sourceType: entry.pending.sourceType,
      sourceId: entry.pending.id,
      title: entry.pending.title,
      body: entry.pending.body,
      scheduledFor: entry.pending.scheduledAt,
      deepLinkRoute: entry.pending.deepLinkRoute,
    );
    await NotificationService.instance.schedule(
      entry.pending,
      moduleId: entry.moduleId,
      snoozeCount: 0,
    );
  }
}

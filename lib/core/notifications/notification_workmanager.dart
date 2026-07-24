import 'dart:io';

import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/notifications/notification_planner.dart';
import 'package:habit_tracker/core/wearable/wearable_sync_helper.dart';
import 'package:habit_tracker/core/widgets/widget_refresh_helper.dart';
import 'package:habit_tracker/features/water/data/weather_cache_refresher.dart';
import 'package:workmanager/workmanager.dart';

/// Unique WorkManager task name for the periodic notification top-up.
const notificationTopUpTaskName = 'notification_top_up';

/// Android-only periodic re-top-up of the notification scheduling window
/// (`../../strategies/notifications.md`'s trigger 3) — deliberately **not**
/// registered on iOS: `BGTaskScheduler` is opportunistic with no delivery
/// guarantee, so it isn't treated as a reliable mechanism here (documented
/// platform asymmetry, not an oversight).
@pragma('vm:entry-point')
void notificationWorkmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final db = AppDatabase();
    try {
      await planAndApplyNotifications(db: db);
      await refreshWeatherCacheIfStale(db);
      await refreshAllWidgets(db);
      await syncWearableData(db);
    } finally {
      await db.close();
    }
    return true;
  });
}

/// Registers the periodic top-up task. No-op off-Android.
Future<void> registerNotificationWorkmanager() async {
  if (!Platform.isAndroid) return;
  await Workmanager().initialize(notificationWorkmanagerCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    notificationTopUpTaskName,
    notificationTopUpTaskName,
    frequency: const Duration(hours: 8),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

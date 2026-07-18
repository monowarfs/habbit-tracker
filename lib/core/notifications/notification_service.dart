import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:timezone/timezone.dart' as tz;

/// Action button ids used on every scheduled notification, shared by the
/// scheduler and every handler that decodes a tapped action
/// (`../../strategies/notifications.md`).
const kNotificationActionDone = 'done';

/// See [kNotificationActionDone].
const kNotificationActionSnooze = 'snooze';

/// See [kNotificationActionDone].
const kNotificationActionSkip = 'skip';

/// One Android notification channel per module
/// (`../../strategies/notifications.md`'s per-module-channel requirement).
/// `defaultImportance`, not `high`/`max` — these are "please log this"
/// reminders, not time-critical alerts.
const Map<String, AndroidNotificationChannel> notificationChannels = {
  'water': AndroidNotificationChannel(
    'water_reminders',
    'Water reminders',
    description: 'Reminders to log your water intake',
  ),
};

/// FNV-1a 32-bit hash: `flutter_local_notifications` notification ids are
/// 32-bit ints, but this app's ledger ids are strings — this gives a
/// deterministic mapping between the two that two separate isolates (main
/// app + the background action-handler isolate) always agree on, without
/// relying on `String.hashCode`'s stability, which Dart doesn't document as
/// guaranteed across SDK versions.
int notificationIntId(String id) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(id)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

/// Thin wrapper around `flutter_local_notifications`
/// (`../../strategies/notifications.md`) — the only file that imports the
/// plugin package directly. Deliberately knows nothing about the ledger or
/// module dispatch — callback wiring is composed in
/// `notification_bootstrap.dart` so this file, `notification_action_
/// handler.dart`, and `notification_planner.dart` don't form an import
/// cycle.
class NotificationService {
  /// Creates a service wrapping [_plugin].
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// The app-wide instance — a plain singleton (same pattern as
  /// `core/logging/app_logger.dart`'s `logger`), not a Riverpod provider:
  /// this must be constructible and usable from the notification background
  /// isolate, which has no `ProviderContainer`.
  static final NotificationService instance = NotificationService(
    FlutterLocalNotificationsPlugin(),
  );

  /// Initializes the plugin and creates every module's Android channel.
  /// [onForegroundResponse] fires for taps/actions while the app process is
  /// alive (foreground or backgrounded); [onBackgroundResponse] must be a
  /// top-level `@pragma('vm:entry-point')` function — the plugin's own
  /// requirement for the fully-closed-app case
  /// (`../../strategies/notifications.md`).
  Future<void> rawInit({
    required void Function(NotificationResponse) onForegroundResponse,
    required void Function(NotificationResponse) onBackgroundResponse,
  }) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosCategories = [
      DarwinNotificationCategory(
        'reminder_actions',
        actions: [
          DarwinNotificationAction.plain(kNotificationActionDone, 'Done'),
          DarwinNotificationAction.plain(kNotificationActionSnooze, 'Snooze'),
          DarwinNotificationAction.plain(kNotificationActionSkip, 'Skip'),
        ],
      ),
      DarwinNotificationCategory(
        'reminder_actions_no_snooze',
        actions: [
          DarwinNotificationAction.plain(kNotificationActionDone, 'Done'),
          DarwinNotificationAction.plain(kNotificationActionSkip, 'Skip'),
        ],
      ),
    ];
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: iosCategories,
    );
    await _plugin.initialize(
      settings: InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      for (final channel in notificationChannels.values) {
        await androidPlugin?.createNotificationChannel(channel);
      }
    }
  }

  /// Requests the OS notification permission (Android 13+
  /// `POST_NOTIFICATIONS`, iOS alert/badge/sound). Call after showing the
  /// pre-permission explainer (`notification_permission_explainer_screen
  /// .dart`).
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidPlugin?.requestNotificationsPermission() ?? true;
    }
    if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
    }
    return true;
  }

  /// Whether exact-alarm scheduling is currently allowed (Android 12+).
  /// Always `true` off-Android — see [requestExactAlarmsPermission].
  Future<bool> exactAlarmsAllowed() async {
    if (!Platform.isAndroid) return true;
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  /// Prompts the user for exact-alarm permission (Android 12+'s
  /// user-visible grant, per `../../strategies/notifications.md`'s chosen
  /// approach over the auto-granted `USE_EXACT_ALARM`).
  Future<void> requestExactAlarmsPermission() async {
    if (!Platform.isAndroid) return;
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  /// Schedules (or re-schedules, e.g. for a Snooze) [pending] as a real OS
  /// notification. [snoozeCount] controls whether the Snooze action is
  /// still offered (max-3 rule, `../../strategies/notifications.md`).
  Future<void> schedule(
    PendingNotification pending, {
    required String moduleId,
    required int snoozeCount,
  }) async {
    final channel =
        notificationChannels[moduleId] ?? notificationChannels.values.first;
    final exactAllowed = await exactAlarmsAllowed();
    final canSnooze = snoozeCount < 3;
    final payload = jsonEncode({
      'id': pending.id,
      'moduleId': moduleId,
      'deepLinkRoute': pending.deepLinkRoute,
    });
    await _plugin.zonedSchedule(
      id: notificationIntId(pending.id),
      title: pending.title,
      body: pending.body,
      scheduledDate: tz.TZDateTime.from(pending.scheduledAt, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          actions: [
            const AndroidNotificationAction(kNotificationActionDone, 'Done'),
            if (canSnooze)
              const AndroidNotificationAction(
                kNotificationActionSnooze,
                'Snooze',
              ),
            const AndroidNotificationAction(kNotificationActionSkip, 'Skip'),
          ],
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: canSnooze
              ? 'reminder_actions'
              : 'reminder_actions_no_snooze',
        ),
      ),
      androidScheduleMode: exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Cancels a previously-scheduled notification by its ledger [id].
  Future<void> cancel(String id) => _plugin.cancel(id: notificationIntId(id));

  /// If the app was launched by tapping a notification (cold start), the
  /// tapped notification's `deep_link_route`; otherwise `null`.
  Future<String?> checkLaunchDeepLink() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final payload = details.notificationResponse?.payload;
    if (payload == null) return null;
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    return decoded['deepLinkRoute'] as String?;
  }
}

/// Decodes a tapped/actioned notification's `payload` back into its
/// `(ledgerId, moduleId, deepLinkRoute)` — shared by the foreground and
/// background response handlers so the JSON shape lives in exactly one
/// place.
({String ledgerId, String moduleId, String deepLinkRoute})?
decodeNotificationPayload(
  String? payload,
) {
  if (payload == null) return null;
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  return (
    ledgerId: decoded['id'] as String,
    moduleId: decoded['moduleId'] as String,
    deepLinkRoute: decoded['deepLinkRoute'] as String,
  );
}

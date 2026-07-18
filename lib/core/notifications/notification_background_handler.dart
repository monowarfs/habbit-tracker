import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/notifications/notification_action_handler.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';

/// The action-button tap handler for when the app is fully closed
/// (`../../strategies/notifications.md`) — runs in its own background
/// isolate with no main-isolate state, which is exactly why this must stay
/// a top-level, `@pragma('vm:entry-point')`-annotated function (the
/// plugin's own requirement) rather than a method wired up elsewhere.
@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse response) {
  final decoded = decodeNotificationPayload(response.payload);
  final actionId = response.actionId;
  if (decoded == null || actionId == null) return;
  unawaited(
    handleNotificationAction(
      ledgerId: decoded.ledgerId,
      moduleId: decoded.moduleId,
      actionId: actionId,
    ).catchError((Object e, StackTrace st) {
      logger.e(
        'background notification action failed',
        error: e,
        stackTrace: st,
      );
    }),
  );
}

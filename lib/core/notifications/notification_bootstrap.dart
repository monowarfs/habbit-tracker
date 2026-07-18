import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/notifications/notification_action_handler.dart';
import 'package:habit_tracker/core/notifications/notification_background_handler.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';

/// Wires `NotificationService`'s raw plugin callbacks to this app's
/// deep-link/action handling. The one file allowed to depend on every
/// notification-related file, so none of them need to depend on each other
/// — `notification_background_handler.dart`'s top-level function must stay
/// a leaf the plugin can invoke in a fresh isolate with nothing else
/// initialized (`../../strategies/notifications.md`).
class NotificationBootstrap {
  /// Creates a bootstrap wrapping [service].
  const NotificationBootstrap(this.service);

  /// The service being wired up.
  final NotificationService service;

  /// Initializes the plugin and starts routing taps/actions. [onDeepLink]
  /// is called with a route string for plain taps (FR-C-09); action-button
  /// taps are handled internally via [handleNotificationAction].
  Future<void> init({required void Function(String route) onDeepLink}) {
    return service.rawInit(
      onForegroundResponse: (response) => _handle(response, onDeepLink),
      onBackgroundResponse: notificationTapBackgroundHandler,
    );
  }

  void _handle(
    NotificationResponse response,
    void Function(String) onDeepLink,
  ) {
    final decoded = decodeNotificationPayload(response.payload);
    if (decoded == null) return;
    final actionId = response.actionId;
    if (actionId == null) {
      onDeepLink(decoded.deepLinkRoute);
      return;
    }
    unawaited(
      handleNotificationAction(
        ledgerId: decoded.ledgerId,
        moduleId: decoded.moduleId,
        actionId: actionId,
      ).catchError((Object e, StackTrace st) {
        logger.e(
          'foreground notification action failed',
          error: e,
          stackTrace: st,
        );
      }),
    );
  }
}

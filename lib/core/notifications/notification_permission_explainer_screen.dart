import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';

/// Shows a friendly explanation before the OS notification-permission
/// prompt, then requests it if the user agrees
/// (`../../strategies/notifications.md`'s Android 13+/iOS permission flow).
/// Returns whatever [NotificationService.requestPermission] resolves to, or
/// `false` if the user declined at the explainer step.
Future<bool> showNotificationPermissionExplainer(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.notificationPermissionExplainerTitle),
      content: Text(l10n.notificationPermissionExplainerBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.notificationPermissionNotNowButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.notificationPermissionAllowButton),
        ),
      ],
    ),
  );
  if (proceed != true) return false;
  return NotificationService.instance.requestPermission();
}

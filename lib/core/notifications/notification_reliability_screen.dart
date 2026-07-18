import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Notification troubleshooting stub (`../../strategies/notifications.md`'s
/// OEM battery-killer guidance) — reachable from Settings. Full
/// device-brand-specific instructions and the battery-optimization-exemption
/// action ship in Run 12; this run establishes the entry point and the
/// honest "why this can happen" explanation.
class NotificationReliabilityScreen extends StatelessWidget {
  /// Creates the notification reliability screen.
  const NotificationReliabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationReliabilityTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(l10n.notificationReliabilityIntro),
      ),
    );
  }
}

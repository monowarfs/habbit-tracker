import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/analytics/effectiveness_provider.dart';
import 'package:habit_tracker/core/analytics/notification_effectiveness_use_case.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';

/// Notification troubleshooting stub (`../../strategies/notifications.md`'s
/// OEM battery-killer guidance) — reachable from Settings. Full
/// device-brand-specific instructions and the battery-optimization-exemption
/// action ship in Run 12; this run establishes the entry point and the
/// honest "why this can happen" explanation. Also shows each module's
/// Reminder Effectiveness rate (07-notification-effectiveness spec) so a
/// module whose reminders aren't landing can be spotted and tuned.
class NotificationReliabilityScreen extends ConsumerWidget {
  /// Creates the notification reliability screen.
  const NotificationReliabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final modules = ref.watch(habitModulesProvider);
    final effectiveness = ref.watch(notificationEffectivenessProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationReliabilityTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.notificationReliabilityIntro),
          const Divider(height: 32),
          Text(
            l10n.notificationEffectivenessTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...effectiveness.when(
            data: (byModule) => [
              for (final module in modules)
                _EffectivenessTile(
                  displayName: module.metadata.displayName,
                  accentColor: module.metadata.accentColor,
                  result: byModule[module.id],
                ),
            ],
            loading: () => const [
              Center(child: CircularProgressIndicator()),
            ],
            error: (_, _) => [Text(l10n.notificationEffectivenessEmpty)],
          ),
        ],
      ),
    );
  }
}

class _EffectivenessTile extends StatelessWidget {
  const _EffectivenessTile({
    required this.displayName,
    required this.accentColor,
    required this.result,
  });

  final String displayName;
  final Color accentColor;
  final EffectivenessResult? result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final empty = result == null || result!.total == 0;
    return ListTile(
      leading: CircleAvatar(backgroundColor: accentColor, radius: 6),
      title: Text(displayName),
      subtitle: Text(
        empty
            ? l10n.notificationEffectivenessEmpty
            : l10n.notificationEffectivenessDescription(
                result!.acted,
                result!.total,
              ),
      ),
      trailing: empty
          ? null
          : Text(
              l10n.notificationEffectivenessRate((result!.rate * 100).round()),
            ),
    );
  }
}

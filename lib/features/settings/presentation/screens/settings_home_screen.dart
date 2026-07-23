import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// The Settings tab: sectioned entry points into Appearance, Language,
/// Notifications, Security, Data, and About
/// (`docs/superpowers/specs/2026-07-19-settings-security-design.md`).
class SettingsHomeScreen extends ConsumerWidget {
  /// Creates the settings screen.
  const SettingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pinEnabled =
        ref.watch(appSettingsProvider).value?.pinEnabled ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsAppearance),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.settingsTheme),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/theme'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsLanguage),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n.settingsLanguage),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/language'),
          ),
          const Divider(),
          FutureBuilder<bool>(
            future: NotificationService.instance.exactAlarmsAllowed(),
            builder: (context, snapshot) {
              if (snapshot.data == false) {
                return ListTile(
                  tileColor: Theme.of(context).colorScheme.errorContainer,
                  leading: const Icon(Icons.alarm_off),
                  title: Text(l10n.notificationReliabilityExactAlarmBanner),
                  onTap:
                      NotificationService.instance.requestExactAlarmsPermission,
                );
              }
              return const SizedBox.shrink();
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l10n.settingsNotificationReliability),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/notifications'),
          ),
          ListTile(
            leading: const Icon(Icons.nightlight_outlined),
            title: Text(l10n.settingsQuietHours),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/quiet-hours'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSecurity),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.settingsSecurity),
            subtitle: Text(pinEnabled ? l10n.pinSettingsEnable : ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/pin'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsData),
          ListTile(
            leading: const Icon(Icons.import_export),
            title: Text(l10n.settingsData),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/data'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/about'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      title,
      style:
          Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
    ),
  );
}

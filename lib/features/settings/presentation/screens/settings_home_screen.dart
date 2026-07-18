import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:habit_tracker/features/settings/presentation/providers/locale_controller.dart';
import 'package:habit_tracker/features/settings/presentation/providers/theme_controller.dart';

/// The Settings tab: theme-mode and language switchers today, per-module
/// settings entries join this list once modules ship (`architecture.md`).
class SettingsHomeScreen extends ConsumerWidget {
  /// Creates the settings screen.
  const SettingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          ListTile(title: Text(l10n.settingsTheme)),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeModeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeModeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.themeModeDark),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) => ref
                .read(themeControllerProvider.notifier)
                .updateThemeMode(selection.first),
          ),
          const Divider(),
          ListTile(title: Text(l10n.settingsLanguage)),
          SegmentedButton<Locale>(
            segments: const [
              ButtonSegment(value: Locale('en'), label: Text('English')),
              ButtonSegment(value: Locale('bn'), label: Text('বাংলা')),
            ],
            selected: {locale},
            onSelectionChanged: (selection) => ref
                .read(localeControllerProvider.notifier)
                .updateLocale(selection.first),
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
        ],
      ),
    );
  }
}

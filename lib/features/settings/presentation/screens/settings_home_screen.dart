import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/accessibility/semantic_labels.dart';
import 'package:habit_tracker/core/dev/seed_data_generator.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_settings_providers.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/utils/external_link_launcher.dart';
import 'package:habit_tracker/features/community/community_links.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/settings/presentation/widgets/display_name_editor_sheet.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';

/// The Settings tab: sectioned entry points into Appearance, Language,
/// Notifications, Security, Data, and About
/// (`docs/superpowers/specs/2026-07-19-settings-security-design.md`).
class SettingsHomeScreen extends ConsumerWidget {
  /// Creates the settings screen.
  const SettingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider).value;
    final pinEnabled = settings?.pinEnabled ?? false;
    final displayName = settings?.displayName;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsProfile),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(l10n.settingsDisplayName),
            subtitle: Text(displayName ?? l10n.settingsDisplayNameNotSet),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final name = await showDisplayNameEditorSheet(
                context,
                initialName: displayName,
              );
              if (!context.mounted) return;
              await ref
                  .read(settingsRepositoryProvider)
                  .updateDisplayName(name);
            },
          ),
          const Divider(),
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
          ListTile(
            leading: const Icon(Icons.nightlight_round),
            title: Text(l10n.settingsRamadanMode),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/ramadan'),
          ),
          Semantics(
            label: l10n.adaptiveReminderToggleLabel,
            child: SwitchListTile(
              secondary: const Icon(Icons.schedule_outlined),
              title: Text(l10n.adaptiveReminderTitle),
              subtitle: Text(l10n.adaptiveReminderDescription),
              value:
                  ref
                      .watch(appSettingsProvider)
                      .value
                      ?.adaptiveReminderEnabled ??
                  false,
              onChanged: (value) => ref
                  .read(settingsRepositoryProvider)
                  .updateAdaptiveReminderEnabled(enabled: value),
            ),
          ),
          Semantics(
            label: l10n.reengagementSettingsLabel,
            child: SwitchListTile(
              secondary: const Icon(Icons.waving_hand_outlined),
              title: Text(l10n.reengagementSettingsLabel),
              subtitle: Text(l10n.reengagementSettingsDescription),
              value:
                  ref
                      .watch(appSettingsProvider)
                      .value
                      ?.reengagementNudgeEnabled ??
                  true,
              onChanged: (value) => ref
                  .read(settingsRepositoryProvider)
                  .updateReengagementNudgeEnabled(enabled: value),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSound),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(l10n.settingsSoundToggle),
            value: ref.watch(appSettingsProvider).value?.soundEnabled ?? false,
            onChanged: (value) => ref
                .read(settingsRepositoryProvider)
                .updateSoundEnabled(enabled: value),
          ),
          Semantics(
            label: l10n.settingsAudioCuesLabel,
            child: SwitchListTile(
              secondary: const Icon(Icons.hearing_outlined),
              title: Text(l10n.settingsAudioCuesLabel),
              subtitle: Text(l10n.settingsAudioCuesDescription),
              value:
                  ref.watch(appSettingsProvider).value?.audioCuesEnabled ??
                  true,
              onChanged: (value) => ref
                  .read(settingsRepositoryProvider)
                  .updateAudioCuesEnabled(enabled: value),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.face_retouching_natural_outlined),
            title: Text(l10n.avatarCustomizeTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/avatar'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text(l10n.shopTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/shop'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: Text(l10n.sleepHomeTitle),
            trailing: ref.watch(isPremiumUserProvider)
                ? const Icon(Icons.chevron_right)
                : const Icon(Icons.diamond_outlined),
            onTap: () => context.push('/settings/sleep'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.monitor_heart_outlined),
            title: Text(l10n.bpHomeTitle),
            trailing: ref.watch(isPremiumUserProvider)
                ? const Icon(Icons.chevron_right)
                : const Icon(Icons.diamond_outlined),
            onTap: () => context.push('/settings/blood-pressure'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.fitness_center_outlined),
            title: Text(l10n.exerciseHomeTitle),
            trailing: ref.watch(isPremiumUserProvider)
                ? const Icon(Icons.chevron_right)
                : const Icon(Icons.diamond_outlined),
            onTap: () => context.push('/settings/exercise'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sentiment_satisfied_outlined),
            title: Text(l10n.moodHomeTitle),
            trailing: ref.watch(isPremiumUserProvider)
                ? const Icon(Icons.chevron_right)
                : const Icon(Icons.diamond_outlined),
            onTap: () => context.push('/settings/mood'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.diamond_outlined),
            title: Text(l10n.unlocksTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (ref.read(isPremiumUserProvider)) {
                unawaited(context.push('/settings/unlocks'));
              } else {
                unawaited(context.push('/settings/purchase'));
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(l10n.manageProfilesTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/profiles'),
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
          Semantics(
            label: l10n.recalibrationSettingsLabel,
            child: SwitchListTile(
              secondary: const Icon(Icons.track_changes_outlined),
              title: Text(l10n.recalibrationSettingsLabel),
              subtitle: Text(l10n.recalibrationSettingsDescription),
              value:
                  ref
                      .watch(appSettingsProvider)
                      .value
                      ?.recalibrationPromptsEnabled ??
                  true,
              onChanged: (value) => ref
                  .read(settingsRepositoryProvider)
                  .updateRecalibrationPromptsEnabled(enabled: value),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsData),
          ListTile(
            leading: const Icon(Icons.import_export),
            title: Text(l10n.settingsData),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/data'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: Text(l10n.backupSettingsTitle),
            trailing: ref.watch(isPremiumUserProvider)
                ? const Icon(Icons.chevron_right)
                : const Icon(Icons.diamond_outlined),
            onTap: () => context.push('/settings/backup'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsReports),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: Text(l10n.pastRecapsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/past-recaps'),
          ),
          Semantics(
            label: l10n.recapEnabledLabel,
            child: SwitchListTile(
              secondary: const Icon(Icons.auto_awesome_outlined),
              title: Text(l10n.recapEnabledLabel),
              subtitle: Text(l10n.recapEnabledDescription),
              value: settings?.recapEnabled ?? true,
              onChanged: (value) => ref
                  .read(settingsRepositoryProvider)
                  .updateRecapEnabled(enabled: value),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsModules),
          _ModuleToggleTile(
            moduleId: 'water',
            label: l10n.navWater,
            locked: true,
          ),
          _ModuleToggleTile(moduleId: 'medicine', label: l10n.navMedicine),
          _ModuleToggleTile(moduleId: 'prayer', label: l10n.navPrayer),
          const Divider(),
          _SectionHeader(l10n.settingsPremium),
          ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: Text(l10n.prioritySupportTitle),
            trailing: ref.watch(isPremiumUserProvider)
                ? const Icon(Icons.chevron_right)
                : const Icon(Icons.diamond_outlined),
            onTap: () => context.push('/settings/priority-support'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsCommunity),
          _ExternalLinkTile(
            icon: Icons.forum_outlined,
            title: l10n.communityJoinTitle,
            subtitle: l10n.communityJoinDescription,
            url: CommunityLinks.communityUrl,
            displayUrl: CommunityLinks.communityUrlDisplay,
          ),
          _ExternalLinkTile(
            icon: Icons.feedback_outlined,
            title: l10n.feedbackTitle,
            subtitle: l10n.feedbackDescription,
            url: CommunityLinks.feedbackUrl,
            displayUrl: CommunityLinks.feedbackUrlDisplay,
          ),
          const Divider(),
          _SectionHeader(l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/about'),
          ),
          if (kDebugMode) ...[
            const Divider(),
            const _SectionHeader('Developer'),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Seed Data Generator'),
              subtitle: const Text(
                'Wipes Water/Medicine/Prayer data and backfills 1 month-2 '
                'years of random test history',
              ),
              onTap: () => _seedData(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _seedData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seed Data Generator'),
        content: const Text(
          'This permanently deletes all existing Water, Medicine, and '
          'Prayer data and replaces it with randomized test history. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating seed data…'),
            ],
          ),
        ),
      ),
    );
    try {
      await generateSeedData(
        waterRepository: ref.read(waterRepositoryProvider),
        medicineRepository: ref.read(medicineRepositoryProvider),
        prayerRepository: ref.read(prayerRepositoryProvider),
      );
    } finally {
      if (context.mounted) Navigator.of(context).pop();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seed data generated')),
      );
    }
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

/// A ListTile that opens an external URL via url_launcher.
class _ExternalLinkTile extends StatelessWidget {
  const _ExternalLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
    required this.displayUrl,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
  final String displayUrl;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => launchExternalLink(
        context,
        uri: Uri.parse(url),
        fallbackMessage: displayUrl,
      ),
    );
  }
}

class _ModuleToggleTile extends ConsumerStatefulWidget {
  const _ModuleToggleTile({
    required this.moduleId,
    required this.label,
    this.locked = false,
  });

  final String moduleId;
  final String label;
  final bool locked;

  @override
  ConsumerState<_ModuleToggleTile> createState() => _ModuleToggleTileState();
}

class _ModuleToggleTileState extends ConsumerState<_ModuleToggleTile> {
  late Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = _isEnabled();
  }

  Future<bool> _isEnabled() async {
    final profileId = (await ref.read(activeProfileProvider.future)).id;
    return ref
        .read(moduleSettingsRepositoryProvider)
        .isEnabled(widget.moduleId, profileId: profileId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snapshot) {
        final enabled = snapshot.data ?? false;
        // Switch state (on/off) is already announced natively by
        // SwitchListTile's own semantics — this wrap only adds the
        // module-name label, matching this file's existing convention
        // for the other inline switches above (e.g. recalibration,
        // reengagement).
        return SemanticLabels.wrap(
          label: widget.label,
          child: SwitchListTile(
            title: Text(widget.label),
            value: enabled,
            onChanged: widget.locked
                ? null
                : (value) async {
                    final profileId = (await ref.read(
                      activeProfileProvider.future,
                    )).id;
                    await ref
                        .read(moduleSettingsRepositoryProvider)
                        .setEnabled(
                          widget.moduleId,
                          enabled: value,
                          profileId: profileId,
                        );
                    setState(() {
                      _future = _isEnabled();
                    });
                  },
          ),
        );
      },
    );
  }
}

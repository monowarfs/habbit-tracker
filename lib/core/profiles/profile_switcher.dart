import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/profiles/profile.dart';
import 'package:habit_tracker/core/theme/palette_packs.dart';

/// Resolves a [Profile.avatarColor] key to an actual [Color], reusing the
/// same named-color-key convention as `AppSettingsTable.activePaletteId`
/// (`profile.dart`'s doc comment) — falls back to the default palette's
/// seed color for an unrecognized key.
Color resolveProfileAvatarColor(String avatarColor) {
  final pack = palettePacks.firstWhere(
    (p) => p.id == avatarColor,
    orElse: () => palettePacks.first,
  );
  return pack.seedColor;
}

/// App bar widget showing the active profile's avatar/name; tapping it
/// opens a bottom sheet to switch profiles (family/multi-profile,
/// `docs/superpowers/specs/04-premium/03-family-multi-profile-
/// IMPLEMENTATION-PLAN.md` Task 6).
class ProfileSwitcher extends ConsumerWidget {
  /// Creates the profile switcher.
  const ProfileSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.watch(activeProfileProvider).value;
    if (profile == null) return const SizedBox.shrink();
    return IconButton(
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: resolveProfileAvatarColor(profile.avatarColor),
        child: Text(
          profile.displayName.isEmpty
              ? '?'
              : profile.displayName[0].toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      tooltip: l10n.profileSwitcherTooltip(profile.displayName),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _ProfileSwitcherSheet(),
      ),
    );
  }
}

class _ProfileSwitcherSheet extends ConsumerWidget {
  const _ProfileSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profiles = ref.watch(profileListProvider).value ?? const [];
    final activeId = ref.watch(activeProfileProvider).value?.id;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.switchProfileSheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final profile in profiles)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: resolveProfileAvatarColor(
                  profile.avatarColor,
                ),
                child: Text(
                  profile.displayName.isEmpty
                      ? '?'
                      : profile.displayName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(profile.displayName),
              trailing: profile.id == activeId ? const Icon(Icons.check) : null,
              onTap: profile.id == activeId
                  ? null
                  : () async {
                      await ref
                          .read(profileRepositoryProvider)
                          .setActiveProfile(profile.id);
                      ref
                        ..invalidate(activeProfileProvider)
                        ..invalidate(profileListProvider);
                      if (context.mounted) Navigator.of(context).pop();
                    },
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(l10n.manageProfilesTitle),
            onTap: () {
              Navigator.of(context).pop();
              unawaited(context.push('/settings/profiles'));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

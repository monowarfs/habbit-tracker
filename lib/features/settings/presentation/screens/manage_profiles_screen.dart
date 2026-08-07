import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/profiles/profile.dart';
import 'package:habit_tracker/core/profiles/profile_repository.dart';
import 'package:habit_tracker/core/profiles/profile_switcher.dart';
import 'package:habit_tracker/core/theme/palette_packs.dart';

/// Lists every profile with edit/delete actions, an "Add Profile" entry
/// point (premium-gated, `maxProfiles`-capped), and each profile's
/// approximate data volume (family/multi-profile, `docs/superpowers/
/// specs/04-premium/03-family-multi-profile-IMPLEMENTATION-PLAN.md`
/// Task 7).
class ManageProfilesScreen extends ConsumerWidget {
  /// Creates the manage-profiles screen.
  const ManageProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profiles = ref.watch(profileListProvider).value;
    final activeId = ref.watch(activeProfileProvider).value?.id;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.manageProfilesTitle)),
      body: profiles == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final profile in profiles)
                  _ProfileTile(
                    profile: profile,
                    isActive: profile.id == activeId,
                    canDelete: profiles.length > 1,
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _onAddProfile(context, ref, profiles?.length ?? 0),
        icon: const Icon(Icons.add),
        label: Text(l10n.addProfileAction),
      ),
    );
  }

  Future<void> _onAddProfile(
    BuildContext context,
    WidgetRef ref,
    int currentCount,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (currentCount >= ProfileRepository.maxProfiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.maxProfilesReachedMessage(ProfileRepository.maxProfiles),
          ),
        ),
      );
      return;
    }
    if (!ref.read(isPremiumUserProvider)) {
      unawaited(context.push('/settings/purchase'));
      return;
    }
    final result = await showDialog<({String name, String color})>(
      context: context,
      builder: (context) => const _ProfileEditDialog(),
    );
    if (result == null) return;
    await ref
        .read(profileRepositoryProvider)
        .createProfile(result.name, result.color);
    ref.invalidate(profileListProvider);
  }
}

class _ProfileTile extends ConsumerWidget {
  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.canDelete,
  });

  final Profile profile;
  final bool isActive;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final itemCount = ref.watch(profileDataItemCountProvider(profile.id));
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: resolveProfileAvatarColor(profile.avatarColor),
          child: Text(
            profile.displayName.isEmpty
                ? '?'
                : profile.displayName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(profile.displayName),
        subtitle: Text(
          itemCount.when(
            data: l10n.profileStorageUsageLabel,
            loading: () => '',
            error: (_, _) => '',
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) const Icon(Icons.check_circle),
            IconButton(
              icon: Icon(
                profile.leaderboardOptedOut
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              tooltip: profile.leaderboardOptedOut
                  ? l10n.leaderboardOptIn
                  : l10n.leaderboardOptOut,
              onPressed: () => _onToggleLeaderboardOptOut(ref),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editProfileAction,
              onPressed: () => _onEdit(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteProfileAction,
              onPressed: canDelete ? () => _onDelete(context, ref) : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onToggleLeaderboardOptOut(WidgetRef ref) async {
    await ref
        .read(profileRepositoryProvider)
        .setLeaderboardOptedOut(
          profile.id,
          optedOut: !profile.leaderboardOptedOut,
        );
    ref.invalidate(profileListProvider);
  }

  Future<void> _onEdit(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String name, String color})>(
      context: context,
      builder: (context) => _ProfileEditDialog(profile: profile),
    );
    if (result == null) return;
    await ref
        .read(profileRepositoryProvider)
        .updateProfile(profile.id, name: result.name, color: result.color);
    ref
      ..invalidate(profileListProvider)
      ..invalidate(activeProfileProvider);
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProfileConfirmTitle(profile.displayName)),
        content: Text(l10n.deleteProfileConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteProfileAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(profileRepositoryProvider).deleteProfile(profile.id);
      ref
        ..invalidate(profileListProvider)
        ..invalidate(activeProfileProvider);
      // ProfileRepository.deleteProfile's documented contract throws
      // StateError for "last remaining profile" — the UI already disables
      // delete when canDelete is false, this is a defensive backstop.
      // ignore: avoid_catching_errors
    } on StateError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deleteProfileLastRemainingError)),
        );
      }
    }
  }
}

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({this.profile});

  final Profile? profile;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final _nameController = TextEditingController(
    text: widget.profile?.displayName,
  );
  late String _selectedColor = widget.profile?.avatarColor ?? 'teal';
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.profile == null
            ? l10n.addProfileDialogTitle
            : l10n.editProfileAction,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.profileNameLabel,
              errorText: _errorText,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(l10n.profileColorLabel),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final pack in palettePacks)
                GestureDetector(
                  onTap: () => setState(() => _selectedColor = pack.id),
                  child: CircleAvatar(
                    backgroundColor: pack.seedColor,
                    child: _selectedColor == pack.id
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              setState(() => _errorText = l10n.profileNameRequiredError);
              return;
            }
            Navigator.of(
              context,
            ).pop((name: name, color: _selectedColor));
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

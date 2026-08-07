import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/gamification/avatar/avatar_equipped_repository.dart';
import 'package:habit_tracker/core/gamification/avatar/avatar_piece_catalog.dart';
import 'package:habit_tracker/core/gamification/avatar/avatar_providers.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/features/avatar/presentation/avatar_piece_icons.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/avatar_display.dart';

/// Full-screen avatar customization: a preview plus one piece grid per
/// slot. Locked pieces show a lock icon and their unlock requirement;
/// the equipped piece in each slot shows a checkmark.
class AvatarCustomizeScreen extends ConsumerWidget {
  /// Creates the customize screen.
  const AvatarCustomizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.avatarCustomizeTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: AvatarDisplay()),
          const SizedBox(height: 24),
          for (final slot in AvatarSlot.values) ...[
            Text(
              _localizedSlotName(l10n, slot),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _PieceGrid(slot: slot),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  String _localizedSlotName(AppLocalizations l10n, AvatarSlot slot) =>
      switch (slot) {
        AvatarSlot.head => l10n.avatarSlotHead,
        AvatarSlot.body => l10n.avatarSlotBody,
        AvatarSlot.background => l10n.avatarSlotBackground,
        AvatarSlot.frame => l10n.avatarSlotFrame,
      };
}

class _PieceGrid extends ConsumerWidget {
  const _PieceGrid({required this.slot});
  final AvatarSlot slot;

  String? _equippedIdForSlot(EquippedAvatarPieces equipped, AvatarSlot slot) =>
      switch (slot) {
        AvatarSlot.head => equipped.headPieceId,
        AvatarSlot.body => equipped.bodyPieceId,
        AvatarSlot.background => equipped.backgroundPieceId,
        AvatarSlot.frame => equipped.framePieceId,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final unlockedIds = ref.watch(unlockedAvatarPieceIdsProvider).value ?? {};
    final equipped = ref.watch(avatarEquippedProvider).value;
    final equippedId = equipped == null
        ? null
        : _equippedIdForSlot(equipped, slot);
    final pieces = avatarPieceCatalog.where((p) => p.slot == slot).toList();

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pieces.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final piece = pieces[index];
          final locked = !unlockedIds.contains(piece.id);
          final isEquipped = piece.id == equippedId;

          return Semantics(
            button: true,
            enabled: !locked,
            selected: isEquipped,
            child: GestureDetector(
              onTap: locked
                  ? null
                  : () async {
                      final profileId = (await ref.read(
                        activeProfileProvider.future,
                      )).id;
                      await ref
                          .read(avatarEquippedRepositoryProvider)
                          .equip(
                            slot: slot,
                            pieceId: isEquipped ? null : piece.id,
                            profileId: profileId,
                          );
                    },
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: isEquipped
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 4,
                            )
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          avatarPieceIcons[piece.id],
                          size: 36,
                          color: locked
                              ? theme.colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                )
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        if (locked)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Icon(
                              Icons.lock,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        if (isEquipped)
                          const Positioned(
                            right: 4,
                            bottom: 4,
                            child: Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 72,
                    child: Text(
                      locked
                          ? l10n.avatarLocked
                          : localizedAvatarPieceName(l10n, piece.nameKey),
                      style: theme.textTheme.labelSmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

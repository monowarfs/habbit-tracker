import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/gamification/avatar/avatar_providers.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/avatar/presentation/avatar_piece_icons.dart';

/// Renders the equipped avatar on the dashboard — a base silhouette with
/// unlocked pieces layered on top (background, then head, then a frame
/// ring). Base avatar is always visible; equip state comes from
/// [avatarEquippedProvider].
class AvatarDisplay extends ConsumerWidget {
  /// Creates the avatar display.
  const AvatarDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final equipped = ref.watch(avatarEquippedProvider).value;

    final backgroundIcon = equipped?.backgroundPieceId != null
        ? avatarPieceIcons[equipped!.backgroundPieceId]
        : null;
    final bodyIcon = equipped?.bodyPieceId != null
        ? avatarPieceIcons[equipped!.bodyPieceId]
        : null;
    final headIcon = equipped?.headPieceId != null
        ? avatarPieceIcons[equipped!.headPieceId]
        : null;
    final hasFrame = equipped?.framePieceId != null;

    return Semantics(
      label: l10n.avatarCustomizeTitle,
      excludeSemantics: true,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainerHighest,
          border: hasFrame
              ? Border.all(color: theme.colorScheme.tertiary, width: 3)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (backgroundIcon != null)
              Icon(
                backgroundIcon,
                size: 56,
                color: theme.colorScheme.primaryContainer,
              ),
            if (bodyIcon != null)
              Icon(bodyIcon, size: 44, color: theme.colorScheme.secondary),
            Icon(
              Icons.person,
              size: 36,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            if (headIcon != null)
              Positioned(
                top: 6,
                child: Icon(
                  headIcon,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

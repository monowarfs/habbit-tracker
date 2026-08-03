import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

// ponytail: static Material icon per piece — no PNG art assets exist yet
// (the plan's own "must be produced externally" note). Swap for
// Image.asset(...) once assets/avatar/**/*.png are produced; nothing
// else about the equip/unlock logic needs to change.

/// Placeholder icon per `AvatarPiece.id`, keyed by piece id.
const Map<String, IconData> avatarPieceIcons = {
  'head_bandana': Icons.face_retouching_natural,
  'head_crown': Icons.emoji_events,
  'body_robe': Icons.checkroom,
  'bg_sunset': Icons.wb_twilight,
  'frame_gold': Icons.circle_outlined,
};

/// The localized display name for an avatar piece's `nameKey`
/// (`avatarPieceCatalog` in `avatar_piece_catalog.dart`).
String localizedAvatarPieceName(AppLocalizations l10n, String nameKey) {
  return switch (nameKey) {
    'avatarHeadBandana' => l10n.avatarHeadBandana,
    'avatarHeadCrown' => l10n.avatarHeadCrown,
    'avatarBodyRobe' => l10n.avatarBodyRobe,
    'avatarBgSunset' => l10n.avatarBgSunset,
    'avatarFrameGold' => l10n.avatarFrameGold,
    _ => nameKey,
  };
}

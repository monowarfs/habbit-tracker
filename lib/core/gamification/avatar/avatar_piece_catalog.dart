/// An avatar composite's equip slot.
enum AvatarSlot {
  /// Head-worn piece (hat, crown, etc).
  head,

  /// Body-worn piece (outfit).
  body,

  /// Backdrop behind the avatar.
  background,

  /// Decorative border around the avatar.
  frame,
}

/// A cosmetic avatar piece, unlocked by reaching [unlockAchievementKey].
class AvatarPiece {
  /// Creates a piece definition.
  const AvatarPiece({
    required this.id,
    required this.slot,
    required this.nameKey,
    required this.unlockAchievementKey,
  });

  /// Stable id — also the `cosmetic_unlocks.cosmeticKey` value.
  final String id;

  /// Which equip slot this piece occupies.
  final AvatarSlot slot;

  /// l10n key for the piece's display name.
  final String nameKey;

  /// The achievement key (see `achievementToCosmetic`) that unlocks this
  /// piece — a real module streak-achievement key, not a fictitious one.
  final String unlockAchievementKey;
}

/// All avatar pieces available to unlock and equip.
const avatarPieceCatalog = [
  AvatarPiece(
    id: 'head_bandana',
    slot: AvatarSlot.head,
    nameKey: 'avatarHeadBandana',
    unlockAchievementKey: 'water_streak_7',
  ),
  AvatarPiece(
    id: 'head_crown',
    slot: AvatarSlot.head,
    nameKey: 'avatarHeadCrown',
    unlockAchievementKey: 'water_streak_100',
  ),
  AvatarPiece(
    id: 'body_robe',
    slot: AvatarSlot.body,
    nameKey: 'avatarBodyRobe',
    unlockAchievementKey: 'prayer_streak_30',
  ),
  AvatarPiece(
    id: 'bg_sunset',
    slot: AvatarSlot.background,
    nameKey: 'avatarBgSunset',
    unlockAchievementKey: 'medicine_adherence_streak_7',
  ),
  AvatarPiece(
    id: 'frame_gold',
    slot: AvatarSlot.frame,
    nameKey: 'avatarFrameGold',
    unlockAchievementKey: 'prayer_streak_100',
  ),
];

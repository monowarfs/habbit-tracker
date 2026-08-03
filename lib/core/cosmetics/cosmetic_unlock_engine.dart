import 'package:habit_tracker/core/cosmetics/cosmetic_repository.dart';
import 'package:habit_tracker/core/gamification/avatar/avatar_piece_catalog.dart';

/// Maps achievement keys to cosmetic option keys. Avatar pieces
/// (`avatarPieceCatalog`) are cosmetics too — their `unlockAchievementKey`
/// entries are mirrored here so the existing poll-on-resume unlock check
/// (`_checkCosmeticUnlocks` in `main.dart`) covers them with no new call
/// site.
const achievementToCosmetic = {
  'tenure_2_year': 'theme_accent_midnight',
  'water_streak_7': 'head_bandana',
  'water_streak_100': 'head_crown',
  'prayer_streak_30': 'body_robe',
  'medicine_adherence_streak_7': 'bg_sunset',
  'prayer_streak_100': 'frame_gold',
};

/// Maps achievement keys to cosmetic display info.
class CosmeticOption {
  /// Creates a cosmetic option.
  const CosmeticOption({
    required this.key,
    required this.titleKey,
    required this.descriptionKey,
    required this.achievementKey,
  });

  /// The cosmetic option key.
  final String key;

  /// Localization key for the title.
  final String titleKey;

  /// Localization key for the description.
  final String descriptionKey;

  /// The achievement key that unlocks this cosmetic.
  final String achievementKey;
}

/// All available cosmetic options.
const availableCosmetics = [
  CosmeticOption(
    key: 'theme_accent_midnight',
    titleKey: 'unlockThemeAccentMidnight',
    descriptionKey: 'unlockThemeAccentMidnightDescription',
    achievementKey: 'tenure_2_year',
  ),
];

/// Maps achievement unlocks to cosmetic unlocks.
class CosmeticUnlockEngine {
  /// Creates an engine.
  const CosmeticUnlockEngine({required this.cosmeticRepository});

  /// Repository for cosmetic unlock records.
  final CosmeticRepository cosmeticRepository;

  /// Checks if [achievementKey] maps to a cosmetic unlock.
  /// If so, records it in the cosmetic_unlocks table — tagging the row
  /// with its [AvatarSlot] when the cosmetic is an avatar piece.
  Future<void> onAchievementUnlocked(String achievementKey) async {
    final cosmeticKey = achievementToCosmetic[achievementKey];
    if (cosmeticKey == null) return;
    final piece = _avatarPieceById(cosmeticKey);
    await cosmeticRepository.unlock(
      achievementKey: achievementKey,
      cosmeticKey: cosmeticKey,
      slot: piece?.slot.name,
    );
  }

  /// All unlocked cosmetic keys.
  Future<Set<String>> unlockedCosmetics() {
    return cosmeticRepository.unlockedKeys();
  }
}

AvatarPiece? _avatarPieceById(String id) {
  for (final piece in avatarPieceCatalog) {
    if (piece.id == id) return piece;
  }
  return null;
}

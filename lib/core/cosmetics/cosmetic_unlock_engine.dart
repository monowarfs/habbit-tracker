import 'package:habit_tracker/core/cosmetics/cosmetic_repository.dart';

/// Maps achievement keys to cosmetic option keys.
const achievementToCosmetic = {
  'tenure_2_year': 'theme_accent_midnight',
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
  /// If so, records it in the cosmetic_unlocks table.
  Future<void> onAchievementUnlocked(String achievementKey) async {
    final cosmeticKey = achievementToCosmetic[achievementKey];
    if (cosmeticKey == null) return;
    await cosmeticRepository.unlock(
      achievementKey: achievementKey,
      cosmeticKey: cosmeticKey,
    );
  }

  /// All unlocked cosmetic keys.
  Future<Set<String>> unlockedCosmetics() {
    return cosmeticRepository.unlockedKeys();
  }
}

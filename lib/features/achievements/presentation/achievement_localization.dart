import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// Maps an `AchievementDefinition.titleKey` to its localized text. Every
/// key produced by a module's `achievementDefinitions` (Water/Medicine/
/// Prayer) must have a case here — kept in sync with each module's
/// achievement keys by hand, since these are plain strings, not an enum.
String localizedAchievementTitle(AppLocalizations l10n, String titleKey) {
  return switch (titleKey) {
    'achievementWaterFirstLogTitle' => l10n.achievementWaterFirstLogTitle,
    'achievementWaterStreak7Title' => l10n.achievementWaterStreak7Title,
    'achievementWaterStreak30Title' => l10n.achievementWaterStreak30Title,
    'achievementWaterStreak100Title' => l10n.achievementWaterStreak100Title,
    'achievementWaterPerfectWeekTitle' => l10n.achievementWaterPerfectWeekTitle,
    'achievementMedicineFirstDoseTitle' =>
      l10n.achievementMedicineFirstDoseTitle,
    'achievementMedicineAdherenceStreak7Title' =>
      l10n.achievementMedicineAdherenceStreak7Title,
    'achievementMedicineAdherenceStreak30Title' =>
      l10n.achievementMedicineAdherenceStreak30Title,
    'achievementPrayerFirstLogTitle' => l10n.achievementPrayerFirstLogTitle,
    'achievementPrayerStreak7Title' => l10n.achievementPrayerStreak7Title,
    'achievementPrayerStreak30Title' => l10n.achievementPrayerStreak30Title,
    'achievementPrayerStreak100Title' => l10n.achievementPrayerStreak100Title,
    'achievementPrayerPerfectWeekTitle' =>
      l10n.achievementPrayerPerfectWeekTitle,
    'achievementSleepFirstLogTitle' => l10n.achievementSleepFirstLogTitle,
    'achievementSleepStreak7Title' => l10n.achievementSleepStreak7Title,
    'achievementSleepStreak30Title' => l10n.achievementSleepStreak30Title,
    'achievementSleepStreak100Title' => l10n.achievementSleepStreak100Title,
    'achievementBpFirstLogTitle' => l10n.achievementBpFirstLogTitle,
    'achievementBpStreak7Title' => l10n.achievementBpStreak7Title,
    'achievementBpStreak30Title' => l10n.achievementBpStreak30Title,
    'achievementBpStreak100Title' => l10n.achievementBpStreak100Title,
    'achievementMoodFirstLogTitle' => l10n.achievementMoodFirstLogTitle,
    'achievementMoodStreak7Title' => l10n.achievementMoodStreak7Title,
    'achievementMoodStreak30Title' => l10n.achievementMoodStreak30Title,
    'achievementMoodStreak100Title' => l10n.achievementMoodStreak100Title,
    _ => titleKey,
  };
}

/// Maps an `AchievementDefinition.descriptionKey` to its localized text.
/// Same hand-kept-in-sync caveat as [localizedAchievementTitle].
String localizedAchievementDescription(
  AppLocalizations l10n,
  String descriptionKey,
) {
  return switch (descriptionKey) {
    'achievementWaterFirstLogDescription' =>
      l10n.achievementWaterFirstLogDescription,
    'achievementWaterStreak7Description' =>
      l10n.achievementWaterStreak7Description,
    'achievementWaterStreak30Description' =>
      l10n.achievementWaterStreak30Description,
    'achievementWaterStreak100Description' =>
      l10n.achievementWaterStreak100Description,
    'achievementWaterPerfectWeekDescription' =>
      l10n.achievementWaterPerfectWeekDescription,
    'achievementMedicineFirstDoseDescription' =>
      l10n.achievementMedicineFirstDoseDescription,
    'achievementMedicineAdherenceStreak7Description' =>
      l10n.achievementMedicineAdherenceStreak7Description,
    'achievementMedicineAdherenceStreak30Description' =>
      l10n.achievementMedicineAdherenceStreak30Description,
    'achievementPrayerFirstLogDescription' =>
      l10n.achievementPrayerFirstLogDescription,
    'achievementPrayerStreak7Description' =>
      l10n.achievementPrayerStreak7Description,
    'achievementPrayerStreak30Description' =>
      l10n.achievementPrayerStreak30Description,
    'achievementPrayerStreak100Description' =>
      l10n.achievementPrayerStreak100Description,
    'achievementPrayerPerfectWeekDescription' =>
      l10n.achievementPrayerPerfectWeekDescription,
    'achievementSleepFirstLogDescription' =>
      l10n.achievementSleepFirstLogDescription,
    'achievementSleepStreak7Description' =>
      l10n.achievementSleepStreak7Description,
    'achievementSleepStreak30Description' =>
      l10n.achievementSleepStreak30Description,
    'achievementSleepStreak100Description' =>
      l10n.achievementSleepStreak100Description,
    'achievementBpFirstLogDescription' =>
      l10n.achievementBpFirstLogDescription,
    'achievementBpStreak7Description' => l10n.achievementBpStreak7Description,
    'achievementBpStreak30Description' =>
      l10n.achievementBpStreak30Description,
    'achievementBpStreak100Description' =>
      l10n.achievementBpStreak100Description,
    'achievementMoodFirstLogDescription' =>
      l10n.achievementMoodFirstLogDescription,
    'achievementMoodStreak7Description' =>
      l10n.achievementMoodStreak7Description,
    'achievementMoodStreak30Description' =>
      l10n.achievementMoodStreak30Description,
    'achievementMoodStreak100Description' =>
      l10n.achievementMoodStreak100Description,
    _ => descriptionKey,
  };
}

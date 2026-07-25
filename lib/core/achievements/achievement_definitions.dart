import 'package:flutter/material.dart';

/// Display metadata for tenure-based achievements.
class TenureAchievementDisplay {
  /// Creates a display definition.
  const TenureAchievementDisplay({
    required this.key,
    required this.moduleId,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
  });

  /// The achievement key (e.g. `'tenure_1_year'`).
  final String key;

  /// The module ID (always `'core'` for tenure achievements).
  final String moduleId;

  /// Localization key for the title.
  final String titleKey;

  /// Localization key for the description.
  final String descriptionKey;

  /// Icon to display.
  final IconData icon;
}

/// Display definitions for tenure-based achievements.
const tenureAchievementDefinitions = [
  TenureAchievementDisplay(
    key: 'tenure_1_year',
    moduleId: 'core',
    titleKey: 'achievementTenure1YearTitle',
    descriptionKey: 'achievementTenure1YearDescription',
    icon: Icons.workspace_premium,
  ),
  TenureAchievementDisplay(
    key: 'tenure_2_year',
    moduleId: 'core',
    titleKey: 'achievementTenure2YearTitle',
    descriptionKey: 'achievementTenure2YearDescription',
    icon: Icons.diamond,
  ),
];

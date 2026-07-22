/// A named daily-goal preset offered as a quick-pick chip on
/// `WaterSettingsScreen` (`docs/superpowers/specs/
/// 2026-07-21-05-habit-templates-design.md`).
class WaterGoalPreset {
  /// Creates a water goal preset.
  const WaterGoalPreset({required this.labelKey, required this.goalMl});

  /// L10n key for the chip's label, e.g. `'waterPresetLight'`.
  final String labelKey;

  /// The goal value this preset fills in, in milliliters.
  final int goalMl;
}

/// The three daily-goal presets shown on `WaterSettingsScreen`.
const waterGoalPresets = [
  WaterGoalPreset(labelKey: 'waterPresetLight', goalMl: 1500),
  WaterGoalPreset(labelKey: 'waterPresetStandard', goalMl: 2000),
  WaterGoalPreset(labelKey: 'waterPresetActive', goalMl: 3000),
];

import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';

/// A named schedule preset offered on `MedicineFormScreen`'s step 0
/// (`docs/superpowers/specs/2026-07-21-05-habit-templates-design.md`).
class MedicineSchedulePreset {
  /// Creates a medicine schedule preset.
  const MedicineSchedulePreset({
    required this.labelKey,
    required this.descriptionKey,
    required this.rule,
  });

  /// L10n key for the tile's title, e.g. `'medPresetOnceDaily'`.
  final String labelKey;

  /// L10n key for the tile's subtitle.
  final String descriptionKey;

  /// The repeat rule this preset fills in.
  final RepeatRule rule;
}

/// The four schedule presets shown on `MedicineFormScreen`'s step 0. A
/// fifth, always-last "Custom" tile is not a list entry — the screen
/// renders it separately and falls through to the existing schedule step.
const medicineSchedulePresets = [
  MedicineSchedulePreset(
    labelKey: 'medPresetOnceDaily',
    descriptionKey: 'medPresetOnceDailyDesc',
    rule: RepeatRule.fixedDaily(timesOfDay: [LocalTime(20, 0)]),
  ),
  MedicineSchedulePreset(
    labelKey: 'medPresetTwiceDaily',
    descriptionKey: 'medPresetTwiceDailyDesc',
    rule: RepeatRule.fixedDaily(
      timesOfDay: [LocalTime(8, 0), LocalTime(20, 0)],
    ),
  ),
  MedicineSchedulePreset(
    labelKey: 'medPresetEveryOtherDay',
    descriptionKey: 'medPresetEveryOtherDayDesc',
    rule: RepeatRule.everyNDays(
      intervalDays: 2,
      timesOfDay: [LocalTime(20, 0)],
    ),
  ),
  MedicineSchedulePreset(
    labelKey: 'medPresetAsNeeded',
    descriptionKey: 'medPresetAsNeededDesc',
    rule: RepeatRule.prn(),
  ),
];

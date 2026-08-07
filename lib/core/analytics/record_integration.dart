import 'package:habit_tracker/core/analytics/record_detection_use_case.dart';

/// After a streak recalculation, checks whether [currentStreak] broke
/// [moduleId]'s persisted `longest_streak` record via
/// [recordDetectionUseCase] (Task 4,
/// `docs/superpowers/specs/08-analytics/
/// 02-personal-record-tracking-IMPLEMENTATION-PLAN.md`), returning the
/// [RecordBrokenEvent] so the caller (a stats screen) can show a
/// "New Record!" celebration.
///
/// Deliberately NOT wired into `core/achievements`' engine — the design
/// doc's "Achievement coordination" edge case is explicit that a record
/// celebration is a presentation concern, not a second achievement-unlock
/// detection path for the same underlying streak number.
Future<RecordBrokenEvent?> checkRecordsAfterStreak({
  required RecordDetectionUseCase recordDetectionUseCase,
  required String moduleId,
  required int currentStreak,
}) {
  return recordDetectionUseCase.checkRecord(
    moduleId: moduleId,
    recordType: 'longest_streak',
    currentValue: currentStreak,
  );
}

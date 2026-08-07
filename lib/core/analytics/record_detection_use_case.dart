import 'package:habit_tracker/core/analytics/personal_record_repository.dart';

/// Emitted by [RecordDetectionUseCase.checkRecord] when a new value beats
/// the persisted record.
class RecordBrokenEvent {
  /// Creates a record-broken event.
  const RecordBrokenEvent({
    required this.moduleId,
    required this.recordType,
    required this.newValue,
  });

  /// Which module's record broke.
  final String moduleId;

  /// Which record type broke (e.g. `'longest_streak'`).
  final String recordType;

  /// The new record value.
  final int newValue;
}

/// Detects and persists new personal records (Task 3,
/// `docs/superpowers/specs/08-analytics/
/// 02-personal-record-tracking-IMPLEMENTATION-PLAN.md`).
class RecordDetectionUseCase {
  /// Creates the use case over [repo].
  const RecordDetectionUseCase({required this.repo});

  /// Where records are persisted.
  final PersonalRecordRepository repo;

  /// Checks if a new streak/adherence value breaks the record.
  /// Returns [RecordBrokenEvent] if so.
  Future<RecordBrokenEvent?> checkRecord({
    required String moduleId,
    required String recordType,
    required int currentValue,
    required String profileId,
  }) async {
    final broken = await repo.checkAndUpdate(
      moduleId: moduleId,
      recordType: recordType,
      newValue: currentValue,
      profileId: profileId,
    );
    if (broken) {
      return RecordBrokenEvent(
        moduleId: moduleId,
        recordType: recordType,
        newValue: currentValue,
      );
    }
    return null;
  }
}

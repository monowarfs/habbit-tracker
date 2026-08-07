import 'package:habit_tracker/core/analytics/personal_record_repository.dart';
import 'package:habit_tracker/core/analytics/record_detection_use_case.dart';
import 'package:habit_tracker/core/analytics/record_integration.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'personal_record_providers.g.dart';

/// The shared [PersonalRecordRepository].
@Riverpod(keepAlive: true)
PersonalRecordRepository personalRecordRepository(Ref ref) {
  return PersonalRecordRepository(ref.watch(databaseProvider));
}

/// The shared [RecordDetectionUseCase].
@Riverpod(keepAlive: true)
RecordDetectionUseCase recordDetectionUseCase(Ref ref) {
  return RecordDetectionUseCase(
    repo: ref.watch(personalRecordRepositoryProvider),
  );
}

/// A module's `longest_streak` personal record, read against the
/// current streak (Task 5,
/// `docs/superpowers/specs/08-analytics/
/// 02-personal-record-tracking-IMPLEMENTATION-PLAN.md`) — the value to
/// display, the previous record (for the "Previous: X days" line when a
/// new record was just set), and whether this call is the moment the
/// record broke.
typedef PersonalRecordStatus = ({
  int value,
  int? previousValue,
  bool isNewRecord,
});

/// Checks [currentValue] against [moduleId]'s persisted `longest_streak`
/// record, updating it if beaten, and returns the resulting display
/// state. Safe to call on every stats-screen build — Riverpod caches by
/// argument, and [PersonalRecordRepository.checkAndUpdate] is a cheap,
/// idempotent compare-and-set.
@riverpod
Future<PersonalRecordStatus> personalRecordStatus(
  Ref ref, {
  required String moduleId,
  required int currentValue,
}) async {
  final profileId = (await ref.watch(activeProfileProvider.future)).id;
  final repo = ref.watch(personalRecordRepositoryProvider);
  final existing = await repo.getRecord(
    moduleId: moduleId,
    recordType: 'longest_streak',
    profileId: profileId,
  );
  final event = await checkRecordsAfterStreak(
    recordDetectionUseCase: ref.watch(recordDetectionUseCaseProvider),
    moduleId: moduleId,
    currentStreak: currentValue,
    profileId: profileId,
  );
  return (
    value: event?.newValue ?? existing?.recordValue ?? 0,
    previousValue: existing?.recordValue,
    isNewRecord: event != null,
  );
}

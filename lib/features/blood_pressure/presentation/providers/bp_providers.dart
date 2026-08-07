import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/blood_pressure/data/repositories/bp_repository_impl.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_log.dart';
import 'package:habit_tracker/features/blood_pressure/domain/repositories/bp_repository.dart';
import 'package:habit_tracker/features/blood_pressure/domain/usecases/bp_day_status.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bp_providers.g.dart';

/// The Blood Pressure module's repository.
@Riverpod(keepAlive: true)
BpRepository bpRepository(Ref ref) {
  return BpRepositoryImpl(ref.watch(databaseProvider));
}

/// Every reading with `loggedAt` on [day].
@riverpod
Stream<List<BpLog>> bpLogsForDay(Ref ref, LocalDate day) {
  final profileId = ref.watch(activeProfileProvider).value?.id;
  if (profileId == null) return const Stream.empty();
  return ref
      .watch(bpRepositoryProvider)
      .watchLogsForDay(day, profileId: profileId);
}

/// Every reading with `loggedAt` between [start] and [end] (inclusive).
@riverpod
Stream<List<BpLog>> bpLogsInRange(Ref ref, LocalDate start, LocalDate end) {
  final profileId = ref.watch(activeProfileProvider).value?.id;
  if (profileId == null) return const Stream.empty();
  return ref
      .watch(bpRepositoryProvider)
      .watchLogsInRange(start, end, profileId: profileId);
}

/// The most recent reading across the last 2 days (covers a reading just
/// after midnight not yet reflected in "today").
@riverpod
Future<BpLog?> lastBpLog(Ref ref) async {
  final profileId = (await ref.watch(activeProfileProvider.future)).id;
  final today = localDayKey(clock.now());
  final logs = await ref
      .watch(bpRepositoryProvider)
      .watchLogsInRange(today.addDays(-1), today, profileId: profileId)
      .first;
  if (logs.isEmpty) return null;
  return logs.last;
}

/// The current consecutive-days-logged streak, ending today.
@riverpod
Future<int> bpCurrentStreak(Ref ref) async {
  final profileId = (await ref.watch(activeProfileProvider.future)).id;
  final today = localDayKey(clock.now());
  return currentBpStreak(
    ref.watch(bpRepositoryProvider),
    today,
    profileId: profileId,
  );
}

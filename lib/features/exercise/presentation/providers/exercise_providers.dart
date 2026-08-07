import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/reports/logged_day_status.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/exercise/data/repositories/exercise_repository_impl.dart';
import 'package:habit_tracker/features/exercise/domain/entities/exercise_log.dart';
import 'package:habit_tracker/features/exercise/domain/repositories/exercise_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'exercise_providers.g.dart';

/// The Exercise module's repository.
@Riverpod(keepAlive: true)
ExerciseRepository exerciseRepository(Ref ref) {
  return ExerciseRepositoryImpl(ref.watch(databaseProvider));
}

/// Every workout with `loggedAt` on [day].
@riverpod
Stream<List<ExerciseLog>> exerciseLogsForDay(Ref ref, LocalDate day) {
  final profileId = ref.watch(activeProfileProvider).value?.id;
  if (profileId == null) return const Stream.empty();
  return ref
      .watch(exerciseRepositoryProvider)
      .watchLogsForDay(day, profileId: profileId);
}

/// Every workout with `loggedAt` between [start] and [end] (inclusive).
@riverpod
Stream<List<ExerciseLog>> exerciseLogsInRange(
  Ref ref,
  LocalDate start,
  LocalDate end,
) {
  final profileId = ref.watch(activeProfileProvider).value?.id;
  if (profileId == null) return const Stream.empty();
  return ref
      .watch(exerciseRepositoryProvider)
      .watchLogsInRange(start, end, profileId: profileId);
}

/// The most recent workout across the last 2 days (covers a workout just
/// after midnight not yet reflected in "today").
@riverpod
Future<ExerciseLog?> lastExerciseLog(Ref ref) async {
  final profileId = (await ref.watch(activeProfileProvider.future)).id;
  final today = localDayKey(clock.now());
  final logs = await ref
      .watch(exerciseRepositoryProvider)
      .watchLogsInRange(today.addDays(-1), today, profileId: profileId)
      .first;
  if (logs.isEmpty) return null;
  return logs.last;
}

/// The current consecutive-days-logged streak, ending today.
@riverpod
Future<int> exerciseCurrentStreak(Ref ref) async {
  final profileId = (await ref.watch(activeProfileProvider.future)).id;
  final today = localDayKey(clock.now());
  final repository = ref.watch(exerciseRepositoryProvider);
  return currentLoggedStreak<ExerciseLog>(
    allLogs: () => repository.allLogs(profileId: profileId),
    dateOf: (log) => log.loggedAt,
    today: today,
  );
}

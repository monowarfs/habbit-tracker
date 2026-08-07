import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/reports/logged_day_status.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/mood/data/repositories/mood_repository_impl.dart';
import 'package:habit_tracker/features/mood/domain/entities/mood_log.dart';
import 'package:habit_tracker/features/mood/domain/repositories/mood_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mood_providers.g.dart';

/// The Mood module's repository.
@Riverpod(keepAlive: true)
MoodRepository moodRepository(Ref ref) {
  return MoodRepositoryImpl(ref.watch(databaseProvider));
}

/// Every check-in with `loggedAt` on [day].
@riverpod
Stream<List<MoodLog>> moodLogsForDay(Ref ref, LocalDate day) {
  final profileId = ref.watch(activeProfileProvider).value?.id;
  if (profileId == null) return const Stream.empty();
  return ref
      .watch(moodRepositoryProvider)
      .watchLogsForDay(day, profileId: profileId);
}

/// Every check-in with `loggedAt` between [start] and [end] (inclusive).
@riverpod
Stream<List<MoodLog>> moodLogsInRange(
  Ref ref,
  LocalDate start,
  LocalDate end,
) {
  final profileId = ref.watch(activeProfileProvider).value?.id;
  if (profileId == null) return const Stream.empty();
  return ref
      .watch(moodRepositoryProvider)
      .watchLogsInRange(start, end, profileId: profileId);
}

/// The most recent check-in across the last 2 days (covers a check-in
/// just after midnight not yet reflected in "today").
@riverpod
Future<MoodLog?> lastMoodLog(Ref ref) async {
  final profileId = (await ref.watch(activeProfileProvider.future)).id;
  final today = localDayKey(clock.now());
  final logs = await ref
      .watch(moodRepositoryProvider)
      .watchLogsInRange(today.addDays(-1), today, profileId: profileId)
      .first;
  if (logs.isEmpty) return null;
  return logs.last;
}

/// The current consecutive-days-logged streak, ending today.
@riverpod
Future<int> moodCurrentStreak(Ref ref) async {
  final profileId = (await ref.watch(activeProfileProvider.future)).id;
  final repository = ref.watch(moodRepositoryProvider);
  return currentLoggedStreak<MoodLog>(
    allLogs: () => repository.allLogs(profileId: profileId),
    dateOf: (log) => log.loggedAt,
    today: localDayKey(clock.now()),
  );
}

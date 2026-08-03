import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/sleep/data/repositories/sleep_repository_impl.dart';
import 'package:habit_tracker/features/sleep/domain/entities/sleep_log.dart';
import 'package:habit_tracker/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:habit_tracker/features/sleep/domain/usecases/sleep_day_status.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sleep_providers.g.dart';

/// The Sleep module's repository.
@Riverpod(keepAlive: true)
SleepRepository sleepRepository(Ref ref) {
  return SleepRepositoryImpl(ref.watch(databaseProvider));
}

/// Every log with `wakeTime` on [day].
@riverpod
Stream<List<SleepLog>> sleepLogsForDay(Ref ref, LocalDate day) {
  return ref.watch(sleepRepositoryProvider).watchLogsForDay(day);
}

/// Every log with `wakeTime` between [start] and [end] (inclusive).
@riverpod
Stream<List<SleepLog>> sleepLogsInRange(
  Ref ref,
  LocalDate start,
  LocalDate end,
) {
  return ref.watch(sleepRepositoryProvider).watchLogsInRange(start, end);
}

/// The most recent night's sleep log across the last 2 days (covers a
/// wake time just after midnight not yet reflected in "today").
@riverpod
Future<SleepLog?> lastNightSleepLog(Ref ref) async {
  final today = localDayKey(clock.now());
  final logs = await ref
      .watch(sleepRepositoryProvider)
      .watchLogsInRange(today.addDays(-1), today)
      .first;
  if (logs.isEmpty) return null;
  return logs.last;
}

/// The current consecutive-nights-logged streak, ending today.
@riverpod
Future<int> sleepCurrentStreak(Ref ref) {
  final today = localDayKey(clock.now());
  return currentSleepStreak(ref.watch(sleepRepositoryProvider), today);
}

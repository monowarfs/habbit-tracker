import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/features/sleep/domain/usecases/log_sleep_use_case.dart';
import 'package:habit_tracker/features/sleep/presentation/providers/sleep_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sleep_controller.g.dart';

/// Mutation surface for the Sleep module — a pure command controller (see
/// `WaterController`'s doc comment for why `keepAlive: true` is required
/// here too: screens only ever `ref.read` this, never `watch`).
@Riverpod(keepAlive: true)
class SleepController extends _$SleepController {
  @override
  void build() {}

  /// Logs a night's sleep from [bedTime] to [wakeTime]. Returns whether it
  /// succeeded, so the screen can show a validation error (e.g. a future
  /// wake time, an out-of-range quality) instead of closing as if the
  /// entry had actually been saved.
  Future<bool> logSleep({
    required DateTime bedTime,
    required DateTime wakeTime,
    int? quality,
    String? notes,
  }) async {
    final repository = ref.read(sleepRepositoryProvider);
    final result = await LogSleepUseCase(repository).execute(
      bedTime: bedTime,
      wakeTime: wakeTime,
      quality: quality,
      notes: notes,
    );
    if (result case Failure(:final error)) {
      logException(error);
      return false;
    }
    await ref.read(achievementEngineProvider).evaluate('sleep');
    return true;
  }

  /// Deletes a log.
  Future<bool> deleteLog(String id) async {
    final result = await ref.read(sleepRepositoryProvider).deleteLog(id);
    if (result case Failure(:final error)) {
      logException(error);
      return false;
    }
    return true;
  }
}

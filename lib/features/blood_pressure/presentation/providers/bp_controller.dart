import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/features/blood_pressure/domain/usecases/log_bp_use_case.dart';
import 'package:habit_tracker/features/blood_pressure/presentation/providers/bp_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bp_controller.g.dart';

/// Mutation surface for the Blood Pressure module — a pure command
/// controller (see `SleepController`'s doc comment for why
/// `keepAlive: true` is required here too).
@Riverpod(keepAlive: true)
class BpController extends _$BpController {
  @override
  void build() {}

  /// Logs a reading. Returns whether it succeeded, so the screen can show
  /// a validation error instead of closing as if it had actually saved.
  Future<bool> logReading({
    required int systolic,
    required int diastolic,
    DateTime? loggedAt,
    int? pulse,
    String? notes,
  }) async {
    final repository = ref.read(bpRepositoryProvider);
    final result = await LogBpUseCase(repository).execute(
      systolic: systolic,
      diastolic: diastolic,
      loggedAt: loggedAt,
      pulse: pulse,
      notes: notes,
    );
    if (result case Failure(:final error)) {
      logException(error);
      return false;
    }
    await ref.read(achievementEngineProvider).evaluate('blood_pressure');
    return true;
  }

  /// Deletes a reading.
  Future<bool> deleteLog(String id) async {
    final result = await ref.read(bpRepositoryProvider).deleteLog(id);
    if (result case Failure(:final error)) {
      logException(error);
      return false;
    }
    return true;
  }
}

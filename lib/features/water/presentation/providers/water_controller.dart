import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/usecases/log_water_entry.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'water_controller.g.dart';

/// Mutation surface for the Water module — a pure command controller, it
/// exposes no state of its own (screens watch the read providers in
/// `water_providers.dart` instead).
///
/// `keepAlive: true`: screens only ever `ref.read` this (never `watch`),
/// so nothing keeps a default auto-dispose instance alive across the
/// `await` inside each mutation method — Riverpod would tear it down
/// mid-flight and the method's `ref` use after that point throws.
@Riverpod(keepAlive: true)
class WaterController extends _$WaterController {
  @override
  void build() {}

  /// Logs a quick-add preset amount (FR-W-03).
  Future<void> logQuickAdd(int amountMl) => _log(
    amountMl: amountMl,
    source: WaterEntrySource.quick,
  );

  /// Logs a custom amount, optionally backdated (FR-W-03/FR-W-05).
  Future<void> logCustom({required int amountMl, DateTime? loggedAt}) => _log(
    amountMl: amountMl,
    source: WaterEntrySource.custom,
    loggedAt: loggedAt,
  );

  Future<void> _log({
    required int amountMl,
    required WaterEntrySource source,
    DateTime? loggedAt,
  }) async {
    final repository = ref.read(waterRepositoryProvider);
    final result = await LogWaterEntryUseCase(
      repository,
    ).execute(amountMl: amountMl, source: source, loggedAt: loggedAt);
    if (result case Failure(:final error)) logException(error);
  }

  /// Updates an existing entry (FR-W-09).
  Future<void> updateEntry(
    String id, {
    int? amountMl,
    DateTime? loggedAt,
  }) async {
    final result = await ref
        .read(waterRepositoryProvider)
        .updateEntry(id, amountMl: amountMl, loggedAt: loggedAt);
    if (result case Failure(:final error)) logException(error);
  }

  /// Deletes an entry (FR-W-09).
  Future<void> deleteEntry(String id) async {
    final result = await ref.read(waterRepositoryProvider).deleteEntry(id);
    if (result case Failure(:final error)) logException(error);
  }

  /// Records a new goal effective now (FR-W-01/FR-W-04).
  Future<void> updateGoal(int goalMl) async {
    final result = await ref
        .read(waterRepositoryProvider)
        .setGoal(goalMl, effectiveFrom: DateTime.now());
    if (result case Failure(:final error)) logException(error);
  }

  /// Updates the quick-add preset amounts (FR-W-03).
  Future<void> updateQuickAddAmounts(List<int> amountsMl) async {
    final result = await ref
        .read(waterRepositoryProvider)
        .updateQuickAddAmounts(amountsMl);
    if (result case Failure(:final error)) logException(error);
  }

  /// Updates reminder preferences (FR-W-10, data only).
  Future<void> updateReminderSettings({
    required bool enabled,
    required int intervalMinutes,
    required LocalTime windowStart,
    required LocalTime windowEnd,
  }) async {
    final result = await ref
        .read(waterRepositoryProvider)
        .updateReminderSettings(
          enabled: enabled,
          intervalMinutes: intervalMinutes,
          windowStart: windowStart,
          windowEnd: windowEnd,
        );
    if (result case Failure(:final error)) logException(error);
  }
}

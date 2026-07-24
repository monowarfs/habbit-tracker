import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/water/domain/entities/parsed_water_entry.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/repositories/water_repository.dart';
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

  /// Logs an already-parsed natural-language quick-add entry
  /// (`docs/superpowers/plans/ai-powered/
  /// 02-natural-language-quick-add-impl-plan.md`) — takes the exact
  /// [ParsedWaterEntry] the widget's preview showed and the user confirmed,
  /// rather than re-parsing the raw text here: re-parsing against a fresh
  /// clock/unit at tap-time could silently log something the user never
  /// actually saw. A no-op if no amount could be extracted (the preview
  /// already warned the user before they tapped Log).
  Future<void> logFromParsedText(ParsedWaterEntry parsed) {
    final amountMl = parsed.amountMl;
    if (amountMl == null || amountMl <= 0) return Future.value();
    return _log(
      amountMl: amountMl,
      source: WaterEntrySource.quick,
      loggedAt: parsed.loggedAt,
    );
  }

  /// Logs a custom amount, optionally backdated (FR-W-03/FR-W-05).
  Future<void> logCustom({
    required int amountMl,
    DateTime? loggedAt,
    String? notes,
  }) => _log(
    amountMl: amountMl,
    source: WaterEntrySource.custom,
    loggedAt: loggedAt,
    notes: notes,
  );

  Future<void> _log({
    required int amountMl,
    required WaterEntrySource source,
    DateTime? loggedAt,
    String? notes,
  }) async {
    final repository = ref.read(waterRepositoryProvider);
    final result = await LogWaterEntryUseCase(repository).execute(
      amountMl: amountMl,
      source: source,
      loggedAt: loggedAt,
      notes: notes,
    );
    if (result case Failure(:final error)) {
      logException(error);
      return;
    }
    await ref.read(achievementEngineProvider).evaluate('water');
  }

  /// Updates an existing entry (FR-W-09). See [unsetWaterNotes] for
  /// [notes]'s "omitted vs. explicitly cleared" distinction.
  Future<void> updateEntry(
    String id, {
    int? amountMl,
    DateTime? loggedAt,
    Object? notes = unsetWaterNotes,
  }) async {
    final result = await ref
        .read(waterRepositoryProvider)
        .updateEntry(id, amountMl: amountMl, loggedAt: loggedAt, notes: notes);
    if (result case Failure(:final error)) logException(error);
  }

  /// Deletes an entry (FR-W-09). Returns whether it succeeded so callers
  /// that deferred the write behind an undo window (see `WaterHomeScreen`)
  /// can restore the optimistically-hidden entry if the write failed.
  Future<bool> deleteEntry(String id) async {
    final result = await ref.read(waterRepositoryProvider).deleteEntry(id);
    if (result case Failure(:final error)) {
      logException(error);
      return false;
    }
    return true;
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
    required Map<int, ({LocalTime start, LocalTime end})> windowOverrides,
  }) async {
    final result = await ref
        .read(waterRepositoryProvider)
        .updateReminderSettings(
          enabled: enabled,
          intervalMinutes: intervalMinutes,
          windowStart: windowStart,
          windowEnd: windowEnd,
          windowOverrides: windowOverrides,
        );
    if (result case Failure(:final error)) logException(error);
  }

  /// Enables or disables the weather-derived reminder-copy clause
  /// (`docs/superpowers/specs/02-delightful/
  /// 07-weather-aware-water-nudge-copy-design.md`).
  Future<void> updateWeatherNudgeEnabled({required bool enabled}) async {
    final result = await ref
        .read(waterRepositoryProvider)
        .updateWeatherNudgeEnabled(enabled: enabled);
    if (result case Failure(:final error)) logException(error);
  }
}

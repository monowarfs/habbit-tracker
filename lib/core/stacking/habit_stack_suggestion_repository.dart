import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/stacking/habit_stack_correlation_usecase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'habit_stack_suggestion_repository.g.dart';

/// Drift-backed CRUD over the `habit_stack_suggestions` table
/// (`core/stacking/habit_stack_suggestion_evaluator.dart`'s only data
/// dependency).
class HabitStackSuggestionRepository {
  /// Creates a repository backed by [_db].
  HabitStackSuggestionRepository(this._db);

  final AppDatabase _db;

  /// Looks up a single row by its deterministic [id], or `null` if it has
  /// never been evaluated.
  Future<HabitStackSuggestionRow?> byId(
    String id, {
    required String profileId,
  }) {
    return (_db.select(_db.habitStackSuggestionsTable)..where(
          (t) => t.id.equals(id) & t.profileId.equals(profileId),
        ))
        .getSingleOrNull();
  }

  /// The one `pending` row, if any — the dashboard card's data source.
  /// (At most two rows exist in v1; ordering by `lastEvaluatedAt` desc
  /// just makes "which one, if somehow both are pending" deterministic.)
  Stream<HabitStackSuggestionRow?> pendingSuggestion({
    required String profileId,
  }) {
    final query = _db.select(_db.habitStackSuggestionsTable)
      ..where(
        (t) => t.status.equals('pending') & t.profileId.equals(profileId),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.lastEvaluatedAt)])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  /// Writes [result] as [id]'s current evaluation. Only ever moves a row
  /// **into** `pending` from nothing, from itself (still pending), or
  /// from an expired (`>= 30` days) `dismissed` cooldown — never
  /// overwrites `accepted`, and never resets `dismissed` before its
  /// cooldown expires (though `lastEvaluatedAt` still bumps either way,
  /// so the 24h early-exit in `habit_stack_suggestion_evaluator.dart`
  /// keeps working).
  Future<void> upsertEvaluation({
    required String id,
    required String sourceModuleId,
    required String targetModuleId,
    required StackCorrelationResult result,
    required DateTime now,
    required String profileId,
    String? sourceLabel,
  }) async {
    final nowMillis = now.millisecondsSinceEpoch;
    final existing = await byId(id, profileId: profileId);
    if (existing == null) {
      await _db
          .into(_db.habitStackSuggestionsTable)
          .insert(
            HabitStackSuggestionsTableCompanion.insert(
              id: id,
              sourceModuleId: sourceModuleId,
              targetModuleId: targetModuleId,
              qualifyingDays: result.qualifyingDays,
              medianGapMinutes: result.medianGapMinutes,
              typicalSourceTime: result.typicalSourceTime.format(),
              sourceLabel: Value(sourceLabel),
              lastEvaluatedAt: nowMillis,
              createdAt: nowMillis,
              updatedAt: nowMillis,
              profileId: Value(profileId),
            ),
          );
      return;
    }
    if (existing.status == 'accepted') return;
    if (existing.status == 'dismissed') {
      final respondedAt = existing.respondedAt;
      final cooldownExpired =
          respondedAt == null ||
          now.difference(DateTime.fromMillisecondsSinceEpoch(respondedAt)) >=
              const Duration(days: 30);
      if (!cooldownExpired) {
        await (_db.update(_db.habitStackSuggestionsTable)..where(
              (t) => t.id.equals(id) & t.profileId.equals(profileId),
            ))
            .write(
              HabitStackSuggestionsTableCompanion(
                lastEvaluatedAt: Value(nowMillis),
                updatedAt: Value(nowMillis),
              ),
            );
        return;
      }
    }
    await (_db.update(_db.habitStackSuggestionsTable)..where(
          (t) => t.id.equals(id) & t.profileId.equals(profileId),
        ))
        .write(
          HabitStackSuggestionsTableCompanion(
            status: const Value('pending'),
            qualifyingDays: Value(result.qualifyingDays),
            medianGapMinutes: Value(result.medianGapMinutes),
            typicalSourceTime: Value(result.typicalSourceTime.format()),
            sourceLabel: Value(sourceLabel),
            lastEvaluatedAt: Value(nowMillis),
            respondedAt: const Value(null),
            updatedAt: Value(nowMillis),
          ),
        );
  }

  /// Marks [id] accepted — never re-evaluated again (the reminder is
  /// already adjusted; re-suggesting the same stack is noise).
  Future<void> accept(
    String id, {
    required DateTime now,
    required String profileId,
  }) => _respond(id, status: 'accepted', now: now, profileId: profileId);

  /// Marks [id] dismissed — eligible for re-evaluation after a 30-day
  /// cooldown (`upsertEvaluation`'s own check).
  Future<void> dismiss(
    String id, {
    required DateTime now,
    required String profileId,
  }) => _respond(id, status: 'dismissed', now: now, profileId: profileId);

  Future<void> _respond(
    String id, {
    required String status,
    required DateTime now,
    required String profileId,
  }) async {
    final nowMillis = now.millisecondsSinceEpoch;
    await (_db.update(_db.habitStackSuggestionsTable)..where(
          (t) => t.id.equals(id) & t.profileId.equals(profileId),
        ))
        .write(
          HabitStackSuggestionsTableCompanion(
            status: Value(status),
            respondedAt: Value(nowMillis),
            updatedAt: Value(nowMillis),
          ),
        );
  }
}

/// The shared [HabitStackSuggestionRepository].
@Riverpod(keepAlive: true)
HabitStackSuggestionRepository habitStackSuggestionRepository(Ref ref) {
  return HabitStackSuggestionRepository(ref.watch(databaseProvider));
}

/// The one pending suggestion, if any — `HabitStackSuggestionCard`'s data
/// source.
final StreamProvider<HabitStackSuggestionRow?>
pendingHabitStackSuggestionProvider =
    StreamProvider.autoDispose<HabitStackSuggestionRow?>((ref) async* {
      final profile = await ref.watch(activeProfileProvider.future);
      yield* ref
          .watch(habitStackSuggestionRepositoryProvider)
          .pendingSuggestion(profileId: profile.id);
    });

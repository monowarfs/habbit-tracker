import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';

/// Thin Drift-backed repository over `notification_ledger`
/// (`../../technical/database-design.md`) — the audit trail every module's
/// scheduled/fired/actioned notifications are recorded in
/// (`../../strategies/notifications.md`). Not wrapped in `Result` (unlike
/// feature repositories): nothing in the UI observes these writes directly,
/// they're infrastructure bookkeeping for the notification engine itself.
class NotificationLedgerRepository {
  /// Creates a repository backed by [_db].
  const NotificationLedgerRepository(this._db);

  final AppDatabase _db;

  /// Every not-yet-cancelled, not-yet-actioned row — the planner's view of
  /// "what's currently registered with the OS".
  Future<List<NotificationLedgerRow>> pendingRows({
    required String profileId,
  }) {
    return (_db.select(_db.notificationLedgerTable)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.deletedAt.isNull() &
              t.action.isNull(),
        ))
        .get();
  }

  /// Looks up a single row by id, or `null` if it doesn't exist / was
  /// cancelled.
  Future<NotificationLedgerRow?> rowById(
    String id, {
    required String profileId,
  }) {
    return (_db.select(_db.notificationLedgerTable)..where(
          (t) =>
              t.id.equals(id) &
              t.profileId.equals(profileId) &
              t.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  /// Records a newly-scheduled notification. Idempotent by [id] — safe to
  /// call again for the same slot. [originalScheduledFor] is the module's
  /// own unshifted time — pass it whenever an adaptive-reminder offset
  /// moved [scheduledFor] away from it, so future offset learning stays
  /// anchored to a stable reference.
  Future<void> insertScheduled({
    required String id,
    required String moduleId,
    required String sourceType,
    required String sourceId,
    required String title,
    required String body,
    required DateTime scheduledFor,
    required String deepLinkRoute,
    required String profileId,
    DateTime? originalScheduledFor,
  }) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await _db
        .into(_db.notificationLedgerTable)
        .insertOnConflictUpdate(
          NotificationLedgerTableCompanion.insert(
            id: id,
            moduleId: moduleId,
            sourceType: sourceType,
            sourceId: sourceId,
            title: title,
            body: body,
            scheduledFor: scheduledFor.toUtc().millisecondsSinceEpoch,
            deepLinkRoute: deepLinkRoute,
            originalScheduledFor: Value(
              originalScheduledFor?.toUtc().millisecondsSinceEpoch,
            ),
            createdAt: now,
            updatedAt: now,
            profileId: Value(profileId),
          ),
        );
  }

  /// Records a terminal Done/Skip action.
  Future<void> markActioned(
    String id, {
    required String action,
    required DateTime actionAt,
    required String profileId,
  }) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.notificationLedgerTable)..where(
          (t) => t.id.equals(id) & t.profileId.equals(profileId),
        ))
        .write(
          NotificationLedgerTableCompanion(
            action: Value(action),
            actionAt: Value(actionAt.toUtc().millisecondsSinceEpoch),
            updatedAt: Value(now),
          ),
        );
  }

  /// Records a Snooze: bumps `snooze_count` and moves `scheduled_for` to
  /// the re-fire time. Leaves `action`/`action_at` untouched — snooze is
  /// not a terminal outcome (`../../strategies/notifications.md`), so the
  /// row must stay out of [pendingRows]' "needs top-up" consideration by
  /// remaining "pending" (`action` still null).
  Future<void> recordSnooze(
    String id, {
    required DateTime rescheduledFor,
    required String profileId,
  }) async {
    final row = await rowById(id, profileId: profileId);
    if (row == null) return;
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.notificationLedgerTable)..where(
          (t) => t.id.equals(id) & t.profileId.equals(profileId),
        ))
        .write(
          NotificationLedgerTableCompanion(
            scheduledFor: Value(rescheduledFor.toUtc().millisecondsSinceEpoch),
            snoozeCount: Value(row.snoozeCount + 1),
            updatedAt: Value(now),
          ),
        );
  }

  /// Every terminal Done row `actioned` within the last [windowDays],
  /// relative to [now] — the raw material
  /// `CalculateAdaptiveOffsetUseCase` derives response-time offsets from.
  Future<List<NotificationLedgerRow>> actionedDoneRows({
    required int windowDays,
    required DateTime now,
    required String profileId,
  }) async {
    final since = now.subtract(Duration(days: windowDays));
    return (_db.select(_db.notificationLedgerTable)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.deletedAt.isNull() &
              t.action.equals('done') &
              t.actionAt.isNotNull() &
              t.scheduledFor.isBiggerOrEqualValue(
                since.toUtc().millisecondsSinceEpoch,
              ),
        ))
        .get();
  }

  /// Every row whose reminder should already have fired — `scheduledFor`
  /// in the past — within the last [windowDays], relative to [now],
  /// regardless of what (if anything) happened after —
  /// `NotificationEffectivenessUseCase`'s raw material for the "Reminder
  /// Effectiveness" self-metric.
  ///
  /// Windows on `scheduledFor` rather than `firedAt`: nothing in the
  /// notification stack populates `firedAt` today (`flutter_local_
  /// notifications` has no cross-platform "notification delivered"
  /// callback, only a tap callback), so gating on it would make this query
  /// — and the effectiveness metric itself — permanently empty. A locally
  /// scheduled alarm firing at its scheduled time is the best available
  /// proxy.
  Future<List<NotificationLedgerRow>> firedRows({
    required int windowDays,
    required DateTime now,
    required String profileId,
  }) async {
    final since = now.subtract(Duration(days: windowDays));
    final nowMillis = now.toUtc().millisecondsSinceEpoch;
    return (_db.select(_db.notificationLedgerTable)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.deletedAt.isNull() &
              t.scheduledFor.isBiggerOrEqualValue(
                since.toUtc().millisecondsSinceEpoch,
              ) &
              t.scheduledFor.isSmallerOrEqualValue(nowMillis),
        ))
        .get();
  }

  /// Soft-deletes (cancels) [id] — used when a source falls out of the
  /// scheduling window (e.g. reminder settings changed).
  Future<void> cancel(String id, {required String profileId}) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.notificationLedgerTable)..where(
          (t) => t.id.equals(id) & t.profileId.equals(profileId),
        ))
        .write(
          NotificationLedgerTableCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// Evicts ledger entries older than [age], across every profile —
  /// housekeeping, not a user-facing query, so it deliberately isn't
  /// profile-scoped. Called periodically to bound notification_ledger
  /// growth. User-facing data is unaffected.
  Future<int> cleanupOlderThan(Duration age) async {
    final cutoff = clock.now().subtract(age).toUtc().millisecondsSinceEpoch;
    return (_db.delete(
      _db.notificationLedgerTable,
    )..where((t) => t.createdAt.isSmallerThanValue(cutoff))).go();
  }
}

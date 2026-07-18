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
  Future<List<NotificationLedgerRow>> pendingRows() {
    return (_db.select(
      _db.notificationLedgerTable,
    )..where((t) => t.deletedAt.isNull() & t.action.isNull())).get();
  }

  /// Looks up a single row by id, or `null` if it doesn't exist / was
  /// cancelled.
  Future<NotificationLedgerRow?> rowById(String id) {
    return (_db.select(
      _db.notificationLedgerTable,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
  }

  /// Records a newly-scheduled notification. Idempotent by [id] — safe to
  /// call again for the same slot.
  Future<void> insertScheduled({
    required String id,
    required String moduleId,
    required String sourceType,
    required String sourceId,
    required String title,
    required String body,
    required DateTime scheduledFor,
    required String deepLinkRoute,
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
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Records a terminal Done/Skip action.
  Future<void> markActioned(
    String id, {
    required String action,
    required DateTime actionAt,
  }) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(
      _db.notificationLedgerTable,
    )..where((t) => t.id.equals(id))).write(
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
  }) async {
    final row = await rowById(id);
    if (row == null) return;
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(
      _db.notificationLedgerTable,
    )..where((t) => t.id.equals(id))).write(
      NotificationLedgerTableCompanion(
        scheduledFor: Value(rescheduledFor.toUtc().millisecondsSinceEpoch),
        snoozeCount: Value(row.snoozeCount + 1),
        updatedAt: Value(now),
      ),
    );
  }

  /// Soft-deletes (cancels) [id] — used when a source falls out of the
  /// scheduling window (e.g. reminder settings changed).
  Future<void> cancel(String id) async {
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(
      _db.notificationLedgerTable,
    )..where((t) => t.id.equals(id))).write(
      NotificationLedgerTableCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }
}

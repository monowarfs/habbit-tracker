import 'package:drift/drift.dart';

/// Every notification the app has ever scheduled and what happened to it
/// (`database-design.md`) — the audit trail behind FR-C-07/08/09 and the
/// snooze-limit rule.
///
/// `sourceId` is deliberately not a SQL foreign key: this table is
/// polymorphic by design (one ledger for every module's notifications, so a
/// future module needs zero migration to use it) — referential integrity
/// for it is enforced in the repository layer instead.
@DataClassName('NotificationLedgerRow')
@TableIndex(
  name: 'idx_notification_ledger_scheduled_for',
  columns: {#scheduledFor},
)
@TableIndex(
  name: 'idx_notification_ledger_source',
  columns: {#sourceType, #sourceId},
)
class NotificationLedgerTable extends Table {
  @override
  String get tableName => 'notification_ledger';

  /// Row id.
  TextColumn get id => text()();

  /// `'water'` | `'medicine'` | `'prayer'`.
  TextColumn get moduleId => text()();

  /// `'medicine_dose'` | `'prayer_record'` | `'water_reminder'` |
  /// `'low_stock'`.
  TextColumn get sourceType => text()();

  /// Id of the row in the relevant module table (app-level reference only).
  TextColumn get sourceId => text()();

  /// **Added (Run 08 implementation):** the notification's display title —
  /// needed so a Snooze reschedule can re-show the exact original
  /// notification without asking the module to regenerate content it may
  /// no longer have (e.g. after settings changed) — `strategies/
  /// notifications.md`'s snooze flow.
  TextColumn get title => text()();

  /// **Added (Run 08 implementation):** the notification's display body,
  /// same reasoning as [title].
  TextColumn get body => text()();

  /// UTC epoch millis the OS was asked to fire at.
  IntColumn get scheduledFor => integer()();

  /// UTC epoch millis, set by the notification-received handler.
  IntColumn get firedAt => integer().nullable()();

  /// `'done'` | `'snooze'` | `'skip'` | null (not yet actioned).
  TextColumn get action => text().nullable()();

  /// UTC epoch millis.
  IntColumn get actionAt => integer().nullable()();

  /// Enforces the max-3-snooze rule.
  IntColumn get snoozeCount => integer().withDefault(const Constant(0))();

  /// E.g. `/medicine/dose/:id` — precomputed at scheduling time.
  TextColumn get deepLinkRoute => text()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

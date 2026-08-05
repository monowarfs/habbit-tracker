import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/utils/uuid.dart';

const _singletonId = 'singleton';

/// Drift-backed XP ledger + running balance. `xp_balance`'s singleton row
/// is lazily seeded on first read/write (mirrors `SettingsRepositoryImpl`
/// `_ensureSeeded()`), not via a migration-time insert.
class XpRepository {
  /// Creates a repository backed by [_db].
  XpRepository(this._db);

  final AppDatabase _db;

  /// Records an XP award: inserts a ledger row and increments the running
  /// balance in one transaction.
  Future<void> awardXp({
    required String moduleId,
    required String eventType,
    required int amount,
    required DateTime now,
    String? sourceId,
  }) async {
    final nowMillis = now.millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _ensureSeeded(nowMillis);
      await _db
          .into(_db.xpLedgerTable)
          .insert(
            XpLedgerTableCompanion.insert(
              id: generateId(),
              moduleId: moduleId,
              eventType: eventType,
              xpAmount: amount,
              sourceId: Value(sourceId),
              createdAt: nowMillis,
            ),
          );
      final balance = await (_db.select(
        _db.xpBalanceTable,
      )..where((t) => t.id.equals(_singletonId))).getSingle();
      await (_db.update(
        _db.xpBalanceTable,
      )..where((t) => t.id.equals(_singletonId))).write(
        XpBalanceTableCompanion(
          totalXp: Value(balance.totalXp + amount),
          updatedAt: Value(nowMillis),
        ),
      );
    });
  }

  /// Whether an award already exists for this exact
  /// [moduleId]/[eventType]/[sourceId] combination — the dedup check
  /// idempotent event types (day-complete, quest/boss claims) use before
  /// calling [awardXp], since unlike streak milestones (already
  /// deduped by `AchievementEngine`'s own `justUnlocked` flag) or
  /// per-action awards (naturally 1:1 with each write), these can
  /// otherwise be triggered more than once for the same underlying event.
  Future<bool> hasAwarded({
    required String moduleId,
    required String eventType,
    required String sourceId,
  }) async {
    final row =
        await (_db.select(_db.xpLedgerTable)
              ..where(
                (t) =>
                    t.moduleId.equals(moduleId) &
                    t.eventType.equals(eventType) &
                    t.sourceId.equals(sourceId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Current total XP.
  Future<int> totalXp() async {
    await _ensureSeeded(clock.now().millisecondsSinceEpoch);
    final row = await (_db.select(
      _db.xpBalanceTable,
    )..where((t) => t.id.equals(_singletonId))).getSingle();
    return row.totalXp;
  }

  /// Stream of total XP, for reactive UI.
  Stream<int> watchTotalXp() {
    return Stream.fromFuture(
      _ensureSeeded(clock.now().millisecondsSinceEpoch),
    ).asyncExpand((_) {
      final query = _db.select(
        _db.xpBalanceTable,
      )..where((t) => t.id.equals(_singletonId));
      return query.watchSingle().map((row) => row.totalXp);
    });
  }

  /// Most recent [limit] ledger rows, newest first — the XP-history
  /// screen's source, paginated rather than loading the whole ledger.
  Future<List<XpLedgerRow>> recentLedger({int limit = 50}) {
    return (_db.select(_db.xpLedgerTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> _ensureSeeded(int nowMillis) async {
    final existing = await (_db.select(
      _db.xpBalanceTable,
    )..where((t) => t.id.equals(_singletonId))).getSingleOrNull();
    if (existing != null) return;
    await _db
        .into(_db.xpBalanceTable)
        .insertOnConflictUpdate(
          XpBalanceTableCompanion.insert(
            id: _singletonId,
            totalXp: 0,
            createdAt: nowMillis,
            updatedAt: nowMillis,
          ),
        );
  }
}

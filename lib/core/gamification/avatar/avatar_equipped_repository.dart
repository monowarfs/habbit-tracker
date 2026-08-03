import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/cosmetics/cosmetic_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/avatar/avatar_piece_catalog.dart';

const _singletonId = 'singleton';

/// The currently equipped avatar piece id per slot (or null for none).
class EquippedAvatarPieces {
  /// Creates an equipped-pieces snapshot.
  const EquippedAvatarPieces({
    this.headPieceId,
    this.bodyPieceId,
    this.backgroundPieceId,
    this.framePieceId,
  });

  /// Equipped `head` slot piece id, or null.
  final String? headPieceId;

  /// Equipped `body` slot piece id, or null.
  final String? bodyPieceId;

  /// Equipped `background` slot piece id, or null.
  final String? backgroundPieceId;

  /// Equipped `frame` slot piece id, or null.
  final String? framePieceId;
}

/// CRUD for the singleton `avatar_equipped` row.
class AvatarEquippedRepository {
  /// Creates a repository backed by the given database.
  const AvatarEquippedRepository(this._db);

  final AppDatabase _db;

  /// Reactive stream of the currently equipped pieces (seeds the base
  /// all-null row on first read).
  Stream<EquippedAvatarPieces> watchEquipped() {
    return Stream.fromFuture(_ensureSeeded()).asyncExpand((_) {
      final query = _db.select(_db.avatarEquippedTable)
        ..where((t) => t.id.equals(_singletonId));
      return query.watchSingle().map(
        (row) => EquippedAvatarPieces(
          headPieceId: row.headPieceId,
          bodyPieceId: row.bodyPieceId,
          backgroundPieceId: row.backgroundPieceId,
          framePieceId: row.framePieceId,
        ),
      );
    });
  }

  /// Equips [pieceId] in [slot], or clears the slot when [pieceId] is null.
  ///
  /// A no-op if [pieceId] isn't unlocked or belongs to a different slot —
  /// the UI already disables locked pieces, but this is the actual gate:
  /// any other caller can't equip an unearned piece by construction.
  Future<void> equip({
    required AvatarSlot slot,
    required String? pieceId,
  }) async {
    if (pieceId != null) {
      final piece = avatarPieceCatalog.where((p) => p.id == pieceId);
      if (piece.isEmpty || piece.first.slot != slot) return;
      if (!await CosmeticRepository(_db).isUnlocked(pieceId)) return;
    }
    await _ensureSeeded();
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    final companion = switch (slot) {
      AvatarSlot.head => AvatarEquippedTableCompanion(
        headPieceId: Value(pieceId),
        updatedAt: Value(now),
      ),
      AvatarSlot.body => AvatarEquippedTableCompanion(
        bodyPieceId: Value(pieceId),
        updatedAt: Value(now),
      ),
      AvatarSlot.background => AvatarEquippedTableCompanion(
        backgroundPieceId: Value(pieceId),
        updatedAt: Value(now),
      ),
      AvatarSlot.frame => AvatarEquippedTableCompanion(
        framePieceId: Value(pieceId),
        updatedAt: Value(now),
      ),
    };
    await (_db.update(
      _db.avatarEquippedTable,
    )..where((t) => t.id.equals(_singletonId))).write(companion);
  }

  Future<void> _ensureSeeded() async {
    final existing = await (_db.select(
      _db.avatarEquippedTable,
    )..where((t) => t.id.equals(_singletonId))).getSingleOrNull();
    if (existing != null) return;
    final now = clock.now().toUtc().millisecondsSinceEpoch;
    await _db
        .into(_db.avatarEquippedTable)
        .insertOnConflictUpdate(
          AvatarEquippedTableCompanion.insert(
            id: _singletonId,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}

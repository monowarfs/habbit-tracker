import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/avatar/avatar_equipped_repository.dart';
import 'package:habit_tracker/core/gamification/avatar/avatar_piece_catalog.dart';

void main() {
  late AppDatabase db;
  late AvatarEquippedRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = AvatarEquippedRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('starts with the base avatar (all slots null)', () async {
    final equipped = await repository.watchEquipped().first;
    expect(equipped.headPieceId, isNull);
    expect(equipped.bodyPieceId, isNull);
    expect(equipped.backgroundPieceId, isNull);
    expect(equipped.framePieceId, isNull);
  });

  test('equipping a piece in one slot leaves other slots untouched', () async {
    await repository.equip(slot: AvatarSlot.head, pieceId: 'head_bandana');
    await repository.equip(slot: AvatarSlot.body, pieceId: 'body_robe');

    final equipped = await repository.watchEquipped().first;
    expect(equipped.headPieceId, 'head_bandana');
    expect(equipped.bodyPieceId, 'body_robe');
    expect(equipped.backgroundPieceId, isNull);
  });

  test('equipping null clears a slot', () async {
    await repository.equip(slot: AvatarSlot.head, pieceId: 'head_bandana');
    await repository.equip(slot: AvatarSlot.head, pieceId: null);

    final equipped = await repository.watchEquipped().first;
    expect(equipped.headPieceId, isNull);
  });
}

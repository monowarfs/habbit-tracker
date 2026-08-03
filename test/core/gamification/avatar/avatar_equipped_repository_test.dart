import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/cosmetics/cosmetic_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/avatar/avatar_equipped_repository.dart';
import 'package:habit_tracker/core/gamification/avatar/avatar_piece_catalog.dart';

void main() {
  late AppDatabase db;
  late AvatarEquippedRepository repository;
  late CosmeticRepository cosmeticRepository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = AvatarEquippedRepository(db);
    cosmeticRepository = CosmeticRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> unlock(String pieceId, AvatarSlot slot) {
    return cosmeticRepository.unlock(
      achievementKey: 'test',
      cosmeticKey: pieceId,
      slot: slot.name,
    );
  }

  test('starts with the base avatar (all slots null)', () async {
    final equipped = await repository.watchEquipped().first;
    expect(equipped.headPieceId, isNull);
    expect(equipped.bodyPieceId, isNull);
    expect(equipped.backgroundPieceId, isNull);
    expect(equipped.framePieceId, isNull);
  });

  test('equipping a piece in one slot leaves other slots untouched', () async {
    await unlock('head_bandana', AvatarSlot.head);
    await unlock('body_robe', AvatarSlot.body);
    await repository.equip(slot: AvatarSlot.head, pieceId: 'head_bandana');
    await repository.equip(slot: AvatarSlot.body, pieceId: 'body_robe');

    final equipped = await repository.watchEquipped().first;
    expect(equipped.headPieceId, 'head_bandana');
    expect(equipped.bodyPieceId, 'body_robe');
    expect(equipped.backgroundPieceId, isNull);
  });

  test('equipping null clears a slot', () async {
    await unlock('head_bandana', AvatarSlot.head);
    await repository.equip(slot: AvatarSlot.head, pieceId: 'head_bandana');
    await repository.equip(slot: AvatarSlot.head, pieceId: null);

    final equipped = await repository.watchEquipped().first;
    expect(equipped.headPieceId, isNull);
  });

  test('equipping a locked piece is a no-op', () async {
    await repository.equip(slot: AvatarSlot.head, pieceId: 'head_bandana');

    final equipped = await repository.watchEquipped().first;
    expect(equipped.headPieceId, isNull);
  });

  test('equipping an unlocked piece into the wrong slot is a no-op', () async {
    await unlock('head_bandana', AvatarSlot.head);
    await repository.equip(slot: AvatarSlot.body, pieceId: 'head_bandana');

    final equipped = await repository.watchEquipped().first;
    expect(equipped.bodyPieceId, isNull);
  });
}

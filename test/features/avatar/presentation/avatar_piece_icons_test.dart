import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/avatar/avatar_piece_catalog.dart';
import 'package:habit_tracker/features/avatar/presentation/avatar_piece_icons.dart';

void main() {
  test('avatarPieceCatalog and avatarPieceIcons stay in sync', () {
    final catalogIds = avatarPieceCatalog.map((p) => p.id).toSet();
    expect(
      avatarPieceIcons.keys.toSet(),
      catalogIds,
      reason:
          'avatarPieceIcons must stay in sync with avatarPieceCatalog — a '
          'piece with no icon entry renders as a blank tile with no error.',
    );
  });
}

import 'package:habit_tracker/core/cosmetics/cosmetic_repository.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/gamification/avatar/avatar_equipped_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'avatar_providers.g.dart';

/// The repository over the singleton `avatar_equipped` row.
@riverpod
AvatarEquippedRepository avatarEquippedRepository(Ref ref) {
  return AvatarEquippedRepository(ref.watch(databaseProvider));
}

/// Reactive stream of the currently equipped avatar pieces.
@riverpod
Stream<EquippedAvatarPieces> avatarEquipped(Ref ref) {
  return ref.watch(avatarEquippedRepositoryProvider).watchEquipped();
}

/// Reactive stream of unlocked avatar piece ids (excludes non-avatar
/// cosmetics like theme accents).
@riverpod
Stream<Set<String>> unlockedAvatarPieceIds(Ref ref) {
  return CosmeticRepository(
    ref.watch(databaseProvider),
  ).watchUnlockedAvatarPieceIds();
}

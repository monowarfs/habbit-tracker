import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/gamification/shop/shop_repository.dart';
import 'package:habit_tracker/core/gamification/xp_providers.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shop_providers.g.dart';

/// The shared [ShopRepository].
@riverpod
ShopRepository shopRepository(Ref ref) {
  return ShopRepository(ref.watch(databaseProvider));
}

/// Reactive stream of unlocked shop item ids.
@riverpod
Stream<Set<String>> unlockedShopItems(Ref ref) {
  final profileId = ref.watch(activeProfileProvider).value?.id;
  if (profileId == null) return const Stream.empty();
  return ref
      .watch(shopRepositoryProvider)
      .watchUnlockedItems(profileId: profileId);
}

/// The current XP balance, live-updating (mirrors [totalXpProvider] — the
/// shop's own read of the same balance, kept as a distinct provider so the
/// shop screen doesn't couple to the XP feature's provider name).
@riverpod
int currentXpBalance(Ref ref) {
  return ref.watch(totalXpProvider).value ?? 0;
}

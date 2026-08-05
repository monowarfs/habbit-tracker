import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/gamification/xp_award_listener.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'xp_providers.g.dart';

/// The shared [XpRepository].
@Riverpod(keepAlive: true)
XpRepository xpRepository(Ref ref) {
  return XpRepository(ref.watch(databaseProvider));
}

/// The shared [XpAwardListener], subscribed as soon as this provider is
/// first read (`main.dart` reads it once at startup — same "read once to
/// force creation" pattern as this app's other lifetime services, e.g.
/// `entitlementProvider`) and unsubscribed when the provider container
/// disposes.
@Riverpod(keepAlive: true)
XpAwardListener xpAwardListener(Ref ref) {
  final listener = XpAwardListener(
    achievementEngine: ref.watch(achievementEngineProvider),
    xpRepository: ref.watch(xpRepositoryProvider),
  );
  final subscription = listener.listen();
  ref.onDispose(subscription.cancel);
  return listener;
}

/// The current total XP, live-updating.
@riverpod
Stream<int> totalXp(Ref ref) {
  return ref.watch(xpRepositoryProvider).watchTotalXp();
}

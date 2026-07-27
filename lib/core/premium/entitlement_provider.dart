import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/premium/entitlement_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'entitlement_provider.g.dart';

/// Provider for the [EntitlementService] instance.
@Riverpod(keepAlive: true)
EntitlementService entitlementService(Ref ref) {
  return EntitlementService(ref.watch(databaseProvider));
}

/// A notifier that tracks the current premium status of the user.
///
/// This is the reactive entry point for UI components to check if
/// features should be gated.
@Riverpod(keepAlive: true)
class EntitlementNotifier extends _$EntitlementNotifier {
  @override
  FutureOr<bool> build() async {
    final state = await ref
        .watch(entitlementServiceProvider)
        .getCachedEntitlement();
    return state.isPremium;
  }

  /// Refreshes the entitlement state from the platform store.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(entitlementServiceProvider);
      await service.verifyWithStore();
      final newState = await service.getCachedEntitlement();
      return newState.isPremium;
    });
  }

  /// Manually sets the premium state (e.g. after a successful purchase).
  void setPremium({required bool isPremium}) {
    state = AsyncValue.data(isPremium);
  }
}

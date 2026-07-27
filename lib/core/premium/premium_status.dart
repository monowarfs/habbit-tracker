import 'package:habit_tracker/core/premium/entitlement_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'premium_status.g.dart';

/// Whether the current user has premium entitlement. Every premium-gated
/// feature (backup/restore, priority support, exportable reports,
/// extended stats ranges) reads this single provider.
@riverpod
bool isPremiumUser(Ref ref) {
  final entitlement = ref.watch(entitlementNotifierProvider);
  return entitlement.value ?? false;
}

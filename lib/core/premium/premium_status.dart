import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'premium_status.g.dart';

/// Whether the current user has premium entitlement. Every premium-gated
/// feature (starting with Drive backup/restore) reads this single
/// provider, so swapping the stub below for a real check later touches
/// no call site.
// TODO(spec-07): replace with the real entitlement check once
// docs/superpowers/specs/04-premium/07-lifetime-unlock-pricing-tier-
// IMPLEMENTATION-PLAN.md ships its EntitlementService/entitlementProvider.
@riverpod
bool isPremiumUser(Ref ref) => true;

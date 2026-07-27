import 'dart:async';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// The result of an entitlement check.
class EntitlementState {
  final bool isPremium;
  final String? source;
  final DateTime? expiresAt;
  final DateTime lastVerifiedAt;

  const EntitlementState({
    required this.isPremium,
    this.source,
    this.expiresAt,
    required this.lastVerifiedAt,
  });

  factory EntitlementState.initial() => EntitlementState(
    isPremium: false,
    lastVerifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Orchestrates premium status verification with the platform stores
/// and local cache.
///
/// This is the foundational service for all IAP-gated features
/// (`docs/superpowers/specs/04-premium/07-lifetime-unlock-pricing-tier-design.md`).
class EntitlementService {
  final AppDatabase db;
  final InAppPurchase _iap = InAppPurchase.instance;

  EntitlementService(this.db);

  /// Product IDs for the lifetime unlock and subscription.
  static const String lifetimeProductId = 'premium_lifetime_unlock';
  static const String monthlySubscriptionId = 'premium_monthly_subscription';

  /// Returns the current cached entitlement state from the database.
  Future<EntitlementState> getCachedEntitlement() async {
    final entitlement = await (db.select(db.premiumEntitlements)
          ..where((t) => t.id.equals('singleton')))
        .getSingleOrNull();

    if (entitlement == null) return EntitlementState.initial();

    return EntitlementState(
      isPremium: entitlement.isPremium,
      source: entitlement.entitlementSource,
      expiresAt: entitlement.subscriptionExpiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(entitlement.subscriptionExpiresAt! * 1000)
          : null,
      lastVerifiedAt: DateTime.fromMillisecondsSinceEpoch(entitlement.lastVerifiedAt * 1000),
    );
  }

  /// Updates the local entitlement cache.
  Future<void> updateEntitlement(EntitlementState state) async {
    await db.into(db.premiumEntitlements).insertOnConflictUpdate(
      PremiumEntitlementsCompanion.insert(
        id: 'singleton',
        isPremium: state.isPremium,
        entitlementSource: Value(state.source),
        subscriptionExpiresAt: Value(state.expiresAt?.millisecondsSinceEpoch != null 
            ? state.expiresAt!.millisecondsSinceEpoch ~/ 1000 
            : null),
        lastVerifiedAt: state.lastVerifiedAt.millisecondsSinceEpoch ~/ 1000,
      ),
    );
  }

  /// Verifies the current entitlement with the App Store / Play Store.
  ///
  /// Should be called on app launch and after every purchase completion.
  Future<void> verifyWithStore() async {
    final available = await _iap.isAvailable();
    if (!available) return;

    // In a real app, this would use _iap.queryPurchasesAsync().
    // For local development/testing without a real store, we can use
    // the existing cached state but simulate a "refresh".
    final current = await getCachedEntitlement();
    if (current.isPremium) {
      // Keep it as is for now.
      return;
    }
  }

  /// Handles a successful purchase completion.
  Future<void> onPurchaseCompleted(PurchaseDetails details) async {
    final isLifetime = details.productID == lifetimeProductId;
    final isSubscription = details.productID == monthlySubscriptionId;

    if (!isLifetime && !isSubscription) return;

    final newState = EntitlementState(
      isPremium: true,
      source: isLifetime ? 'lifetime_purchase' : 'subscription',
      expiresAt: isSubscription
          ? DateTime.now().add(const Duration(days: 30))
          : null,
      lastVerifiedAt: DateTime.now(),
    );

    await updateEntitlement(newState);
  }

  /// Restores previously purchased products.
  Future<void> restorePurchases() async {
    final available = await _iap.isAvailable();
    if (!available) return;

    await _iap.restorePurchases();
  }
}

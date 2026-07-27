import 'package:drift/drift.dart';

/// Persisted cache of the user's premium entitlement state.
///
/// This avoids needing a network call on every app start just to check
/// if the user is premium. We verify with the platform stores
/// periodically (`strategies/premium.md`) and update this table.
class PremiumEntitlements extends Table {
  /// The product ID or a fixed string like 'singleton'.
  TextColumn get id => text()();

  /// Whether the user currently has premium access.
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();

  /// Where the entitlement came from (e.g. 'lifetime_purchase',
  /// 'subscription').
  TextColumn get entitlementSource => text().nullable()();

  /// Epoch seconds when the subscription expires (null for lifetime).
  IntColumn get subscriptionExpiresAt => integer().nullable()();

  /// Epoch seconds when this state was last verified with the store.
  IntColumn get lastVerifiedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

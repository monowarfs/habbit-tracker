# Implementation Plan: Lifetime Unlock / Pricing Tier

**Spec:** `07-lifetime-unlock-pricing-tier-design.md`
**Complexity:** S · **Estimated effort:** 2-3 days
**Depends on:** None (foundational — implement alongside spec 06)

---

## Task 1: Add `premium_entitlements` Drift table

**File:** `lib/core/database/app_database.dart`

Create `lib/core/premium/entitlement_table.dart`:

```dart
class PremiumEntitlements extends Table {
  TextColumn get id => text()();
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
  TextColumn get entitlementSource => text().nullable()();
  IntColumn get subscriptionExpiresAt => integer().nullable()();
  IntColumn get lastVerifiedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}
```

Add to `AppDatabase`'s table list.

---

## Task 2: Create `EntitlementService`

**File:** `lib/core/premium/entitlement_service.dart`

```dart
class EntitlementService {
  final AppDatabase db;
  final PurchaserInfo _purchaserInfo;

  bool get isPremium => _cachedEntitlement?.isPremium ?? false;
  bool get isLifetime => _cachedEntitlement?.entitlementSource == 'lifetime_purchase';
  bool get isSubscription => _cachedEntitlement?.entitlementSource == 'subscription';

  Future<void> initialize() async { ... }
  Future<void> verifyWithStore() async { ... }
  Future<void> onPurchaseCompleted(PurchaseDetails details) async { ... }
  Future<void> restorePurchases() async { ... }
}
```

Uses the `in_app_purchase` package for platform billing.

---

## Task 3: Create entitlement Riverpod provider

**File:** `lib/core/premium/entitlement_provider.dart`

```dart
@Riverpod(keepAlive: true)
class EntitlementNotifier extends _$EntitlementNotifier {
  @override
  bool build() => false; // default: not premium

  Future<void> checkEntitlement() async { ... }
  void setPremium(bool value) { state = value; }
}
```

---

## Task 4: Create `PremiumGateWidget`

**File:** `lib/core/premium/premium_gate_widget.dart`

A reusable wrapper widget:
```dart
class PremiumGateWidget extends ConsumerWidget {
  final Widget child;
  final Widget? lockedChild; // shown when not premium

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(entitlementProvider)) return child;
    return lockedChild ?? _DefaultLockedCTA();
  }
}
```

---

## Task 5: Create purchase screen

**File:** `lib/core/premium/purchase_screen.dart`

UI with:
- Feature list (what premium includes).
- Monthly subscription option with price.
- Lifetime purchase option with price.
- "Restore Purchase" button.
- Terms/privacy links.

---

## Task 6: Configure platform billing

**iOS (App Store Connect):**
- Create subscription product (monthly).
- Create non-consumable product (lifetime).
- Configure receipt validation.

**Android (Play Console):**
- Create subscription product (monthly).
- Create one-time product (lifetime).
- Configure Google Play Billing Library.

---

## Task 7: Wire entitlement check on app launch

**File:** `lib/main.dart`

On app startup, call `EntitlementService.verifyWithStore()` to refresh
the entitlement state from the platform stores. Handle network failures
gracefully (keep current state for up to 7 days).

---

## Task 8: Add purchase screen to settings

**File:** `lib/features/settings/presentation/screens/settings_home_screen.dart`

Update the "Unlocks" tile to navigate to the purchase screen.

---

## Task 9: Add localization strings

en/bn ARB keys for purchase screen text, feature list, prices.

---

## Review checklist

- [ ] Entitlement check works on app launch.
- [ ] Purchase flow completes on both platforms.
- [ ] Restore purchases works after reinstall.
- [ ] Subscription lapse revokes premium at next launch.
- [ ] Network failure during verification keeps current state.
- [ ] `PremiumGateWidget` works correctly.
- [ ] en/bn purchase screen renders correctly.

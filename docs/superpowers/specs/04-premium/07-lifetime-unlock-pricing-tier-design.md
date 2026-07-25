# One-Time "Lifetime Unlock" Pricing Tier

**Category:** Premium · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23 · **Revised:** 2026-07-25
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
This app's personas (per the roadmap/user-stories planning) skew toward
budget-conscious, everyday-device users rather than subscription-heavy
power users. Streaks' own success with lifetime-only pricing (no
subscription at all) suggests a meaningful segment of price-sensitive
users actively prefer paying once over recurring billing, even at a
somewhat higher one-time price point. Offering a lifetime tier alongside
any subscription captures that segment without requiring the whole
premium model to abandon subscription economics for the features that
genuinely need ongoing cost coverage (like sync).

## What stays free vs. what's paywalled
This item isn't a feature itself — it's a pricing structure alternative
for whatever premium features and packs already exist. Nothing new is
paywalled; this changes *how* users pay for what's already premium (icon
packs, additional modules, PDF export, etc.), not *what's* premium.
Ongoing-cost features like multi-device sync may reasonably be excluded
from a lifetime tier or priced differently within it, since sync implies
recurring backend cost regardless of how the user pays.

## Goals
- Offer a single one-time purchase that unlocks some or all premium
  features, as an alternative to subscribing.
- Keep the purchase-state check other premium features gate on agnostic
  to whether the underlying entitlement came from a subscription or a
  lifetime purchase.
- Make the choice between subscription and lifetime clear and simple in
  the purchase UI — not a source of confusion about what's included.

## Non-goals / out of scope
- Not deciding final pricing numbers here — a business/pricing decision,
  not an architecture one.
- Not necessarily including every premium feature in the lifetime tier —
  whether ongoing-cost features (sync) are excluded or price-adjusted is
  an open question below, not assumed either way.
- Not building a tiered-lifetime system (e.g. "lifetime basic" vs.
  "lifetime pro") in this pass — scoped as one lifetime tier.

## Proposed approach (high-level)
Whatever entitlement/purchase-state mechanism gates the first premium
feature (most likely icon packs, being the simplest) should be designed
from the start to represent "premium: yes/no" independent of purchase
type, so a lifetime purchase and a subscription both simply flip the
same entitlement flag. The purchase screen presents both options side by
side (subscribe vs. buy once), using the platform's standard in-app
purchase mechanisms for both a consumable/non-consumable one-time product
and a subscription product.

### Entitlement system design

The entitlement system is the **foundational IAP infrastructure** that
all premium features depend on. It should be designed as a standalone
`core/premium/` package:

```
lib/core/premium/
├── entitlement_service.dart        # checks premium status
├── entitlement_provider.dart       # Riverpod provider wrapping the service
├── purchase_screen.dart            # subscription vs. lifetime UI
└── premium_gate_widget.dart        # reusable lock/CTA widget
```

### Entitlement data model

A new `premium_entitlements` singleton table:

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | always `'singleton'` |
| is_premium | INTEGER (bool) | the single flag all premium gates check |
| entitlement_source | TEXT NULL | `'subscription'` \| `'lifetime_purchase'` \| null |
| subscription_expires_at | INTEGER NULL | UTC; null for lifetime or no subscription |
| last_verified_at | INTEGER | UTC; when the entitlement was last verified with the store |
| created_at, updated_at | INTEGER | |

### Entitlement check flow

```
User taps premium feature
  → premium_gate_widget.dart checks entitlement_service.isPremium
    → if true: allow access
    → if false: show purchase_screen.dart with subscription + lifetime options
```

The check is:
1. **Client-side first:** read `is_premium` from `premium_entitlements`
   for instant UI gating (no network latency).
2. **Server-side verification on app launch:** verify the current
   entitlement with App Store/Play Store receipt validation. Update
   `is_premium` and `subscription_expires_at` if the subscription has
   lapsed.
3. **Grace period:** if receipt verification fails (network error), keep
   the current entitlement state for up to 7 days before revoking —
   avoids punishing users for temporary network issues.

### Purchase screen UI

```
┌─────────────────────────────────────────┐
│  Unlock Premium                         │
│                                         │
│  Get access to:                         │
│  ✦ Advanced themes & icon packs         │
│  ✦ Additional habit modules             │
│  ✦ PDF/CSV report export                │
│  ✦ Extended stats & trends              │
│  ✦ Priority support                     │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  Monthly Subscription           │    │
│  │  $2.99/month                    │    │
│  │  [Subscribe]                    │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  Lifetime Unlock                 │    │
│  │  $29.99 once                    │    │
│  │  [Buy Once]                     │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ✦ Lifetime includes all current and    │
│    future one-time features             │
│  ✦ Sync requires active subscription    │
│                                         │
│  [Restore Purchase]                     │
└─────────────────────────────────────────┘
```

### Purchase restoration

Since the app has no account system, purchase restoration uses the
platform's standard restore flow:
- **iOS:** `SKPaymentQueue.restoreCompletedTransactions()`
- **Android:** `BillingClient.queryPurchasesAsync()`

The "Restore Purchase" button is prominently placed on the purchase
screen and also accessible from Settings → Unlocks. After restoration,
the `premium_entitlements` table is updated to reflect the restored
purchase.

### Sync exclusion from lifetime tier

Multi-device sync (item #2) is explicitly excluded from the lifetime
tier since it implies recurring backend cost. The purchase screen
clearly communicates this distinction:
- Lifetime: one-time features (themes, modules, export, stats, badges)
- Subscription: required for sync (and includes all lifetime features)

This means a lifetime purchaser who also wants sync needs a subscription
— but the subscription price can be lower since they've already paid for
the one-time features.

## Database changes
- New `premium_entitlements` singleton table (see above).
- No changes to existing module tables.

## Dependencies & prerequisites
- IAP configuration only — the platform billing setup (App Store
  Connect/Play Console product definitions) for both a one-time product
  and a subscription product.
- This feature **establishes** the entitlement mechanism — it doesn't
  depend on an existing one. It's the foundational IAP infrastructure.
- Recommended to implement alongside or immediately after icon packs
  (item #6) since icon packs need a premium gate.

## Localization
- Purchase screen text (plan names, prices, feature lists) needs en/bn
  localization.
- Price formatting must respect locale conventions (e.g. "$2.99" vs
  "২.৯৯ ডলার").
- "Restore Purchase" button label needs localization.

## Edge cases & error handling
- **Subscription lapses:** the entitlement check on app launch detects
  the lapse and sets `is_premium = false`. The user loses access to
  premium features at the next app launch (not mid-session, to avoid
  disrupting an in-progress action).
- **Network failure during purchase:** the platform's own purchase flow
  handles retries; the app should not interfere with that.
- **Duplicate purchases:** the platform prevents this at the billing
  level; the app simply updates `premium_entitlements` with the latest
  purchase info.
- **Purchase on one device, use on another:** without an account system,
  each device needs its own purchase or a restore. This is standard
  behavior for non-account-based apps.

## Open questions for the implementation round
- Does the lifetime tier include every current and future premium
  feature, or is sync (an ongoing-cost feature) excluded or priced as a
  separate add-on even for lifetime purchasers? (Answered above: sync
  excluded.)
- What's the lifetime price point relative to N months/years of
  subscription — a business decision to make before implementation, not
  during it.
- How are lifetime purchases restored across devices/reinstalls (standard
  platform purchase-restore flows) given the app has no account system?
  (Answered above: standard platform restore.)

## Effort & sequencing notes
S complexity — almost entirely IAP configuration once any entitlement
check exists; the real prerequisite is that the *first* premium feature's
entitlement model is built generically enough to not care how the user
paid. **Recommended to implement alongside icon packs (item #6) since
both need the IAP infrastructure — building them together avoids building
the entitlement system twice.**

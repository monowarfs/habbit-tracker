# One-Time "Lifetime Unlock" Pricing Tier

**Category:** Premium · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
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

## Dependencies & prerequisites
- IAP configuration only — the platform billing setup (App Store
  Connect/Play Console product definitions) for both a one-time product
  and a subscription product.
- Whatever entitlement-check mechanism the first shipped premium feature
  establishes — this item rides on that, rather than building its own.

## Open questions for the implementation round
- Does the lifetime tier include every current and future premium
  feature, or is sync (an ongoing-cost feature) excluded or priced as a
  separate add-on even for lifetime purchasers?
- What's the lifetime price point relative to N months/years of
  subscription — a business decision to make before implementation, not
  during it.
- How are lifetime purchases restored across devices/reinstalls (standard
  platform purchase-restore flows) given the app has no account system?

## Effort & sequencing notes
S complexity — almost entirely IAP configuration once any entitlement
check exists; the real prerequisite is that the *first* premium feature's
entitlement model is built generically enough to not care how the user
paid. Natural to design at the same time as whichever feature ships the
first paywall, rather than bolted on afterward.

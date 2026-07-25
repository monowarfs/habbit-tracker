# Point-Shop for Cosmetic Unlocks

**Category:** Gamification · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Once a cross-module XP system exists, that XP has no sink beyond leveling
up passively — Habitica's own economy shows that letting players spend
earned currency on cosmetics (themes, icon variants) gives even non-paying
users a visible progression path, rather than every desirable customization
being locked behind a paywall. For an app that likely wants a premium tier
elsewhere, a point-shop for purely cosmetic unlocks keeps the core
experience feeling generous and rewarding effort, while leaving room for a
separate, functionally-differentiated premium offering.

## Goals

- Let users spend accumulated points (drawn from the XP system) on
  cosmetic-only unlocks: themes, icon variants, and similar.
- Keep every shop item purely cosmetic — no functional advantage, so it
  never feels pay-to-win even though nothing is actually purchased with
  real money here.
- Make the shop's inventory extensible so new cosmetic packs can be added
  without reworking the underlying spend/unlock mechanism.

## Non-goals / out of scope

- Real-money purchases — this is an points-for-cosmetics economy, not a
  storefront; monetization is a separate premium-tier concern.
- Functional unlocks (e.g. features, module capabilities) sold through the
  shop — cosmetics only.
- A secondary currency separate from XP — the shop spends the same points
  the XP system already tracks, not a new currency to design and balance.

## Proposed approach (high-level)

This feature is explicitly a consumer of the cross-module XP/level system:
it needs a spendable point balance to exist before a shop makes sense. The
shop itself is a straightforward catalog-and-unlock model — a list of
cosmetic items (new theme variants building on the existing Material 3
theme system's per-module accents, alternate icon sets) each with a point
cost, and a record of which items a given install has unlocked. Spending
points deducts from the same balance the XP system maintains and flips an
item to "owned," after which existing settings/theme selection surfaces
let the user apply it.

## Dependencies & prerequisites

- The cross-module XP/level system (hard dependency — the shop has no
  currency without it).
- A cosmetic asset pack (new theme variants, icon variants) to sell,
  which is separate production work from the shop mechanism itself.
- The existing theme system (light/dark/per-module accents), as the
  integration point for unlocked themes to actually apply.

## Open questions for the implementation round

- Does spending points on cosmetics reduce the "level" the XP system
  displays, or is spendable currency tracked separately from the level
  progress bar (spend vs. lifetime-earned distinction)?
- What's the actual v1 cosmetic catalog — how many themes/icon variants
  are worth producing before this ships?
- Are unlocked cosmetics tied to the device/install (consistent with the
  app's offline-first, no-account model) with no cloud sync, meaning a
  reinstall loses them?
- Should any cosmetics be earned "free" via achievements rather than
  purchasable, to keep the shop from being the only route to
  customization?

## Effort & sequencing notes

Medium — the shop mechanism itself is simple (catalog, balance, unlock
flag) but is entirely blocked on the XP system existing first, and its
real cost is producing the cosmetic asset pack rather than the code.
Sequence strictly after the cross-module XP/level system.

## Database schema

New `shop_unlocks` table:

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | UUID v7 |
| item_id | TEXT | shop catalog item identifier |
| item_type | TEXT | `'palette'` \| `'icon'` \| `'theme'` |
| unlocked_at | INTEGER | UTC |
| created_at | INTEGER | |

XP balance is tracked in Spec 06-gamification/02's `xp_balance` table.
The shop deducts from `total_xp` on purchase — this means spending
reduces the displayed level (level is derived from `total_xp`).

## Localization

New ARB keys (en/bn):
- `shopTitle` — "Point Shop"
- `shopBuyButton` — "Buy for {cost} XP"
- `shopOwnedLabel` — "Owned"
- `shopInsufficientXp` — "Not enough XP ({current}/{needed})"
- Per-item name keys (e.g. `shopItemOceanPalette`).

## Edge cases & error handling

- **Insufficient XP:** show "Not enough XP" with current balance and
  cost displayed. The buy button is disabled, not hidden.
- **Reinstall data loss:** unlocks are device-local (no cloud sync in
  v1). After reinstall, the user must re-purchase with their XP. This
  is consistent with the app's offline-first model.
- **Duplicate purchase:** the `shop_unlocks` table uses `item_id` as a
  unique constraint. Attempting to buy again shows "Already owned."
- **XP goes negative:** not possible — purchase is only allowed when
  `total_xp >= cost`.

## Cross-references

- XP system: Spec 06-gamification/02 (hard dependency).
- Theme system: `lib/core/theme/app_theme.dart`.
- Icon switching: `lib/core/theme/icon_switcher.dart` (if exists).
- Related: Spec 04-premium/06 (icon packs) — the IAP version of
  cosmetic unlocks. The point shop is the free/earned alternative.

## Test strategy

- Unit test: purchase deduction logic.
- Unit test: duplicate purchase prevention.
- Unit test: insufficient XP blocking.
- Widget test: shop catalog display with owned/buyable states.

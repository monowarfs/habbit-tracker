# Icon Packs / Advanced Theming

**Category:** Premium · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
The app already ships a solid Material 3 theme (light/dark/system, teal
seed, per-module accent colors). What it lacks is any personalization
beyond that fixed palette — no alternate app icon, no user-chosen accent.
Streaks and Todoist both monetize exactly this kind of cosmetic
personalization successfully because it's a low-friction, low-risk
purchase: it changes nothing about how the app works, so it's an easy
"yes" for a user who already likes the app and wants to make it feel more
their own.

## What stays free vs. what's paywalled
The existing light/dark/system theme, teal seed color, and all
per-module accent colors stay exactly as they are today, free, for every
user. What's paywalled is a set of alternate app icons and alternate
accent/seed color palettes beyond the current built-in one — pure
cosmetic variety, no data or functional implication whatsoever.

## Goals
- Offer a small set of alternate home-screen app icons, purchasable as an
  IAP.
- Offer alternate color seed/accent palettes beyond the current teal
  default, reusing the existing `ColorScheme.fromSeed` + `ModuleAccents`
  theming approach with a different seed/accent input.
- Keep this entirely cosmetic — no feature, data, or notification
  behavior changes based on which icon/palette is active.

## Non-goals / out of scope
- Not changing the underlying Material 3 theming architecture
  (`AppSemanticColors` extension, bn line-height adjustment) — new
  palettes are new inputs to the same system, not a new system.
- Not supporting fully custom user-picked colors (a color wheel) in this
  pass — a curated set of alternate palettes, not infinite customization.
- Not touching per-module accent *logic* (which module gets which
  accent) — only the palette options available to choose from.

## Proposed approach (high-level)
Extend the existing theme system with a small, curated set of alternate
seed colors and accent sets, selectable from Settings, gated behind a
purchase. App icon alternates use the platform's standard alternate-icon
mechanism (configured at build time, toggled at runtime), which is
additive to the existing icon setup rather than a replacement of it. No
new architecture is needed — this is entirely new *content* (icon
assets, palette definitions) flowing through theme/icon mechanisms the
app already has.

## Dependencies & prerequisites
- The existing `app_theme.dart` theming system (seed color,
  `ModuleAccents`, `AppSemanticColors`) as the mechanism new palettes
  plug into.
- A launcher-icon package supporting runtime-alternate icons (e.g.
  `flutter_launcher_icons` alternate-icon configuration) plus platform-
  specific setup (iOS alternate icons, Android activity-alias icons).
- IAP plumbing shared with other premium features.

## Open questions for the implementation round
- How many alternate icons/palettes ship at launch — a handful (3-5) to
  start, or more?
- Are icon packs and palette packs sold together as one purchase or
  separately?
- Does changing the app icon at runtime have any platform quirks worth
  flagging early (Android activity-alias icon changes can briefly kill
  the app process; iOS has its own confirmation dialog)?
- Any interaction with Bangla localization — do alternate icons need
  locale-aware variants, or are they locale-agnostic?

## Effort & sequencing notes
S complexity — the smallest item in this batch; almost entirely asset
work and IAP wiring on top of an already-solid theming foundation. A
reasonable candidate to sequence early precisely because it's cheap and
validates the premium-purchase flow/IAP plumbing other features in this
set will reuse.

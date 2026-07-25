# Icon Packs / Advanced Theming

**Category:** Premium · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23 · **Revised:** 2026-07-25
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
  theming approach (in `core/theme/app_theme.dart`) with a different
  seed/accent input.
- Keep this entirely cosmetic — no feature, data, or notification
  behavior changes based on which icon/palette is active.
- Serve as the **first premium feature to ship**, establishing the
  IAP/entitlement infrastructure that all other premium features reuse.

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

### Palette pack structure

Each palette pack defines:
- A seed `Color` for `ColorScheme.fromSeed`.
- Per-module accent overrides (optional — if not specified, the module
  derives its accent from the seed automatically).
- A pack ID, display name, and preview thumbnail for the purchase UI.

```dart
class PalettePack {
  const PalettePack({
    required this.id,
    required this.displayNameKey, // ARB key for localized name
    required this.seedColor,
    this.moduleAccents = const {}, // moduleId → Color overrides
    required this.previewAsset,    // thumbnail for purchase UI
  });

  final String id;
  final String displayNameKey;
  final Color seedColor;
  final Map<String, Color> moduleAccents;
  final String previewAsset;
}
```

Built-in packs (example set):
1. **Teal** (default, free) — current theme
2. **Ocean** — deep blue seed, cool-toned accents
3. **Sunset** — warm orange seed, warm-toned accents
4. **Forest** — green seed, earthy accents
5. **Midnight** — dark purple seed, moody accents

### App icon alternates

Each icon pack provides alternate launcher icons for both platforms:
- **iOS:** Use `CFBundleAlternateIcons` in `Info.plist` with runtime
  switching via `UIApplication.shared.setAlternateIconName()`. Note: iOS
  shows a confirmation dialog when changing icons — this is standard
  platform behavior, not a bug.
- **Android:** Use activity-alias icon configuration. Runtime switching
  involves enabling/disabling activity-aliases. Note: this can briefly
  kill the app process on some Android versions — the switch should save
  state first and handle the process restart gracefully.

Icon packs are sold together with palette packs as a single IAP, not
separately — keep the purchase decision simple.

### Theme settings UI changes

The existing theme settings screen (`settings/presentation/screens/
theme_settings_screen.dart`) gains a new "Palette" section below the
existing light/dark/system toggle:

```
┌─────────────────────────────────────────┐
│  Theme Mode                             │
│  ○ System  ○ Light  ○ Dark              │
├─────────────────────────────────────────┤
│  Palette                                │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐      │
│  │ Teal│ │Ocean│ │Sunst│ │Fore.│ [Locked│
│  │  ✓  │ │     │ │     │ │     │  icons]│
│  └─────┘ └─────┘ └─────┘ └─────┘      │
│  [More palettes →] (premium gate)       │
├─────────────────────────────────────────┤
│  App Icon                               │
│  [Default] [Ocean] [Sunset] [Forest]    │
│  (premium gate for non-default)         │
└─────────────────────────────────────────┘
```

### Active palette storage

The selected palette ID is stored in `app_settings` (new column
`active_palette_id TEXT`, default `'teal'`). This avoids a separate
settings table for what's fundamentally a display preference.

## Database changes
- `app_settings` gains `active_palette_id TEXT` column (default
  `'teal'`).
- No other new tables — palette definitions are in-code constants, not
  database rows.

## Dependencies & prerequisites
- The existing `app_theme.dart` theming system (seed color,
  `ModuleAccents`, `AppSemanticColors`) as the mechanism new palettes
  plug into.
- A launcher-icon package supporting runtime-alternate icons (e.g.
  `flutter_launcher_icons` alternate-icon configuration) plus platform-
  specific setup (iOS alternate icons, Android activity-alias icons).
- Entitlement/IAP infrastructure (spec 07) — this feature establishes
  the first premium gate, but the entitlement system itself is defined
  in spec 07. Implement these two specs together to avoid building
  the entitlement system twice.
- App icon assets for each pack (design cost, not engineering).

## Localization
- Palette pack names need en/bn ARB keys (e.g. "Ocean", "সমুদ্র").
- The "Upgrade to unlock" CTA needs localization.
- Palette descriptions (if any) need localization.

## Edge cases & error handling
- **Android icon switch process kill:** save active palette to
  `app_settings` before the switch; on process restart, the app reads
  the saved palette and applies it — no visible disruption.
- **iOS icon switch confirmation dialog:** this is standard platform
  behavior; no override needed.
- **Palette preview rendering:** each palette pack's preview thumbnail
  should be a static asset, not a live render, to avoid performance
  issues in the settings scroll.
- **IAP restore after reinstall:** the active palette ID is lost on
  reinstall (it's in `app_settings` which is in the Drift DB). The
  palette selector should show all palettes the user has purchased
  (via IAP restore) and re-apply the default if none is selected.

## Open questions for the implementation round
- How many alternate icons/palettes ship at launch — a handful (3-5) to
  start, or more?
- Are icon packs and palette packs sold together as one purchase or
  separately?
- Any interaction with Bangla localization — do alternate icons need
  locale-aware variants, or are they locale-agnostic?
- Should the default teal palette always be available even if the user
  has purchased other packs? (Recommended: yes.)

## Effort & sequencing notes
S complexity — the smallest item in this batch; almost entirely asset
work and IAP wiring on top of an already-solid theming foundation. A
reasonable candidate to sequence early precisely because it's cheap and
validates the premium-purchase flow/IAP plumbing other features in this
set will reuse. **Recommended as the first premium feature to implement
since it establishes the entitlement infrastructure.**

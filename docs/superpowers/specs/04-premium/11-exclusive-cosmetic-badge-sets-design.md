# Exclusive Cosmetic Badge Sets

**Category:** Premium · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23 · **Revised:** 2026-07-25
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
The achievements engine and badge gallery already exist (Run 15) —
achievements are evaluated from each module's own write path and unlock
via a snackbar, not a modal. What's missing is any cosmetic variety in
how an unlocked achievement actually looks. Habitica's own cosmetics
model is the direct inspiration here: purely decorative purchases that
never touch gameplay/functional balance, keeping the free achievement
system entirely fair while still giving purchasing users a way to make
their unlocked badges feel more personal.

## What stays free vs. what's paywalled
Every existing achievement — its unlock criteria, when it fires, and its
default badge appearance — stays exactly as it is today, free, for every
user. Nothing about earning achievements or which achievements exist is
gated. What's paywalled is purely cosmetic: alternate visual skins for
already-unlocked badges (e.g. a different art style or color treatment
applied to the same badge gallery), never a shortcut to unlocking
anything or a functional advantage.

## Goals
- Offer alternate visual badge skins, purchasable as an IAP, applied
  across the existing badge gallery.
- Guarantee zero effect on achievement unlock criteria, timing, or
  difficulty — a purely visual layer on top of the existing engine.
- Keep the free achievement system exactly as fair and complete as it is
  today — this is Habitica's own stated design principle for cosmetics
  and should carry over directly.

## Non-goals / out of scope
- Not changing the achievements engine's unlock logic, evaluation
  triggers, or the snackbar-not-modal unlock UX established in Run 15 —
  this is a rendering-layer addition only.
- Not adding new achievements as part of this feature — badge skins
  apply to whatever achievement set already exists or is added later
  through the normal achievements-engine path.
- Not building user-uploaded/custom badge art in this pass — a curated
  set of alternate skins, not an open customization system.

## Proposed approach (high-level)
Add an alternate-asset-pack layer to the existing badge gallery: instead
of the achievement repository or engine changing at all, the gallery's
rendering code would look up which skin is active (default vs. a
purchased pack) and swap the badge artwork/color treatment accordingly
per achievement. Because achievement unlock state already lives entirely
in the achievements engine/repository, cosmetic skins are additive
presentation-only content — a purchased skin pack is just an alternate
asset set the gallery screen selects between, with no new fields needed
on the achievement data itself beyond perhaps which skin is currently
active (a simple settings-level preference).

### Skin pack structure

Each skin pack defines:
- A pack ID, display name, and preview thumbnail.
- A map of achievement key → alternate asset/color treatment.
- Not every achievement needs a custom skin — achievements without a
  skin-specific asset fall back to their default appearance.

```dart
class BadgeSkinPack {
  const BadgeSkinPack({
    required this.id,
    required this.displayNameKey, // ARB key
    required this.previewAsset,
    required this.badgeSkins,     // achievementKey → skin asset/color
  });

  final String id;
  final String displayNameKey;
  final String previewAsset;
  final Map<String, BadgeSkin> badgeSkins;
}

class BadgeSkin {
  const BadgeSkin({
    this.assetPath,        // override asset image (null = use default icon)
    this.backgroundColor,  // override background color
    this.accentColor,      // override accent/tint color
  });

  final String? assetPath;
  final Color? backgroundColor;
  final Color? accentColor;
}
```

### Badge gallery rendering changes

The existing badge gallery (in `core/achievements/` presentation layer)
currently renders badges with their default icon and colors. The change:

```dart
// Before:
Widget buildBadge(AchievementDefinition achievement) {
  return Icon(achievement.icon, color: defaultColor);
}

// After:
Widget buildBadge(AchievementDefinition achievement, {String? activeSkinId}) {
  final skin = activeSkinId != null
      ? _skinPackFor(activeSkinId).badgeSkins[achievement.key]
      : null;
  if (skin?.assetPath != null) {
    return Image.asset(skin!.assetPath!);
  }
  return Icon(
    achievement.icon,
    color: skin?.accentColor ?? defaultColor,
  );
}
```

### Active skin storage

The active skin pack ID is stored in `app_settings` (new column
`active_badge_skin_id TEXT`, default `'default'`). This is a simple
preference, not per-achievement — the user selects a skin pack and
all badges in that pack apply uniformly.

### Skin pack rendering in gallery

The badge gallery gains a skin pack selector (horizontal pager or
dropdown) at the top, showing:
- "Default" (always available, free)
- Purchased skin packs (gated behind IAP)
- Lock icon on unpurchased packs with a "Get" CTA

### Snackbar unlock notification

When an achievement unlocks, the snackbar shows the badge with the
**active skin** applied — so the unlock moment feels consistent with
the gallery the user has customized. This requires the snackbar
rendering code to read the current skin preference.

## Database changes
- `app_settings` gains `active_badge_skin_id TEXT` column (default
  `'default'`).
- No new tables — skin pack definitions are in-code constants (asset
  paths, color values), not database rows.

## Dependencies & prerequisites
- The existing achievements engine and badge gallery (Run 15) as the
  system this skins on top of, unchanged.
- An asset pack (alternate badge artwork) per skin set — a design/asset
  cost more than an engineering one.
- Entitlement/IAP infrastructure (spec 07) for premium gating. Consider
  bundling this purchase with icon packs (spec 06) since both are
  cosmetic asset-driven purchases — a single "Cosmetics Pack" IAP
  covers themes, icons, and badge skins.

## Localization
- Skin pack names need en/bn ARB keys (e.g. "Golden Edition",
  "সোনালি সংস্করণ").
- "Get" / "Apply" / "Default" labels need localization.
- The "Unlock to use" CTA on unpurchased packs needs localization.

## Edge cases & error handling
- **No achievements unlocked yet:** the badge gallery shows all
  achievements (locked and unlocked) with the active skin applied. This
  lets users preview how skins look before they've earned badges.
- **Skin pack purchase but no achievements unlocked:** the skin applies
  to the gallery, but all badges show as locked. No issue — the skin
  is cosmetic, not functional.
- **IAP restore after reinstall:** the active skin ID is lost (it's in
  `app_settings`). The skin selector should show all purchased packs
  (via IAP restore) and default to `'default'` if none is selected.
- **New achievement added after skin pack purchase:** the new achievement
  uses default appearance unless the skin pack is updated to include it.
  This is a design/asset cost, not an engineering issue.

## Open questions for the implementation round
- Is the active skin a global per-device preference, or could a future
  multi-profile world (item #3) need it per-profile? (Recommendation:
  per-device for now, since it's cosmetic and non-critical.)
- How many skin packs ship at launch, and are they sold individually or
  bundled? (Recommendation: 2-3 packs, bundled with icon packs from
  item #6 since both are cosmetic asset purchases.)
- Does the snackbar unlock notification itself need to reflect the active
  skin, or only the badge gallery screen? (Answered above: yes, the
  snackbar should reflect the active skin for consistency.)

## Effort & sequencing notes
S complexity — purely a presentation-layer addition over an already-
complete achievements engine and gallery; the main cost is asset
production, not engineering. No dependency on other premium items; a
reasonable candidate to bundle into the same IAP-plumbing work as icon
packs (item #6) since both are small, purely cosmetic, asset-driven
purchases. Consider a single "Cosmetics Pack" IAP that includes icon
packs (spec 06), palette packs (spec 06), and badge skin packs
(this spec) — simplifies the purchase decision and increases perceived
value.

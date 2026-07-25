# Implementation Plan: Exclusive Cosmetic Badge Sets

**Spec:** `11-exclusive-cosmetic-badge-sets-design.md`
**Complexity:** S · **Estimated effort:** 2-3 days
**Depends on:** Achievements engine (Run 15), spec 07 (entitlements)

---

## Task 1: Add `active_badge_skin_id` column to `app_settings`

**File:** `lib/core/database/app_database.dart`

Add `active_badge_skin_id TEXT DEFAULT 'default'` column to
`app_settings` via Drift migration.

---

## Task 2: Create skin pack definitions

**File:** `lib/core/achievements/badge_skin_packs.dart`

```dart
const badgeSkinPacks = [
  BadgeSkinPack(
    id: 'default',
    displayNameKey: 'badgeSkinDefault',
    previewAsset: 'assets/badges/default_preview.png',
    badgeSkins: {}, // uses default icons
  ),
  BadgeSkinPack(
    id: 'golden',
    displayNameKey: 'badgeSkinGolden',
    previewAsset: 'assets/badges/golden_preview.png',
    badgeSkins: {
      'water_7_day_streak': BadgeSkin(
        assetPath: 'assets/badges/golden/water_7_day.png',
        accentColor: Color(0xFFFFD700),
      ),
      // ... more skins
    },
  ),
  // ... more packs
];
```

---

## Task 3: Create skin selection provider

**File:** `lib/core/achievements/badge_skin_provider.dart`

Riverpod provider that:
- Reads `active_badge_skin_id` from `app_settings`.
- Returns the corresponding `BadgeSkinPack`.
- Provides `setActiveSkin(String id)` to update.

---

## Task 4: Update badge gallery rendering

**File:** `lib/features/achievements/presentation/widgets/badge_gallery.dart`

Modify badge rendering to check for active skin:
```dart
Widget buildBadge(AchievementDefinition achievement) {
  final skin = activeSkinPack.badgeSkins[achievement.key];
  if (skin?.assetPath != null) {
    return Image.asset(skin!.assetPath!);
  }
  return Icon(
    achievement.icon,
    color: skin?.accentColor ?? defaultColor,
  );
}
```

---

## Task 5: Add skin pack selector to gallery

**File:** `lib/features/achievements/presentation/screens/achievements_screen.dart`

Add a horizontal pager or dropdown at the top showing:
- "Default" (always available).
- Purchased packs (gated behind IAP).
- Lock icon on unpurchased packs with "Get" CTA.

---

## Task 6: Update snackbar unlock notification

**File:** `lib/features/achievements/presentation/widgets/achievement_unlock_snackbar.dart`

Read the active skin preference and apply it to the badge shown in the
unlock snackbar.

---

## Task 7: Create badge skin assets

Prepare alternate badge artwork for each skin pack:
- `assets/badges/golden/water_7_day.png`
- `assets/badges/golden/water_30_day.png`
- etc.

---

## Task 8: Add entitlement gate

Gate skin pack selection behind spec 07's entitlement check. Consider
bundling with icon packs (spec 06) as a single "Cosmetics Pack" IAP.

---

## Task 9: Add localization strings

en/bn ARB keys for skin pack names, "Get" / "Apply" / "Default" labels.

---

## Review checklist

- [ ] Skin switching updates all badges instantly.
- [ ] Default skin always available.
- [ ] Snackbar unlock reflects active skin.
- [ ] Entitlement gate works for non-premium users.
- [ ] IAP restore re-applies purchased skins.
- [ ] New achievements use default skin if not in pack.
- [ ] en/bn skin names render correctly.

# Implementation Plan: Icon Packs / Advanced Theming

**Spec:** `06-icon-packs-advanced-theming-design.md`
**Complexity:** S · **Estimated effort:** 2-3 days
**Depends on:** Spec 07 (entitlements — implement together)

---

## Task 1: Add `active_palette_id` column to `app_settings`

**File:** `lib/core/database/app_database.dart`

Add `active_palette_id TEXT DEFAULT 'teal'` column to the `app_settings`
table via Drift migration.

---

## Task 2: Create palette pack definitions

**File:** `lib/core/theme/palette_packs.dart`

```dart
const palettePacks = [
  PalettePack(
    id: 'teal',
    displayNameKey: 'palettePackTeal',
    seedColor: Color(0xFF009688),
    previewAsset: 'assets/palettes/teal_preview.png',
  ),
  PalettePack(
    id: 'ocean',
    displayNameKey: 'palettePackOcean',
    seedColor: Color(0xFF1565C0),
    moduleAccents: { ... },
    previewAsset: 'assets/palettes/ocean_preview.png',
  ),
  // ... more packs
];
```

---

## Task 3: Create palette selection provider

**File:** `lib/core/theme/palette_provider.dart`

Riverpod provider that:
- Reads `active_palette_id` from `app_settings`.
- Returns the corresponding `PalettePack`.
- Provides `setActivePalette(String id)` to update.

---

## Task 4: Update theme generation

**File:** `lib/core/theme/app_theme.dart`

Modify `ThemeData` generation to use the active palette's seed color
instead of the hardcoded teal. The `ModuleAccents` should merge
palette-specific overrides with defaults.

---

## Task 5: Create icon pack assets

Prepare alternate launcher icon assets for each pack:
- `assets/icons/icon_ocean.png`
- `assets/icons/icon_sunset.png`
- etc.

Configure platform-specific icon metadata:
- **iOS:** Add `CFBundleAlternateIcons` entries in `Info.plist`.
- **Android:** Create activity-alias entries in `AndroidManifest.xml`.

---

## Task 6: Create runtime icon switcher

**File:** `lib/core/theme/icon_switcher.dart`

```dart
class IconSwitcher {
  Future<void> setAlternateIcon(String packId) async {
    if (Platform.isIOS) {
      // Use UIApplication.shared.setAlternateIconName()
    } else if (Platform.isAndroid) {
      // Toggle activity-aliases
    }
  }
}
```

Handle the Android process-kill gracefully by saving state first.

---

## Task 7: Update theme settings screen

**File:** `lib/features/settings/presentation/screens/theme_settings_screen.dart`

Add:
- Palette selector grid (horizontal scroll of palette previews).
- Lock icon on premium palettes.
- App icon selector below palettes.

---

## Task 8: Add entitlement gate

Wire spec 07's entitlement check. Non-default palettes and icons are
premium.

---

## Task 9: Add localization strings

en/bn ARB keys for palette names, "Get" / "Apply" labels.

---

## Task 10: Add palette preview assets

Create preview thumbnail images for each palette pack.

---

## Review checklist

- [ ] Palette switching updates theme instantly.
- [ ] App icon switching works on both platforms.
- [ ] Android process kill on icon switch is handled gracefully.
- [ ] Default teal palette always available.
- [ ] Entitlement gate works for non-premium users.
- [ ] en/bn palette names render correctly.

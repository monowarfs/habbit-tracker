# Implementation Plan: 06 Simple Mode Large-Button Layout

## Overview

- **Spec:** "Simple Mode" Large-Button Layout
- **Complexity:** L
- **Estimated effort:** 3 days
- **Dependencies:** Depends on specs 01 (labeling), 03 (colorblind palette), and 05 (text scaling). Should run before spec 12.
- **Prerequisites:** `AppSettings` entity and `SettingsRepository` already support theme/locale persistence (reuse same pattern).

---

## Implementation Tasks

### Task 1: Add `simpleModeEnabled` to `AppSettings`

**Files to create/modify:**
- `lib/features/settings/domain/entities/app_settings.dart` (modify)
- `lib/core/database/app_database.dart` (modify — add column to `app_settings` table)
- `lib/features/settings/data/repositories/settings_repository_impl.dart` (modify)

**Detailed changes:**
- Add `bool simpleModeEnabled` field to `AppSettings` entity (default: `false`).
- Add `simple_mode_enabled` column to the `app_settings` Drift table in `app_database.dart`.
- Update `SettingsRepositoryImpl` to read/write the new field using the same stream pattern as theme mode and locale.
- Create `simpleModeEnabledProvider` (a `@riverpod` provider) that streams the setting and exposes it as a `bool`.

**Integration:** Follows existing `AppSettings`/`SettingsRepository` pattern exactly. No new persistence layer.

### Task 2: Create Simple Mode layout constants

**Files to create/modify:**
- `lib/core/theme/simple_mode_constants.dart` (new)

**Detailed changes:**
- Define constants for Simple Mode sizing:
  - `simpleModeMinTouchTarget = 48.0` (WCAG 2.5.5).
  - `simpleModeButtonHeight = 64.0`.
  - `simpleModeIconSize = 32.0`.
  - `simpleModeTextScaleMultiplier = 1.2`.
  - `simpleModePadding = EdgeInsets.all(24.0)`.
- These are consumed by Simple Mode layout widgets.

**Integration:** Pure constants file, no dependencies.

### Task 3: Build Dashboard Simple Mode layout

**Files to create/modify:**
- `lib/features/dashboard/presentation/dashboard_screen.dart` (modify)

**Detailed changes:**
- Read `simpleModeEnabledProvider` via `ref.watch`.
- When enabled, replace the multi-column dashboard layout with a single-column layout:
  - Full-width cards for each module.
  - Larger touch targets (48x48 minimum) on all interactive elements.
  - Larger default text (apply `simpleModeTextScaleMultiplier` via `MediaQuery` or `TextTheme`).
- When disabled, render the existing layout unchanged.
- Use a conditional builder pattern (e.g. `if (simpleMode) ...` inside `build()`), not a separate widget class.

**Integration:** Presentation-layer branch only — same data, same controllers, same routes.

### Task 4: Build Water Simple Mode layout

**Files to create/modify:**
- `lib/features/water/presentation/water_home_screen.dart` (modify)

**Detailed changes:**
- When `simpleModeEnabled`:
  - Replace the row of quick-add chips with a single large "Log Water" button (full-width, 64px height).
  - Keep the custom-add flow accessible but with larger touch targets.
  - Single-column layout for today's log list.
- Use `AppLocalizations.of(context).waterSimpleLogButton` for the large button text.

**Integration:** Same data/controller, alternate presentation.

### Task 5: Build Medicine Simple Mode layout

**Files to create/modify:**
- `lib/features/medicine/presentation/medicine_home_screen.dart` (modify)

**Detailed changes:**
- When `simpleModeEnabled`:
  - Dose list renders as full-width cards with oversized "Mark Done" buttons.
  - Single-column layout, no multi-column dose grid.
  - Larger text for medicine names and status labels.
- Use `AppLocalizations.of(context).medicineSimpleDoseDoneButton`.

**Integration:** Same data/controller, alternate presentation.

### Task 6: Build Prayer Simple Mode layout

**Files to create/modify:**
- `lib/features/prayer/presentation/prayer_home_screen.dart` (modify)

**Detailed changes:**
- When `simpleModeEnabled`:
  - Checklist renders as full-width cards with oversized toggle buttons.
  - Single-column layout.
  - Larger text for prayer names and status labels.
- Use `AppLocalizations.of(context).prayerSimpleToggleButton`.

**Integration:** Same data/controller, alternate presentation.

### Task 7: Add Settings toggle

**Files to create/modify:**
- `lib/features/settings/presentation/settings_screen.dart` (modify)

**Detailed changes:**
- Add a `SwitchListTile` near the top of the Settings screen (alongside theme/locale toggles).
- Label: `AppLocalizations.of(context).settingsSimpleModeLabel`.
- Description: `AppLocalizations.of(context).settingsSimpleModeDescription`.
- Toggle updates `simpleModeEnabledProvider` via the settings controller.
- The switch itself must have a `Semantics` label per spec 01 conventions.

**Integration:** Uses existing settings persistence pattern. Toggle is reactive (no app restart needed).

### Task 8: Add ARB keys

**Files to create/modify:**
- `lib/core/l10n/app_en.arb` (modify)
- `lib/core/l10n/app_bn.arb` (modify)

**Detailed changes:**
- Add keys: `settingsSimpleModeLabel`, `settingsSimpleModeDescription`, `settingsSimpleModeToggleHint`, `waterSimpleLogButton`, `medicineSimpleDoseDoneButton`, `prayerSimpleToggleButton`.

**Integration:** Standard `gen_l10n` flow.

### Task 9: Test compound scenarios

**Files to create/modify:**
- `test/accessibility/simple_mode_compound_test.dart` (new)

**Detailed changes:**
- Pump Simple Mode screens at 2.0x text scale and assert no overflow.
- Verify that toggling Simple Mode on/off re-renders correctly without app restart.
- Verify that unconverted modules gracefully fall back to normal layout.

**Integration:** Uses existing module screens with Simple Mode enabled.

---

## Performance Considerations

- **Caching strategy:** `simpleModeEnabledProvider` streams from `SettingsRepository` — same caching as theme mode.
- **Lazy loading:** Simple Mode layouts are conditional branches in existing `build()` methods, not lazy-loaded widgets.
- **Memory efficiency:** No new widgets are created — only layout branches change.

---

## Testing

- `test/features/settings/presentation/simple_mode_toggle_test.dart` — toggle appears, persists, re-renders.
- `test/features/water/presentation/water_simple_mode_test.dart` — single-column large-button layout renders.
- `test/features/medicine/presentation/medicine_simple_mode_test.dart` — dose list with oversized done buttons.
- `test/features/prayer/presentation/prayer_simple_mode_test.dart` — checklist with oversized toggles.
- `test/accessibility/simple_mode_compound_test.dart` — Simple Mode at 2.0x text scale, no overflow.
- Golden tests for each Simple Mode layout at fixed screen size.

---

## Localization

New ARB keys:
```
settingsSimpleModeLabel
settingsSimpleModeDescription
settingsSimpleModeToggleHint
waterSimpleLogButton
medicineSimpleDoseDoneButton
prayerSimpleToggleButton
```

---

## Edge Cases

1. **Toggle not discoverable** — placed prominently in Settings near theme/locale toggles with clear description.
2. **Simple Mode + 200% text scale** — compound effect may still cause overflow; tested in compound scenario tests.
3. **Module with no Simple Mode layout yet** — gracefully falls back to normal layout.
4. **Orientation change** — single-column layout should adapt to landscape or lock to portrait.
5. **Toggle mid-session** — reactive via `appSettingsProvider` stream, no restart needed.

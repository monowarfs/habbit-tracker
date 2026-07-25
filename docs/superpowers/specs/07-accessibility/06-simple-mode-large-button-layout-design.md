# "Simple Mode" Large-Button Layout

**Category:** Accessibility · **Atlas complexity:** L · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is the largest net-new feature in this category. The app's default layouts are dense, multi-column, and sized for an average user — reasonable for most people but a real barrier for an elderly or low-vision user who is also, per this app's offline-first/no-account positioning, likely to be a self-directed non-account-holder without anyone else to configure the app for them. An alternate, single-column, oversized-touch-target layout for the key screens directly serves that persona, in the spirit of senior-focused apps (the GreatCall/Jitterbug class of product) that ship a "simple mode" as a first-class, not bolted-on, option.

## Goals

- Offer an opt-in "Simple Mode" toggle (in Settings) that switches key screens — at minimum the dashboard, and each module's primary log/quick-action screen (Water quick-add, Medicine dose list, Prayer checklist) — to a single-column layout with larger touch targets and larger default text.
- Keep Simple Mode's data and logic identical to normal mode — it's a presentation-layer alternate layout, not a different feature set or a different data model.
- Make the toggle easy to find and easy to reverse from Settings.

## Non-goals / out of scope

- A separate onboarding flow or separate app icon/branding for Simple Mode — it's a layout toggle, not a different app.
- Rebuilding every screen in the app for Simple Mode in the first pass — start with the highest-traffic screens (dashboard + one primary action screen per module) and treat full coverage as a follow-up if adopted.
- Voice-control or other input-method alternatives — Simple Mode is specifically about layout density and touch-target size, not a new input modality.

## Proposed approach (high-level)

Add a `Simple Mode` setting alongside the existing theme/locale settings (same settings-persistence pattern already used for theme mode and locale), and have the key screens branch their layout based on that setting — collapsing multi-column/dense layouts into a single column with larger buttons and text, reusing the same underlying data/controllers each screen already has (this is a presentation swap, not a new domain layer). Where existing widgets already parameterize size (buttons, list tiles), prefer growing those parameters over building all-new Simple-Mode-only widgets; only build a distinct widget where the layout shape itself genuinely differs (e.g. a single big "log now" button replacing a row of quick-add chips). The existing per-module accent colors and `AppSemanticColors` extension should carry over unchanged — Simple Mode changes size and density, not color or branding.

## Dependencies & prerequisites

- Depends on the settings persistence pattern already in place (`AppSettings`/`SettingsRepository`) to add and store the new toggle the same way theme mode and locale are stored today.
- Benefits from items #1 (screen-reader audit) and #5 (text-scaling stress test) being done first, since Simple Mode's larger targets and text should build on layouts that are already known to behave correctly at scale, rather than compounding two unverified assumptions at once.
- Should follow item #3 (colorblind-safe palette) if Simple Mode introduces any new status indicators, so it inherits an already-verified palette instead of a new one.

## Open questions for the implementation round

- Which screens are "key" for a first pass — is dashboard + one screen per module sufficient, or does the persona need the full log-history/stats screens simplified too?
- Does Simple Mode also imply reduced information density (e.g. hiding secondary stats) or purely larger/single-column presentation of the same information?
- Should Simple Mode be a binary global toggle, or could it eventually be scoped per-module (e.g. only Medicine, if that's the module most used by the target persona)? Scope the first version as global unless there's a clear reason not to.

## Effort & sequencing notes

Complexity L — the largest item in this category; touches multiple screens across modules and needs a new settings toggle wired through to layout branching. Sequence after items #1, #3, and #5 (the three audits) so Simple Mode is built on already-verified accessibility foundations rather than needing its own separate audit pass afterward.

## Localization

- New ARB keys needed for Simple Mode UI and settings:
  - `settings_simple_mode_label` — "Simple Mode" / "সিম্পল মোড"
  - `settings_simple_mode_description` — "Larger buttons and simpler layout" / "বড় বোতাম এবং সহজ লেআউট"
  - `settings_simple_mode_toggle_hint` — accessibility hint for the toggle switch.
- Per-module keys for Simple Mode's primary action screens:
  - `water_simple_log_button` — the large "Log Water" button text.
  - `medicine_simple_dose_done_button` — the large "Mark Done" button text.
  - `prayer_simple_toggle_button` — the large "Mark as Done" button text.
- These are new user-facing strings that must be added to both `app_en.arb` and `app_bn.arb`.
- Simple Mode's layout does not introduce new status categories, so the color palette from #3 carries over unchanged; no new color-related localization is needed.
- All Simple Mode screen-reader labels follow #1's established conventions.

## Edge cases & error handling

1. **Toggle not discoverable in Settings** — the Simple Mode toggle must be placed prominently in the Settings screen (near the top, alongside theme/locale toggles) and must have a clear description so a non-technical user understands what it does. The toggle itself needs a `Semantics` label per #1's audit.
2. **Simple Mode + large text scale compound effect** — if a user enables both Simple Mode and 200% OS text scale (from #5), the combined effect could still cause overflow on some screens; verify this compound scenario during testing.
3. **Module with no Simple Mode layout yet** — if a module doesn't have a Simple Mode layout in the first pass, it should gracefully fall back to its normal layout rather than crashing or showing a blank screen; the toggle must not break modules that haven't been converted yet.
4. **Orientation change in Simple Mode** — landscape orientation on a phone may undermine the single-column layout intent; either lock Simple Mode to portrait or ensure the large-button layout adapts gracefully to landscape.
5. **Toggling Simple Mode mid-session** — switching the toggle should immediately re-render affected screens without requiring an app restart; the setting must be reactive (using the existing `appSettingsProvider` stream pattern from `SettingsRepository`).

## Cross-references

- `docs/superpowers/specs/07-accessibility/01-talkback-voiceover-navigation-audit-design.md` — labeling conventions for all Simple Mode buttons/toggles.
- `docs/superpowers/specs/07-accessibility/03-colorblind-safe-streak-heatmap-palette-check-design.md` — Simple Mode inherits the verified color palette.
- `docs/superpowers/specs/07-accessibility/05-dynamic-text-scaling-stress-test-design.md` — Simple Mode layouts must also pass the text-scaling stress test.
- `docs/superpowers/specs/07-accessibility/09-rtl-readiness-structural-audit-design.md` — new Simple Mode layouts must be RTL-ready from the start.
- `lib/features/settings/` — `AppSettings` entity, `SettingsRepository`, `appSettingsProvider` for adding the toggle.
- `lib/core/theme/app_theme.dart` — `AppSemanticColors` carried over to Simple Mode unchanged.
- `lib/features/water/presentation/` — Water quick-add screen for Simple Mode layout.
- `lib/features/medicine/presentation/` — Medicine dose list screen for Simple Mode layout.
- `lib/features/prayer/presentation/` — Prayer checklist screen for Simple Mode layout.

## Test strategy

- **Widget tests**: Create `test/features/settings/presentation/simple_mode_toggle_test.dart` verifying:
  - The toggle appears in Settings and is tappable.
  - Toggling it persists the value to `AppSettings`.
  - Affected screens re-render when the toggle changes.
- **Widget tests per module**: For each module's Simple Mode layout:
  - `test/features/water/presentation/water_simple_mode_test.dart` — verifies the single-column large-button layout renders and the log button is tappable.
  - `test/features/medicine/presentation/medicine_simple_mode_test.dart` — verifies the dose list renders in Simple Mode with oversized done buttons.
  - `test/features/prayer/presentation/prayer_simple_mode_test.dart` — verifies the checklist renders in Simple Mode.
- **Compound scenario tests**: Create `test/accessibility/simple_mode_compound_test.dart` that pumps Simple Mode screens at 2.0x text scale and asserts no overflow.
- **Regression-prevention strategy**: Add a CI check that enumerates all screens with a Simple Mode variant and asserts each variant's primary action button has a minimum touch target size of 48x48 logical pixels (WCAG 2.5.5 target size).
- **Golden tests**: Golden tests for each Simple Mode layout at a fixed screen size to catch layout drift over time.

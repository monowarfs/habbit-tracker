# Dynamic Text Scaling Stress Test

**Category:** Accessibility · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is an audit-and-fix item, not a net-new feature. Android and iOS both let users scale system font size well beyond 100% (up to 200% or more), and this is a common accessibility setting for older users — directly relevant to this app's stated elderly/non-account-holder persona. Nothing in the codebase has been verified against large text scales; every screen across all five modules risks clipped text, overflowing rows, or truncated labels once the OS font scale is pushed to 200%.

## Goals

- Run every screen in every module at 200% OS font scale (and a couple of intermediate steps, e.g. 150%) and catch any clipping, overflow, truncation, or broken layout.
- Fix layouts that break — typically by allowing wrapping/scrolling where a row or fixed-width element previously assumed one line of text, or by letting flexible widgets grow instead of clip.
- Confirm this holds in both light/dark themes and both en/bn locales, since Bangla strings are typically longer and already have a documented line-height adjustment.

## Non-goals / out of scope

- Introducing an in-app font-scale override independent of OS settings — this stress-test only ensures the app *respects* the OS-level `MediaQuery` text scale correctly, it doesn't add a new scaling mechanism.
- Redesigning screens for aesthetics at large scale beyond what's needed to prevent breakage.
- The Simple Mode large-button layout (item #6) — that's a separate, opt-in alternate layout; this item is about the existing default layout surviving scaling.

## Proposed approach (high-level)

Set the OS (or simulator/emulator) accessibility text size to its maximum, then walk every screen across Dashboard, Water, Medicine, Prayer, and Settings the same way item #1's screen-reader audit does, looking specifically for clipped text, overflowing `Row`/`Column` children, and truncated buttons/labels. Where a fixed-size or `Row`-without-`Expanded` layout breaks, the fix is generally to let text wrap, make a container scrollable, or replace a rigid horizontal layout with one that can grow vertically — using Flutter's existing `TextTheme`/`MediaQuery` plumbing that's already in place, not introducing a new text-scaling system. The existing bn line-height adjustment in the theme is a precedent for how these kinds of typography fixes get made centrally rather than per-screen.

## Dependencies & prerequisites

- Depends on all module screens existing in their current form (they do) — this is a verification pass over finished UI, not new screens.
- Best run after item #1 (screen-reader audit) since both audits touch the same screens and can share a single walkthrough pass if scheduled back to back, though they check different things.
- Should be re-run any time a new screen is added by a later feature, since it's a snapshot audit, not an enforced invariant.

## Open questions for the implementation round

- Is there an appetite for a lightweight golden-test or widget-test check at a large `textScaleFactor` to catch regressions automatically, or is this purely a manual audit with fixes?
- Should the 200% target be treated as a hard cap (clip/truncate gracefully beyond it) or does the app need to hold up at even higher OS-permitted scales?
- Are there specific known-risky screens (e.g. dose timeline rows, prayer checklist rows) worth prioritizing first based on how dense their text layout already is?

## Effort & sequencing notes

Complexity M — broad (every screen, both locales, both themes) but mechanically simple fixes once found. Can run independently of the other items in this category, though pairing it with item #1's walkthrough is efficient since both require visiting every screen once.

## Localization

- No new ARB keys are needed — this audit fixes layout breakage from existing strings at large scales, not new strings.
- The existing Bangla line-height adjustment in `lib/core/theme/app_theme.dart` is the precedent for centralized typography fixes; any new scaling fixes should follow the same pattern.
- Verify that Bangla strings (which are typically 20-40% longer than English equivalents) do not cause additional overflow at 200% scale beyond what English strings cause; if they do, the fix should be language-agnostic (wrapping/flexible layout) not per-locale.
- The `textScaleFactor` is read from `MediaQuery.of(context).textScaler` — no locale-specific override is needed; the fix must work for both en and bn simultaneously.

## Edge cases & error handling

1. **Fixed-height `Row` widgets with text children** — the most common breakage pattern; a `Row` containing a label and an icon with no `Flexible`/`Expanded` wrapper will overflow when text wraps at 200%. Fix by wrapping text children in `Flexible` with `overflow: TextOverflow.visible` or by switching to a `Column` layout.
2. **Buttons with hardcoded `minWidth` or `height`** — action buttons (quick-add chips, dose-done buttons, prayer toggle) may have fixed dimensions that don't accommodate scaled text. Allow these to grow vertically using `IntrinsicHeight` or by removing fixed constraints.
3. **Snackbar text overflow** — confirmation snackbar messages may be too long for the screen width at 200% scale in Bangla; ensure snackbars use `SnackBarBehavior.floating` with adequate width constraints or allow multi-line content.
4. **Chart axis labels and legends** — `period_bar_chart.dart`'s axis labels and legend text are rendered by `fl_chart` and may not respect `MediaQuery` text scale automatically; verify these render correctly and, if not, set explicit text styles that scale with the system.
5. **Bottom navigation labels** — the `StatefulShellRoute` bottom-nav labels must not truncate at 200% scale; if they do, consider using `BottomNavigationBarItem` with `label` set to allow wrapping, or increase the bottom-nav height dynamically.

## Cross-references

- `docs/superpowers/specs/07-accessibility/01-talkback-voiceover-navigation-audit-design.md` — shares the same screen walkthrough; schedule back-to-back for efficiency.
- `docs/superpowers/specs/07-accessibility/06-simple-mode-large-button-layout-design.md` — Simple Mode should build on layouts already verified at scale.
- `lib/core/theme/app_theme.dart` — the bn line-height `TextTheme` adjustment is the precedent for centralized typography fixes.
- `lib/core/widgets/charts/period_bar_chart.dart` — chart widget where axis labels may not scale.
- `lib/core/router/app_router.dart` — `StatefulShellRoute` bottom-nav labels.
- `lib/core/l10n/app_bn.arb` — Bangla strings that may be longer and cause additional overflow.

## Test strategy

- **Widget tests**: Create `test/accessibility/text_scaling_stress_test.dart` that uses `MediaQuery(textScaleFactor: 2.0)` (or the newer `TextScaler.linear(2.0)`) to wrap each screen's widget tree and assert no `OverflowError` or `RenderFlex` overflow is thrown. Test at 1.5x and 2.0x:
  - `test/features/dashboard/presentation/dashboard_text_scale_test.dart`
  - `test/features/water/presentation/water_text_scale_test.dart`
  - `test/features/medicine/presentation/medicine_text_scale_test.dart`
  - `test/features/prayer/presentation/prayer_text_scale_test.dart`
  - `test/features/settings/presentation/settings_text_scale_test.dart`
- **Regression-prevention strategy**: Add a shared test helper `test/accessibility/text_scale_test_helper.dart` that takes a `Widget` and pumps it at multiple text scale factors, asserting no overflow. New screens added in future runs should be added to this test suite as a checklist item.
- **Golden tests**: Consider golden tests at 2.0x text scale for the most text-dense screens (dose timeline, prayer checklist) to catch visual regressions in wrapping behavior.
- **Manual audit**: Document findings in `docs/superpowers/specs/07-accessibility/05-text-scaling-results.md` with screenshots at 200% for both en and bn locales, both light and dark themes.

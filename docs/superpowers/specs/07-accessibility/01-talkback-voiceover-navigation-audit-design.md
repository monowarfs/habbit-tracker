# Full TalkBack/VoiceOver Navigation Audit

**Category:** Accessibility · **Atlas complexity:** M · **Retention impact:** High
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is an audit-and-fix item, not a net-new feature. The app already gets some semantics for free from Flutter's Material widgets, but nothing in the codebase has been verified against a real screen reader. `very_good_analysis` and `public_member_api_docs` catch missing doc comments, not missing or wrong `Semantics` labels, bad reading order, or unlabeled icon-only buttons. For a WCAG 2.1 AA baseline this is the single highest-leverage item: every other accessibility feature in this category assumes screens are at least navigable by TalkBack/VoiceOver first.

## Goals

- Walk every screen in every module (Dashboard, Water, Medicine, Prayer, Settings) with TalkBack (Android) and VoiceOver (iOS) turned on and confirm every interactive element is announced, focusable, and actionable in a sensible order.
- Pay special attention to the fl_chart-based stats charts and the history calendar in each module — custom-painted widgets are the most likely to have no semantic tree at all.
- Add or correct `Semantics` labels/hints where default widget behavior is insufficient (icon-only buttons, custom chart painters, calendar day cells, swipe/gesture-only controls).
- Confirm live-region-style announcements (e.g. "goal met", "dose marked done") actually reach the screen reader.

## Non-goals / out of scope

- Building the chart data-table fallback (separate item, #2) — this audit only confirms charts are *labeled*, not that they have a full tabular alternative.
- Keyboard/switch-control focus order (separate item, #10) — this audit is about screen-reader semantics, not physical-keyboard traversal.
- Any new UI or layout changes beyond what's needed to attach or correct semantics.

## Proposed approach (high-level)

Treat this as a per-module checklist run against each of the 5 modules' full screen set (list, add/edit forms, detail, stats, settings), using Flutter's `Semantics` widget and existing accessibility inspector tooling (Android Accessibility Scanner, Xcode Accessibility Inspector) plus manual TalkBack/VoiceOver passes. For each screen: confirm every tappable widget has a label, every image/icon conveys meaning via text (not color/shape alone), and reading order matches visual order. Findings get triaged into quick semantic-label fixes (most of them) versus structural fixes that need real redesign (rare, escalate separately). The `AppSemanticColors` theme extension and existing widget library are the touch points — most fixes will be adding a `Semantics` wrapper or a `label`/`tooltip` argument to an existing widget, not new widgets.

## Dependencies & prerequisites

- Should run after all 5 modules are feature-complete (it already is, per current project state) so the audit doesn't have to repeat mid-module.
- Needs a physical or simulator pass with TalkBack and VoiceOver actually enabled — this can't be done from static code reading alone.
- Benefits from being scheduled before item #2 (chart fallback) and #6 (Simple Mode), since both build on whatever labeling conventions this audit establishes.

## Open questions for the implementation round

- Does the team want a written checklist/rubric (e.g. one row per screen) checked into the repo, or is a one-time audit with fixes sufficient?
- Should custom Semantics ordering use `SemanticsSortKey` anywhere, or is default widget-tree order acceptable everywhere once labels are correct?
- Are there any third-party widgets (beyond fl_chart) in the dependency set that are known to have poor built-in semantics support and need a wrapper?

## Effort & sequencing notes

Complexity M — broad in surface area (every screen, two platforms) but shallow in depth (mostly label additions, not redesign). Do this audit first, before #2 (chart fallback), #6 (Simple Mode), and #12 (onboarding screen-reader check) — all three depend on the labeling conventions and gaps this audit surfaces.

## Localization

- All new `Semantics` labels and hints are user-facing strings that need en/bn ARB keys.
- New keys should follow the existing naming convention in `lib/core/l10n/app_en.arb` and `lib/core/l10n/app_bn.arb` (snake_case with a `semantic_` or `accessibility_` prefix for discoverability).
- Examples of expected new strings per module:
  - **Dashboard**: `semantic_day_completion_indicator`, `semantic_upcoming_strip`, `semantic_quick_actions_section`, `semantic_global_calendar_button`.
  - **Water**: `semantic_water_quick_add_button`, `semantic_water_custom_log_button`, `semantic_water_stats_chart`, `semantic_water_streak_indicator`.
  - **Medicine**: `semantic_medicine_dose_timeline`, `semantic_medicine_dose_done_button`, `semantic_medicine_stock_indicator`, `semantic_medicine_stats_chart`.
  - **Prayer**: `semantic_prayer_checklist_toggle`, `semantic_prayer_qadha_counter`, `semantic_prayer_stats_chart`, `semantic_prayer_settings_section`.
  - **Settings**: `semantic_theme_toggle`, `semantic_locale_toggle`, `semantic_simple_mode_toggle` (if already present).
- All chart summary labels (Water/Medicine/Prayer stats) and calendar day-cell labels must also be localized since they're read aloud by screen readers.
- Use `AppLocalizations.of(context)` for all new semantic labels — never hardcode English strings in `Semantics` widgets.

## Edge cases & error handling

1. **Icon-only buttons without visible text** — any `IconButton` or `Icon`-based tappable must have a `Semantics` label or `tooltip`; the audit should flag every instance and each must be fixed individually.
2. **fl_chart custom painters have no semantic tree** — the chart widgets rendered by `PeriodBarChart` (in `lib/core/widgets/charts/period_bar_chart.dart`) and per-module chart variants will return empty accessibility trees by default; each chart instance needs a summary label wrapping the entire widget.
3. **Calendar day cells in history screens** — per-module history calendars and the dashboard's global month calendar use custom cell renderers that don't inherit default semantics; each cell needs explicit `Semantics` annotation for its date and status.
4. **Live-region announcements not firing** — snackbar confirmations (e.g. "goal met", "dose marked done") must use `SemanticsService.announce()` to push updates to the screen reader; the audit should verify each confirmation path actually triggers an announcement.
5. **Swipe/gesture-only controls** — any gesture-driven interaction (e.g. swipe-to-delete on a dose entry) needs an alternative reachable action or an explicit `Semantics` hint describing the gesture.

## Cross-references

- `docs/superpowers/specs/07-accessibility/02-chart-data-table-fallback-design.md` — builds on this audit's chart labeling results.
- `docs/superpowers/specs/07-accessibility/06-simple-mode-large-button-layout-design.md` — depends on established labeling conventions.
- `docs/superpowers/specs/07-accessibility/10-focus-order-keyboard-navigation-pass-design.md` — complementary audit (physical focus order vs. screen-reader semantics).
- `docs/superpowers/specs/07-accessibility/12-screen-reader-friendly-onboarding-order-design.md` — reuses labeling conventions from this audit.
- `lib/core/widgets/charts/period_bar_chart.dart` — primary chart widget needing semantic labels.
- `lib/core/theme/app_theme.dart` — `AppSemanticColors` extension referenced for status-based labeling.
- `lib/core/l10n/app_en.arb` / `lib/core/l10n/app_bn.arb` — localization source of truth for all new strings.

## Test strategy

- **Widget tests**: For each screen, write a widget test that pumps the screen with `SemanticsBinding.instance.ensureSemantics()` enabled and asserts that all expected semantic labels are present and non-empty. Target files:
  - `test/features/dashboard/presentation/dashboard_semantics_test.dart`
  - `test/features/water/presentation/water_semantics_test.dart`
  - `test/features/medicine/presentation/medicine_semantics_test.dart`
  - `test/features/prayer/presentation/prayer_semantics_test.dart`
  - `test/features/settings/presentation/settings_semantics_test.dart`
- **Regression-prevention strategy**: Add a `test/Accessibility/semantics_coverage_test.dart` that enumerates all routes in `AppRoutes` and verifies each route's top-level widget has at least one `Semantics` node with a non-empty label. Run this in CI on every PR to catch new screens added without accessibility labels.
- **Manual audit checklist**: Create a `docs/superpowers/specs/07-accessibility/01-audit-checklist.md` with a table of every screen × TalkBack/VoiceOver × label present/fixed status, checked into the repo for traceability.
- **Golden tests**: Not applicable for semantic labels (golden tests verify visual rendering, not the accessibility tree).

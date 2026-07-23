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

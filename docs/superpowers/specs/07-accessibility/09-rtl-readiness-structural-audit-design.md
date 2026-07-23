# RTL-Readiness Structural Audit

**Category:** Accessibility · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

This is a preventive audit-and-fix item, not a net-new feature. The app ships en/bn today, both left-to-right, so nothing forces a right-to-left layout bug to surface yet. But `gen_l10n` already supports RTL locales out of the box, and this app's likely next-locale candidates (Arabic, Urdu) are RTL — relevant given the Prayer module's audience overlap with those language communities. Verifying layout mirrors correctly now, while there are only a handful of custom-laid-out screens, is far cheaper than discovering directional bugs across five modules' worth of screens after an Arabic/Urdu locale ships and users start reporting mirrored icons, misaligned rows, and reversed swipe gestures.

## Goals

- Audit every screen for places that hardcode a direction (e.g. `left`/`right` padding, `Alignment.centerLeft`, manually positioned icons) instead of using Flutter's directional equivalents (`start`/`end`, `Alignment.centerStart`), which automatically mirror under `Directionality`.
- Spot-check actual RTL rendering by forcing the app into a pseudo-RTL locale during testing (Flutter supports this without a real RTL ARB file) and looking for mirrored icons that shouldn't mirror (e.g. a play/checkmark icon that should stay pointing the same way) versus text/layout that correctly mirrors.
- Fix any hardcoded-direction usages found, replacing them with directional-agnostic equivalents.

## Non-goals / out of scope

- Actually adding an Arabic or Urdu locale/ARB file — this audit is purely structural readiness, not a new localization.
- Auditing third-party widget RTL behavior beyond what's directly used in this app's screens (e.g. fl_chart's own internal RTL handling is out of scope unless it visibly breaks in the app's specific chart configurations).
- Icon redesign for RTL-specific iconography — flag any icon that needs a direction-aware variant as a finding, don't design the replacement in this pass.

## Proposed approach (high-level)

Force the app into a pseudo-RTL test locale (a standard Flutter debug capability, no new dependency) and walk each module's screens looking specifically for `Directionality`-widget usage gaps: hardcoded `left`/`right` in padding/alignment/positioning where `start`/`end` should be used instead, and any icon or layout element that visually breaks or looks wrong once mirrored. Since gen_l10n itself already handles RTL string direction and font shaping automatically, this audit's job is narrower — catching the app's own custom layout code that assumes LTR, not the localization framework itself. Findings get fixed by swapping hardcoded directional properties for their directional-agnostic Flutter equivalents.

## Dependencies & prerequisites

- Depends on all five modules' screens being feature-complete (they are, aside from Dashboard/Prayer placeholders noted in CLAUDE.md) so the audit covers real, final layouts rather than screens likely to change.
- No new locale or translation work required — this is purely a structural code audit using Flutter's existing RTL-testing support.
- Cheapest to run once per major UI addition rather than only once — flag this as a recurring lightweight check for future screens (Simple Mode in item #6, for instance) rather than a single one-time pass.

## Open questions for the implementation round

- Is there a specific future RTL locale already planned (Arabic vs. Urdu), or should the audit stay locale-agnostic and just verify generic RTL-readiness?
- Should this audit produce a checklist artifact for future screens to be checked against, or is a one-time sweep with fixes sufficient given how few custom-direction layouts likely exist today?
- Does the Prayer module have any direction-sensitive content (e.g. Qibla-related iconography, if any exists) that needs special-case handling beyond generic RTL mirroring?

## Effort & sequencing notes

Complexity S — a structural sweep over existing screens, fixes are typically one-line property swaps. Low urgency (no RTL locale ships today) but cheap to do now; worth doing before item #6 (Simple Mode) adds new layouts that would also need to be RTL-checked separately if this audit is deferred.

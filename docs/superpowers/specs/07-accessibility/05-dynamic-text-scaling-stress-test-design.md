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

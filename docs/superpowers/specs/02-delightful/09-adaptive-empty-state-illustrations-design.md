# Adaptive Empty-State Illustrations Per Module

**Category:** Delightful · **Atlas complexity:** S · **Retention impact:** Low-Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Finch and Streaks both invest visibly in first-run and empty-state
moments — the screen a brand-new user sees before they've logged
anything is disproportionately influential on first impressions, and
right now this app's three modules (Water/Medicine/Prayer) most likely
share one generic empty-state treatment despite each already having its
own distinct accent color via the `AppSemanticColors`/`ModuleAccents`
theme extension. A first-run water screen, medicine screen, and prayer
screen that each look and feel a little different — while staying
visually consistent as a family — reinforces that these are three
purpose-built experiences rather than one generic list view reskinned
three times, at very low implementation cost since the accent-color
infrastructure already exists.

## Goals

- Give each of Water, Medicine, and Prayer's empty states (first-run,
  before any data exists) a distinct illustration or visual treatment in
  that module's own accent color.
- Keep the underlying empty-state widget structure/logic shared — only
  the illustration/art and accent application should differ per module.
- Make the effort proportionate — simple vector illustrations or icon
  compositions, not commissioned custom art requiring an external asset
  pipeline.

## Non-goals / out of scope

- No animated illustrations in v1 (that's a larger, separate investment)
  — static per-module art is enough to start.
- No empty-state redesign for Settings, Dashboard, or Reports — scoped to
  the three habit modules' own primary screens.
- No custom illustration for every possible empty state within a module
  (e.g., Medicine's "no doses today" vs. "no medicines added at all") —
  start with the single most common first-run empty state per module.

## Proposed approach (high-level)

This is a presentation-only change layered on whatever shared empty-state
widget the three modules currently reuse: instead of one generic
illustration/copy combination, the shared widget accepts a per-module
illustration asset (or a simple parametrized vector composition) and
already has access to that module's accent color via the existing theme
extension, so applying module-specific coloring requires no new
plumbing. The illustrations themselves are the actual new work — a
distinct-but-consistent visual motif per module (e.g., a water-drop
motif for Water, a pill/calendar motif for Medicine, a crescent/prayer-
mat motif for Prayer), simple enough to be original vector art or icon
compositions rather than commissioned illustration, keeping the whole
family visually coherent as "the same app's three modules" rather than
three unrelated styles.

## Dependencies & prerequisites

- The existing shared empty-state widget/pattern used across modules.
- The `ModuleAccents`/`AppSemanticColors` theme extension for per-module
  coloring.
- Either a simple in-house vector illustration approach or a licensed/
  free illustration set consistent enough to reskin per module.

## Open questions for the implementation round

- Custom-drawn simple vector art (no new dependency) vs. an illustration
  library/asset pack (new dependency, faster but adds app size, which
  matters for Nusrat's budget-device/limited-storage persona)?
- Does dark mode need a distinct illustration variant, or does the same
  art work with just a color/opacity adjustment?
- Should Bangla and English versions differ at all (e.g., illustrated
  text elements), or is the art purely visual/language-agnostic?
- Is one empty-state illustration per module enough, or do secondary
  empty states (e.g., empty history/stats view) also warrant distinct
  treatment eventually?

## Effort & sequencing notes

Complexity S — mechanically simple (reuses existing theme/widget
infrastructure), with the real cost being illustration production rather
than engineering. No dependency on other atlas items; cheap to schedule
opportunistically whenever illustration assets are ready.

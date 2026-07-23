# Exclusive Cosmetic Badge Sets

**Category:** Premium · **Atlas complexity:** S · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
The achievements engine and badge gallery already exist (Run 15) —
achievements are evaluated from each module's own write path and unlock
via a snackbar, not a modal. What's missing is any cosmetic variety in
how an unlocked achievement actually looks. Habitica's own cosmetics
model is the direct inspiration here: purely decorative purchases that
never touch gameplay/functional balance, keeping the free achievement
system entirely fair while still giving purchasing users a way to make
their unlocked badges feel more personal.

## What stays free vs. what's paywalled
Every existing achievement — its unlock criteria, when it fires, and its
default badge appearance — stays exactly as it is today, free, for every
user. Nothing about earning achievements or which achievements exist is
gated. What's paywalled is purely cosmetic: alternate visual skins for
already-unlocked badges (e.g. a different art style or color treatment
applied to the same badge gallery), never a shortcut to unlocking
anything or a functional advantage.

## Goals
- Offer alternate visual badge skins, purchasable as an IAP, applied
  across the existing badge gallery.
- Guarantee zero effect on achievement unlock criteria, timing, or
  difficulty — a purely visual layer on top of the existing engine.
- Keep the free achievement system exactly as fair and complete as it is
  today — this is Habitica's own stated design principle for cosmetics
  and should carry over directly.

## Non-goals / out of scope
- Not changing the achievements engine's unlock logic, evaluation
  triggers, or the snackbar-not-modal unlock UX established in Run 15 —
  this is a rendering-layer addition only.
- Not adding new achievements as part of this feature — badge skins
  apply to whatever achievement set already exists or is added later
  through the normal achievements-engine path.
- Not building user-uploaded/custom badge art in this pass — a curated
  set of alternate skins, not an open customization system.

## Proposed approach (high-level)
Add an alternate-asset-pack layer to the existing badge gallery: instead
of the achievement repository or engine changing at all, the gallery's
rendering code would look up which skin is active (default vs. a
purchased pack) and swap the badge artwork/color treatment accordingly
per achievement. Because achievement unlock state already lives entirely
in the achievements engine/repository, cosmetic skins are additive
presentation-only content — a purchased skin pack is just an alternate
asset set the gallery screen selects between, with no new fields needed
on the achievement data itself beyond perhaps which skin is currently
active (a simple settings-level preference).

## Dependencies & prerequisites
- The existing achievements engine and badge gallery (Run 15) as the
  system this skins on top of, unchanged.
- An asset pack (alternate badge artwork) per skin set — a design/asset
  cost more than an engineering one.
- IAP/purchase-gating plumbing shared with other premium features.

## Open questions for the implementation round
- Is the active skin a global per-device preference, or could a future
  multi-profile world (item #3) need it per-profile?
- How many skin packs ship at launch, and are they sold individually or
  bundled?
- Does the snackbar unlock notification itself need to reflect the active
  skin, or only the badge gallery screen?

## Effort & sequencing notes
S complexity — purely a presentation-layer addition over an already-
complete achievements engine and gallery; the main cost is asset
production, not engineering. No dependency on other premium items; a
reasonable candidate to bundle into the same IAP-plumbing work as icon
packs (item #6) since both are small, purely cosmetic, asset-driven
purchases.

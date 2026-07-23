# Avatar Customization Unlocked by Streaks

**Category:** Gamification · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Habitica's avatars work because cosmetic pieces are earned through real
play, not bought outright, making a fully-decked-out avatar a visible,
non-pay-to-win status marker of genuine commitment. This app's users
already build real streak lengths across three modules but have no visual
representation of that history anywhere in the app beyond numbers on a
stats screen. Letting streak milestones unlock avatar pieces, worn visibly
on the dashboard, converts an abstract streak length into an identity users
can see and feel proud of every time they open the app.

## Goals

- Unlock cosmetic avatar pieces (e.g. accessories, backgrounds, frames) as
  streak-length milestones are reached, across any module.
- Display the customized avatar prominently on the dashboard as a
  persistent visual reminder of progress.
- Keep unlocks purely tied to genuine streak achievement — no shortcuts.

## Non-goals / out of scope

- Avatar pieces purchasable via the point-shop — these are earned only via
  streak milestones, kept distinct from spendable-point cosmetics so
  streak-based unlocks retain their status-marker meaning.
- A fully modular avatar-building system (many independent slots, complex
  layering) — a simpler curated set of unlockable pieces for v1.
- Social display of avatars (this app has no accounts/social layer today).

## Proposed approach (high-level)

Streak-length milestones are already the trigger mechanism the
achievements engine uses for badges; avatar-piece unlocks are a second
kind of reward attached to the same qualifying events, rather than a new
detection system. Once a piece is unlocked, a settings or dashboard-
adjacent screen lets the user equip it onto a persistent avatar
representation, which the dashboard then renders alongside (or as part of)
its existing day-completion/level display. This is the other feature in
this batch (with the virtual companion) that needs a genuine asset
pipeline — a base avatar plus a library of unlockable pieces — as its
primary cost.

## Dependencies & prerequisites

- The achievements engine, as the trigger for streak-based unlocks.
- An asset pack for the base avatar and each unlockable piece.
- The dashboard, as the surface where the equipped avatar is displayed.

## Open questions for the implementation round

- Is the avatar itself always visible on the dashboard, or does the user
  opt into showing it (some users may prefer a purely data-focused
  dashboard)?
- How many unlockable pieces justify the art investment for v1, and which
  streak thresholds map to which piece?
- Does the avatar's base look overlap with or duplicate the virtual-
  companion feature, and if both ship, do they coexist or should one
  absorb the other?
- Is the avatar per-module (three separate small mascots) or a single
  cross-module identity, consistent with the app's overall framing?

## Effort & sequencing notes

Medium code complexity, but real cost is the asset pack, similar in
shape to the virtual-companion feature. No hard dependency on the XP
system since it can trigger directly off existing streak-length
achievement events, though pairing with XP/levels for a unified
progression story is a reasonable later refinement.

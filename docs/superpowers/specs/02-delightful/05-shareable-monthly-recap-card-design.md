# Shareable Monthly Recap Card

**Category:** Delightful · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity

Spotify Wrapped and Duolingo's shareable milestone cards drive real
organic growth and re-engagement precisely because they turn private
progress into something worth showing someone else, at zero marginal
cost to the app. This app's core positioning — offline-first, no account,
no cloud upload of personal health data — actually makes this feature
land differently than the benchmarks: a locally-rendered image the user
saves or shares from their own camera roll, with nothing ever leaving the
device unless the user themselves chooses to share it, is fully
consistent with the same privacy stance that already differentiates this
app from prior apps both Rafiq and Nusrat abandoned specifically because
of forced accounts and cloud requirements. Reports already computes the
underlying numbers (goal adherence percentages, streak lengths); this
feature is about presentation and export, not new analytics.

## Goals

- Generate a single shareable image summarizing a month's activity across
  the user's enabled modules (e.g., water goal adherence percentage,
  longest prayer streak, medicine adherence rate).
- Render entirely on-device — no network call, no upload, ever.
- Let the user save the image to their device gallery or hand it to the
  OS share sheet (chat apps, etc.) directly.
- Make the card visually distinct and a little celebratory — this is the
  one surface in the app explicitly meant to be shown to someone else.

## Non-goals / out of scope

- No server-side rendering, no cloud template service.
- No forced/automatic sharing or any social feed inside the app itself.
- No historical recap browsing across many past months in v1 — start with
  "current/most recent completed month" only.
- No per-module custom recap card designs in v1 — one shared template
  that pulls whichever modules are enabled.

## Proposed approach (high-level)

The data side is already solved by the Reports module's aggregation logic
(the same month/streak calculations already powering the Reports screen)
— this feature's real work is a rendering step that takes those numbers
and lays them out as a fixed, attractive image, then hands that image to
whatever the app already uses for image export/sharing (or the platform's
native share sheet if nothing exists yet). A reasonable entry point is a
"Share my month" action on the existing Reports screen, since that's
already where the user is looking at exactly this data. The rendering
itself is a bounded, one-off canvas/widget-to-image operation, not an
ongoing feature that needs to sync with anything — generate once, on
demand, from data Reports already has in memory.

## Dependencies & prerequisites

- The Reports module's aggregate month calculations (adherence
  percentages, streak lengths) as the data source.
- A widget-to-image or canvas rendering approach (Flutter has native
  primitives for capturing a widget as an image; may not need a new
  dependency at all).
- OS-level share sheet / save-to-gallery integration (platform channel or
  an already-available plugin, to be confirmed at implementation time).
- Per-module accent colors, if the card is themed to whichever modules
  are enabled.

## Open questions for the implementation round

- Fixed single template for all users, or does the card layout adapt
  based on which modules are enabled (e.g., a 3-module user vs. a
  Water-only user like Nusrat)?
- Does this need a new dependency for image capture/sharing, or can
  Flutter's built-in widget-to-image capability plus an existing plugin
  cover both saving and the OS share sheet?
- Is "monthly" the only cadence, or should a weekly/yearly variant be
  considered later (yearly would pair naturally with the seasonal-theme
  item)?
- Should the card include any personally identifiable info (a display
  name) given it may be shared outside the app, or stay anonymous by
  default?

## Effort & sequencing notes

Complexity M — the numbers already exist via Reports; the new work is
almost entirely a rendering/export pipeline. Natural to sequence after
Reports' month aggregation is confirmed stable, and pairs well with item
12 (seasonal theme accents) if a yearly/festive variant of the recap card
is ever considered, though that's not required for a first version.

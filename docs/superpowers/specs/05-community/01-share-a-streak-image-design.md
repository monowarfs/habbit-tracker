# Share-a-Streak Image

**Category:** Community · **Atlas complexity:** S · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Right now a user's streak lives entirely inside the app — there's no way to show it off. In this market, WhatsApp and Messenger (not Twitter/Instagram) are the dominant sharing surfaces, and a locally-rendered "I hit a 30-day streak" card dropped into a family WhatsApp group is free, organic distribution the app currently has zero mechanism for. This matters most for the streak-motivated persona across Water/Medicine/Prayer, and it's the single lowest-effort community feature on the atlas: no account, no server, no new data model.

## Infrastructure implication
Zero-infra. Everything happens on-device: render an image (or reuse an existing recap-card renderer if one exists), hand it to the OS share sheet. No network call, no account, no backend, nothing to moderate.

## Goals
- Let a user generate a shareable image summarizing a streak/achievement for one module (Water/Medicine/Prayer) or an overall day-completion.
- Invoke the native share sheet so the user picks the destination app themselves (WhatsApp, Messenger, SMS, save-to-gallery, etc.).
- Keep the rendered card visually consistent with the app's existing theme/branding (module accent colors, teal seed).

## Non-goals / out of scope
- No in-app social graph, no "who shared what" tracking, no server-side image generation.
- No automatic/unprompted sharing — this is always a user-initiated action.
- No deep-link attribution in this feature (that's item 02, invite-a-friend).
- Not building a general-purpose image-editor; the card layout is fixed/templated, not customizable pixel-by-pixel.

## Proposed approach (high-level)
Add a share entry point on the relevant stats/achievement surfaces (e.g. Water/Medicine/Prayer stats screens, the Reports screen, achievement unlock moments from `core/achievements`). Render a card widget off-screen (or reuse a recap-card renderer if the codebase already has one from Reports/Achievements work) capturing it to an image file in temp storage, then hand that file to `share_plus`'s share-sheet API. Card content pulls from data already computed by existing streak/aggregation use cases (Water's `CalculateWaterStreakUseCase`, Medicine's adherence calculator, Prayer's streak calculator, or the cross-module `day_status_streaks` reporting logic) — no new domain logic, purely a presentation + export concern.

## Dependencies & prerequisites
- `share_plus` package (not yet a dependency — confirm at implementation time).
- A widget-to-image capture mechanism (Flutter's `RenderRepaintBoundary` is the standard native-first approach; no third-party image-rendering package should be needed).
- Existing streak/adherence calculation use cases per module, plus `core/achievements` and `core/reports` for source data.

## Open questions for the implementation round
- Does a recap-card widget already exist anywhere (Achievements unlock UI, Reports screen) that can be repurposed, or does this need a first one?
- Which entry points get the share button first — all three modules' stats screens, just the Reports screen, or achievement-unlock moments only?
- What's the minimum card design (streak count + module icon + date) vs. a richer one (calendar heatmap, chart snippet)?
- Any localization concern for text baked into the rendered image (en/bn) — does the image need to respect the user's locale/RTL settings?

## Effort & sequencing notes
Small (S). No dependency on any other Community-category feature — this can be scheduled first or independently at any point. The only soft prerequisite is deciding whether a shared recap-card renderer exists or needs to be built once, since item 09 (Ramadan challenge) and general achievement UI could also reuse it.

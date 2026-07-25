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

## Localization

New user-facing strings requiring en/bn ARB keys:

- `shareStreakTitle` — "Share Your Streak" / "আপনার স্ট্রিক শেয়ার করুন"
- `shareStreakSubtitle` — "Create a shareable image" / "শেয়ারযোগ্য ছবি তৈরি করুন"
- `shareStreakWaterLabel` — "Water Streak" / "পানির স্ট্রিক"
- `shareStreakMedicineLabel` — "Medicine Streak" / "ওষুধের স্ট্রিক"
- `shareStreakPrayerLabel` — "Prayer Streak" / "নামাজের স্ট্রিক"
- `shareStreakOverallLabel` — "Overall Streak" / "সামগ্রিক স্ট্রিক"
- `shareStreakDays` — "{count} days" / "{count} দিন"
- `shareStreakShareAction` — "Share" / "শেয়ার করুন"
- `shareStreakSavedToGallery` — "Saved to gallery" / "গ্যালারিতে সংরক্ষিত"

Add these to `lib/core/l10n/app_en.arb` and `lib/core/l10n/app_bn.arb`. The rendered image text must respect the user's locale — RTL for bn, appropriate line-height adjustments per `lib/core/theme/app_theme.dart`'s bn text theme override.

## Edge cases & error handling

1. **Share sheet cancelled by user** — No action needed; treat as a normal dismissal. No error state to surface.
2. **Widget-to-image capture fails** — `RenderRepaintBoundary.toImage()` can throw on low-memory or if the widget is not yet laid out. Catch and surface via a SnackBar using `AppException.unexpected`, logging the cause with `app_logger.dart`'s rotating logger.
3. **No share-capable app installed** — On some stripped-down Android builds, `share_plus` may find no target. Show a fallback "No sharing app available" message (use `AppException.unexpected`).
4. **Streak data is zero or unavailable** — Guard against sharing a card when the user has no meaningful streak to show. Either hide the share entry point or show a friendly empty state with `AppException.validation`.
5. **Image file temp storage full** — Extremely unlikely but possible. `share_plus` will fail; treat as `AppException.unexpected` and show a SnackBar.

## Cross-references

- `docs/superpowers/specs/02-delightful/05-shareable-monthly-recap-card-design.md` — related monthly recap card feature; potential renderer overlap.
- `docs/superpowers/specs/06-gamification/07-milestone-certificate-image-design.md` — milestone certificate shares the widget-to-image pattern.
- `docs/superpowers/specs/05-community/02-invite-a-friend-deep-link-design.md` — shares the `share_plus` dependency.
- `docs/superpowers/specs/05-community/09-ramadan-community-challenge-design.md` — may reuse the card renderer.
- `lib/core/achievements/` — achievement definitions provide unlock data for the card.
- `lib/core/reports/` — `day_status_streaks.dart` and `aggregate_report_usecase.dart` provide source data.
- `lib/core/widgets/charts/period_bar_chart.dart` — reusable chart widget that could be embedded in the card.

## Test strategy

- **Unit tests**: Widget-to-image capture utility (pure mapping from streak data to card content). Mock `share_plus` to verify share invocation with correct file path. Verify locale-aware text rendering (en vs bn).
- **Widget tests**: The shareable card widget renders correctly with mock streak data. Verify module-specific accent colors appear. Test visibility of share button based on streak availability.
- **Golden tests**: Golden images for the rendered card across Water/Medicine/Prayer/Overall variants to catch layout regressions.
- **Test files to create**:
  - `test/features/community/share_streak_image_test.dart`
  - `test/widgets/shareable_card_widget_test.dart`
  - `test/goldens/shareable_card_water_golden.png` (and per-module variants)

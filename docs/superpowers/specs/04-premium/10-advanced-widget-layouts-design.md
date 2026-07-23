# Advanced Widget Layouts

**Category:** Premium · **Atlas complexity:** M · **Retention impact:** Low
**Date:** 2026-07-23
**Status:** Draft — high-level planning (not implementation-ready; re-scope against actual codebase state when scheduled)

## Problem / opportunity
Home-screen widgets already exist (built alongside the Wear OS
complications foundation) — presumably one simple per-module widget
today. Apple Health's widget system shows the appeal of a combined,
resizable dashboard widget that surfaces multiple habits at once without
opening the app. That's meaningfully more engineering (multi-module data
aggregation inside a widget's constrained runtime, resizable layout
variants) than a single-module widget, which is exactly the kind of depth
worth reserving for premium rather than expected as part of the free
baseline.

## What stays free vs. what's paywalled
The existing simple, one-widget-per-module home-screen widgets stay
free exactly as they are today — Water/Medicine/Prayer users keep their
current widget experience with no change or new restriction. What's
paywalled is an advanced, multi-module combined widget (e.g. one widget
showing Water + Medicine + Prayer status together) and resizable/
multiple-layout-size variants of it.

## Goals
- Offer a combined widget surfacing status from more than one module at
  once, for users who want an at-a-glance cross-module view.
- Support multiple widget sizes/layouts (small/medium/large, matching
  platform widget-size conventions) for the combined widget.
- Reuse each module's existing `dashboardSummary()`-equivalent data (the
  same status data already feeding the in-app dashboard) as the combined
  widget's data source — no new per-module summary logic.

## Non-goals / out of scope
- Not changing or removing the existing free per-module widgets — those
  stay as they are.
- Not building fully user-customizable widget layouts (drag-and-drop
  widget building) — a curated set of combined-layout options, not an
  open-ended layout designer.
- Not extending this to Wear OS complications in this pass — scoped to
  home-screen widgets; the existing Wear OS foundation is a separate
  surface.

## Proposed approach (high-level)
Build a new combined-widget variant on top of the existing `home_widget`-
based widget infrastructure, pulling status data from each module the
same way the existing per-module widgets and the in-app dashboard already
do (each module's own summary-producing logic, not new per-module code).
The combined widget needs its own native-side layout work per platform
(Android Glance/App Widget layouts, iOS WidgetKit families) for each
supported size, gated behind the same purchase-state check other premium
features use, likely surfaced as a widget-configuration option the user
picks when adding the widget to their home screen.

## Dependencies & prerequisites
- The existing `home_widget` package integration and the per-module
  widget data pipeline already built for the current simple widgets.
- Each module's existing dashboard-summary-equivalent data — this reuses
  rather than duplicates that.
- Platform-specific advanced widget APIs: Android Glance (or the existing
  App Widget approach, whichever the current simple widgets use) for
  resizable layouts, iOS WidgetKit for equivalent family-size support.
- IAP/purchase-gating plumbing shared with other premium features.

## Open questions for the implementation round
- What widget infrastructure do the existing simple widgets already use
  (App Widget vs. Glance on Android; WidgetKit family support on iOS) —
  this determines how much of the combined widget's plumbing is genuinely
  new versus an extension of the current setup.
- Does the combined widget need live/frequent updates, and if so, does
  that change the existing widget-refresh triggers (app-resume,
  WorkManager) already wired for per-module widgets?
- How is premium-gating enforced at the OS widget level — can a widget
  itself check purchase state, or does the paywall only gate whether the
  combined widget is offered as an option to add?
- Which module combinations are supported — a fixed 3-module layout
  matching today's Water/Medicine/Prayer set, or does this need to
  anticipate the additional-modules pack (item #4) being installed too?

## Effort & sequencing notes
M complexity — the native widget layout work per platform/size is the
main cost; the data-sourcing side reuses existing per-module summary
logic. Worth sequencing after confirming exactly what widget
infrastructure (App Widget/Glance/WidgetKit) the existing simple widgets
already use, since that materially changes how much is new work.

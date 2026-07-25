# Advanced Widget Layouts

**Category:** Premium · **Atlas complexity:** M · **Retention impact:** Low
**Date:** 2026-07-23 · **Revised:** 2026-07-25
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
- Reuse each module's existing `widgetSummary()`-equivalent data (the
  same status data already feeding the in-app dashboard and stored via
  `core/widgets/widget_refresh_helper.dart`) as the combined widget's
  data source — no new per-module summary logic.

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

### Current widget infrastructure analysis

The existing widget setup uses:
- `home_widget` package (imported in `main.dart`)
- `core/widgets/widget_refresh_helper.dart` — saves each module's
  `WidgetSummaryData` to `home_widget`'s shared storage as
  `widget_summary_$moduleId` JSON.
- Each module implements `widgetSummary()` returning a
  `WidgetSummaryData?`.

The combined widget reads from the same `home_widget` shared storage —
no new data pipeline needed. It simply reads multiple module summaries
instead of one.

### Combined widget data format

The combined widget reads these keys from `home_widget` shared storage:
- `widget_summary_water` — Water module summary (already exists)
- `widget_summary_medicine` — Medicine module summary (already exists)
- `widget_summary_prayer` — Prayer module summary (already exists)

If the additional modules pack (item #4) is installed, also:
- `widget_summary_sleep`
- `widget_summary_blood_pressure`
- `widget_summary_mood`
- `widget_summary_exercise`

### Widget size variants

| Size | Modules shown | Layout |
|---|---|---|
| Small (2×2) | 1 module (user's choice) | Single module summary with accent color |
| Medium (4×2) | 2-3 modules | Side-by-side or stacked summaries |
| Large (4×4) | All enabled modules | Grid of module summaries with status indicators |

### Widget layout designs

**Small widget (2×2):**
```
┌──────────────┐
│ 💧 Water     │
│ 1.5L / 2.0L │
│ ████░░ 75%  │
└──────────────┘
```

**Medium widget (4×2):**
```
┌──────────────────────────────────────┐
│ 💧 Water    │ 💊 Medicine │ 🤲 Prayer│
│ 1.5L/2.0L  │ 2/3 done   │ 4/5 done │
│ ████░░ 75% │ ██████ 67%  │ ████ 80% │
└──────────────────────────────────────┘
```

**Large widget (4×4):**
```
┌──────────────────────────────────────┐
│  Habit Tracker          [⚙️]        │
├──────────────────────────────────────┤
│  💧 Water                            │
│  1.5L / 2.0L  ████░░ 75%           │
├──────────────────────────────────────┤
│  💊 Medicine                         │
│  2/3 doses done today               │
│  Next: Metformin at 20:00           │
├──────────────────────────────────────┤
│  🤲 Prayer                           │
│  4/5 prayed · On-time: 85%          │
│  Next: Isha at 21:30                │
└──────────────────────────────────────┘
```

### Platform-specific implementation

**Android:**
- Use Jetpack Glance (or the existing App Widget approach if that's what
  the current widgets use) for the combined widget layouts.
- Glance supports `GlanceAppWidget` with `SizeMode` for responsive
  layouts — one widget class handles all sizes.
- Widget refresh: same triggers as current widgets (app-resume,
  WorkManager periodic, manual refresh via `HomeWidget.updateWidget()`).

**iOS:**
- Use WidgetKit with `TimelineProvider` for the combined widget.
- Support `systemSmall`, `systemMedium`, and `systemLarge` families.
- Widget refresh: same as current — `HomeWidget.updateWidget()` triggers
  a timeline reload.

### Premium gating at widget level

The combined widget is offered as a widget option when the user long-
presses the home screen and selects "Habit Tracker" widgets. The gating
approach:

1. **Widget list filtering:** the combined widget's
   `AppWidgetProviderInfo` metadata is conditionally included in the
   widget manifest based on purchase state. On Android, this means
   registering/unregistering the widget provider dynamically. On iOS,
   the widget intent configuration can include a premium check.

2. **Fallback for ungated access:** if a user somehow adds the widget
   without purchasing (e.g. they purchased, added the widget, then
   subscription lapsed), the widget shows a "Premium required" message
   with a CTA to open the app and resubscribe.

## Database changes
- No new tables — the combined widget reads from `home_widget` shared
  storage, which is populated by the existing `widget_refresh_helper`
  infrastructure.

## Dependencies & prerequisites
- The existing `home_widget` package integration and the per-module
  widget data pipeline already built for the current simple widgets.
- Each module's existing dashboard-summary-equivalent data — this reuses
  rather than duplicates that.
- Platform-specific advanced widget APIs: Android Glance (or the existing
  App Widget approach, whichever the current simple widgets use) for
  resizable layouts, iOS WidgetKit for equivalent family-size support.
- Entitlement/IAP infrastructure (spec 07) for premium gating.

## Localization
- Widget text (module names, status labels) needs en/bn support.
- Widget content is generated natively (not from Flutter's localization
  system), so en/bn strings must be passed through `home_widget` shared
  storage or generated natively on each platform.
- Widget configuration labels ("Choose modules to display") need
  localization.

## Edge cases & error handling
- **No modules have data:** the combined widget shows a "Set up your
  habits" message with a CTA to open the app — same as individual
  widgets today.
- **Only 1 module enabled:** the medium/large widget gracefully
  collapses to show only the enabled module(s), leaving empty space
  rather than showing error states.
- **Widget refresh delay:** `home_widget` has inherent latency (it
  communicates between Flutter and native). The widget should show
  "Last updated: X minutes ago" to set expectations.
- **Premium lapse:** as described above — show "Premium required" in the
  widget rather than crashing or showing stale data.

## Open questions for the implementation round
- What widget infrastructure do the existing simple widgets already use
  (App Widget vs. Glance on Android; WidgetKit family support on iOS) —
  this determines how much of the combined widget's plumbing is genuinely
  new versus an extension of the current setup.
- Does the combined widget need live/frequent updates, and if so, does
  that change the existing widget-refresh triggers (app-resume,
  WorkManager) already wired for per-module widgets?
- Which module combinations are supported — a fixed 3-module layout
  matching today's Water/Medicine/Prayer set, or does this need to
  anticipate the additional-modules pack (item #4) being installed too?

## Effort & sequencing notes
M complexity — the native widget layout work per platform/size is the
main cost; the data-sourcing side reuses existing per-module summary
logic. Worth sequencing after confirming exactly what widget
infrastructure (App Widget/Glance/WidgetKit) the existing simple widgets
already use, since that materially changes how much is new work.

# Wear OS / Apple Watch Complications — Scope & Staging

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

Feature Atlas gap-analysis flags a wrist complication ("3 doses due",
glanceable, no app open) as Must Have, citing Streaks and Apple Health as
prior art. Complexity L, deps "watch companion app, platform channels."

**Data side:** `HabitModule` (`lib/core/modules/habit_module.dart`, Run 15)
already computes most of what a wrist surface would show:
- `dayStatus(DateRange)` — pure, `Ref`-free, per-day
  complete/partial/missed/none + a natural-unit value. Already the source
  Reports/the global calendar read.
- `nextUpcoming(WidgetRef ref)` / `quickActions(WidgetRef ref)` — the
  closest thing to "3 doses due" today. Medicine's `nextUpcoming`
  (`lib/features/medicine/medicine_module.dart:262-280`) filters
  `todaysDoseViewsProvider` for `due`/`upcoming` status and returns the
  *first* match as a `Chip` — a single next item, not a count, and a
  `Widget` that needs a live `WidgetRef`/mounted Flutter widget tree to
  render. Water and Prayer follow the same shape.

Neither is directly reusable off-device: `nextUpcoming`/`quickActions`
require a `Ref` and produce Flutter `Widget`s, and nothing today computes
a raw pending *count* across due items — `nextUpcoming` stops at the first
match. This exact "`Widget`+`Ref` can't survive outside the app process"
problem was already hit and solved once, by the sibling spec
`docs/superpowers/specs/2026-07-21-home-screen-widgets-design.md`, which
adds a `Ref`-free, JSON-able `WidgetSummaryData` for Android/iOS
home-screen widgets — and explicitly lists "Wear OS complications / Apple
Watch" as out of scope, deferred to here.

**Native side — confirmed clean, checked directly:**
- `android/`: no Wear OS Gradle module, no `ComplicationDataSourceService`
  or `TileService`, no `play-services-wearable` dependency. `android/
  app/build.gradle.kts` defines exactly the one `:app` phone module.
- `ios/`: `ios/Runner.xcodeproj` has exactly one `PBXNativeTarget`
  (`Runner`) — no WatchKit extension target, no `WidgetKit`/`ClockKit`
  target.
- `pubspec.yaml`: nothing watch/wear/complication/tile-related in either
  `dependencies:` or `dev_dependencies:`.

This is 100% new native surface area on both platforms, not a Flutter
feature with a thin native shim.

## Design

### Why this isn't a Flutter feature

Flutter doesn't run on watchOS at all, and Wear OS complications run in a
watch-resident process outside Flutter's engine too — one level further
removed than the sibling widgets spec's iOS WidgetKit problem (that's a
separate *process on the same device*; this is a separate *physical
device*). Any wrist surface is native code that (a) runs on the watch,
(b) is driven by the watch OS's own complication/tile scheduler, and
(c) gets data from the phone over a cross-device sync channel, not a
function call. Flutter's role is limited to computing an accurate summary
(mostly already there) and pushing it across whatever sync channel each
platform provides, through one `MethodChannel` at the boundary — mirroring
how `notification_service.dart` is the one file that owns
`flutter_local_notifications` calls today.

### What's reusable vs. new

- **Reusable as-is:** `HabitModule.dayStatus` (pure, `Ref`-free).
- **Reusable pattern, not code:** the sibling widgets spec's
  `WidgetSummaryData` shape + its background-isolate dispatch pattern
  (mirrors `core/notifications/notification_action_handler.dart`'s
  `handleNotificationAction`, which opens its own `AppDatabase()` and
  resolves modules via `buildHabitModules(db)` with no `Ref`). A wearable
  push job needs the exact same "no app process guaranteed alive" handling
  — reuse that pattern rather than inventing a third one.
- **New, but small:** a pending-*count* per module. `nextUpcoming`'s
  existing per-module filters (Medicine: `todaysDoseViewsProvider` where
  status is `due`/`upcoming`; Water: goal-remaining amount; Prayer:
  remaining-today count) already select the right records — they just stop
  at the first one instead of counting. Turning that into a count is a
  few-line addition on top of providers that already exist, not a new
  query.
- **New, large:** literally everything past that count, on both
  platforms — see staging below.

### Staged approach — two independent platform tracks

#### Stage 1 (realistic v1): Android Wear OS tile / complication

Lower lift because Wear OS complications don't require a fully separate,
independently-published watch app:
- A dedicated Wear OS Gradle module (e.g. `:wear`) added to the existing
  Android project, packaged as a "microapp" bundled inside the phone app's
  existing AAB (Play's supported embedded-wear-app packaging) rather than
  a standalone store listing.
- That module hosts a Kotlin `ComplicationDataSourceService` (renders
  "3 doses due" on a watch face) and/or a `TileService` (Wear OS's
  swipe-to surface) — native Kotlin/Compose-for-Wear, no Dart, no Flutter
  engine involved.
- Data reaches the watch via the **Wearable Data Layer API**
  (`DataClient`/`MessageClient`, Google Play Services) — not a phone-side
  `MethodChannel` alone. The phone-side Flutter app needs one
  `MethodChannel` into a small native Kotlin bridge
  (`android/app/src/main/kotlin/dev/shurjomoy/habit_tracker/`) that calls
  `DataClient.putDataItem(...)` whenever a module's summary changes; the
  watch-side `:wear` module listens for that item and refreshes its
  complication/tile.
- Refresh trigger points mirror the sibling widgets spec exactly, no new
  mechanism: after any mutating quick-action, on app foreground resume
  (`HabitTrackerApp.didChangeAppLifecycleState` in `main.dart`), and from
  the existing Android-only WorkManager periodic top-up
  (`core/notifications/notification_workmanager.dart`) — same three call
  sites, one more push added to each.
- Still genuinely new native engineering: a new Gradle module, Wear
  tooling in the build config, the `play-services-wearable` dependency,
  Wear OS emulator/device testing — none of it reachable from existing
  Flutter code.

#### Stage 2 (explicitly deferred, separate larger project): Apple Watch companion app

Categorically bigger — no lighter-weight option exists the way Wear OS's
embedded microapp does:
- Requires a genuinely separate watchOS app target in Xcode (WatchKit, or
  a watchOS 9+ SwiftUI app) with its own `Info.plist`, provisioning
  profile, and — for complications specifically — a `WidgetKit`/`ClockKit`
  extension, all hand-written Swift/SwiftUI. Flutter's engine does not run
  on watchOS at all; this is not a smaller version of the iOS-widget
  problem the sibling spec already flagged as its main complexity driver,
  it's a step beyond it (different OS, different physical device).
- Phone-to-watch sync uses **`WatchConnectivity`** (`WCSession`), not an
  App Group — App Groups only share data between processes on the *same*
  device. Needs `WCSession.updateApplicationContext`/`transferUserInfo`
  calls from a native Swift bridge on the phone side, itself invoked from
  Flutter via a `MethodChannel`.
- Given the size of this alone — a new Xcode target, a full Swift/SwiftUI
  complication UI, `WatchConnectivity` plumbing, and a second binary to
  build/test/version — this spec recommends treating Apple Watch as its
  own follow-up project with its own design spec, not a line item inside
  this one.

### Flutter-side work this spec does scope (benefits both platforms)

1. A pending-count field per module, computed from data each module
   already has (Water: goal-remaining; Medicine: count of doses in
   `due`/`upcoming` state, same statuses `nextUpcoming` already filters
   for; Prayer: count of remaining prayers today).
2. A decision on where that field lives — see Open Questions; likely an
   addition to the sibling widgets spec's `WidgetSummaryData` rather than
   a fourth bespoke summary type.
3. One new `MethodChannel` (Android only, for Stage 1) that Flutter calls
   after computing the summary — one owner, same precedent as
   `notification_service.dart`.

## Out of scope

- Apple Watch companion app / any watchOS code — Stage 2, own future spec.
- Any interactive action from the watch face (e.g. marking a dose done
  from the wrist) — v1 is display-only, matching the atlas's literal ask
  ("glanceable... due"), not an action surface. Interactive is a stage-3
  candidate at best, and would need the Data Layer sync to also flow
  watch → phone, the reverse of Stage 1's direction.
- iOS Lock Screen / StandBy widgets — those live in the iOS WidgetKit
  extension the sibling home-screen-widgets spec already scopes; not
  watchOS, not this spec's concern.
- Wear OS paired to iPhone ("Wear OS companion mode") — not evaluated;
  assumed Android-paired only.

## Global Constraints

- No Dart/Flutter code runs on either watch platform — both are
  native-only surfaces fed by a sync channel, never a Flutter rendering
  target.
- Any new phone-side summary computation reuses each module's existing
  providers (`todaysDoseViewsProvider`, `todaysWaterProgressProvider`,
  Prayer's equivalent) — no duplicate query paths.
- Stage 1 (Android) ships independently of Stage 2 (Apple Watch). This
  spec's Complexity-L estimate, and any implementation plan derived from
  it, should be read as Stage 1 only unless Stage 2 is separately scoped.

## Open Questions

1. **Split into two specs?** Stage 2 is a categorically different, larger
   native project (own Xcode target, own sync mechanism, own test
   surface) — tracking it under this same document risks understating its
   size once someone picks it up. Recommend splitting Android Wear and
   Apple Watch into separate specs before either stage moves past design.
2. Does the pending-count field belong directly on `HabitModule`, or as an
   addition to `WidgetSummaryData` from `docs/superpowers/specs/
   2026-07-21-home-screen-widgets-design.md` (which is sequenced to ship
   first)? Building the wearable surface on that spec's summary
   struct/background-isolate/`onNotificationAction` pattern avoids a
   fourth summary shape, but depends on that spec landing first.
3. Single-module ("3 doses due") vs. a combined cross-module count on the
   wrist face — the atlas item's literal wording is Medicine-specific;
   needs a product decision before Stage 1 design goes further.
4. Wear OS minimum API level / Play Services version floor — its own
   spike, independent of the phone app's existing `minSdk 26` (Wear OS
   devices commonly have a different, often higher, floor).
5. Hardware/QA access — does the team have physical Wear OS and Apple
   Watch devices, or is emulator/simulator parity acceptable? Neither
   platform's complication/tile behavior is fully reliable in emulation
   (background refresh budgets, real Bluetooth pairing behavior for the
   Data Layer API / `WatchConnectivity`).

# Home-Screen Widgets

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

Feature Atlas gap-analysis flags home-screen widgets ("log water or mark a
dose done without opening the app") as Must Have, citing Streaks and Loop
Habit Tracker as prior art. Today every write path — `WaterModule`'s
quick-add chip, `MedicineModule`'s "mark done" chip
(`lib/features/water/water_module.dart`'s and
`lib/features/medicine/medicine_module.dart`'s `quickActions(WidgetRef ref)`)
— requires a `WidgetRef`/`BuildContext`, i.e. the app already open and a
Flutter widget tree mounted. There is no summary data surface a native OS
widget could read, no native widget scaffolding on either platform
(`android/app/src/main/` has no `AppWidgetProvider`, `ios/Runner.xcodeproj`
has exactly one `PBXNativeTarget` — `Runner`, no widget extension target),
and `home_widget` is not in `pubspec.yaml`.

There is one existing precedent worth reusing rather than re-solving: the
notification engine already does headless, `BuildContext`-free action
dispatch from a background isolate
(`core/notifications/notification_action_handler.dart`'s
`handleNotificationAction`, `core/notifications/
notification_background_handler.dart`'s `@pragma('vm:entry-point')` entry
point) by opening a fresh `AppDatabase()`, building modules via
`buildHabitModules(db)` (`core/modules/module_registry.dart`, the ref-free
constructor `main.dart`/the WorkManager callback also use), and calling
`HabitModule.onNotificationAction(sourceId, NotificationActionType.done)`.
A widget tap needs the exact same shape of problem solved: react to a
tap with no app process guaranteed to be alive yet.

## Design

### Scope for v1

Android gets a real interactive widget (log water / mark dose done without
opening the app, matching the ask literally). iOS v1 is a **display +
deep-link** widget: it shows today's summary and tapping it opens the app
already routed to the right screen, same as a notification tap
(`HabitTrackerApp`'s cold-start deep link handling in `main.dart`) — not a
true headless in-widget action. Reasoning is in the iOS section below;
closing that gap needs iOS 17+ App Intents, called out as a v2/open item,
not bundled into this spec's complexity estimate.

### `HabitModule.widgetSummary()` — new contract method

Widgets render outside the Flutter widget tree entirely (native
`RemoteViews` on Android, SwiftUI in a separate process on iOS), so the
existing `dashboardSummary(WidgetRef ref)` / `quickActions(WidgetRef ref)`
— which return `Widget`s and need a live `Ref` — can't be reused directly.
`HabitModule` gains one new method returning plain, JSON-able data instead:

```dart
/// This module's home-screen-widget summary, or `null` if it has nothing
/// worth surfacing (e.g. Water before any goal is set). Ref-free — called
/// from the same background isolate as `onNotificationAction`, not just
/// the foreground.
Future<WidgetSummaryData?> widgetSummary();
```

```dart
@immutable
class WidgetSummaryData {
  const WidgetSummaryData({
    required this.moduleId,
    required this.headline,       // "1250 / 2000 ml", "Vitamin D · due 9:00 AM"
    this.progressFraction,        // 0.0–1.0, null if not applicable (e.g. PRN dose)
    this.primaryActionLabel,      // "+250 ml", "Mark done" — null if nothing to do right now
    this.primaryActionSourceId,   // opaque id passed back into onNotificationAction
    required this.deepLinkRoute,  // tap-to-open fallback, always present
  });
  ...
}
```

Per-module behavior mirrors what `quickActions`/`nextUpcoming` already
compute server-side instead of client-side:
- **Water**: headline from the same `todaysWaterProgressProvider` data
  `dashboardSummary` reads; `primaryActionLabel`/`primaryActionSourceId`
  from `WaterSettings.quickAddAmountsMl.first`, same value
  `WaterModule.onNotificationAction`'s Done branch already defaults to.
- **Medicine**: headline is the next due/upcoming dose's medicine name +
  time (same selection logic as `nextUpcoming`); `primaryActionSourceId` is
  that dose's real id (`dose.id`) — required, since
  `MedicineModule.onNotificationAction` uses `sourceId` as an actual dose
  id for `markDoseDone`, unlike Water's Done handler which ignores it.
  `null` action fields when nothing is due (all doses done, or PRN-only).
- **Prayer**: headline only in v1 (next prayer name + time); no
  `primaryActionLabel` — "mark done" is a checklist toggle keyed by prayer
  name for a specific date, not a single stable action id the way Water's
  quick-add or Medicine's dose-id are, so wiring a real widget action for
  Prayer is deferred (see Open Questions).

### Reusing `onNotificationAction`, not inventing a new action contract

A widget's primary-action tap and a notification's Done button are the
same shape of event: "this module, do the default thing, given an opaque
id." Rather than add `onWidgetAction` alongside `onNotificationAction`,
the widget tap handler calls the **existing** method:

```dart
await module.onNotificationAction(
  sourceId, // WidgetSummaryData.primaryActionSourceId
  NotificationActionType.done,
);
```

This needs a new background entry point mirroring
`notification_background_handler.dart`'s top-level
`@pragma('vm:entry-point')` function, wired through `home_widget`'s
`HomeWidget.registerInteractivityCallback` (Android-only capability — see
below). It opens its own `AppDatabase()` exactly like
`handleNotificationAction`'s `database: null` branch, resolves the module
via `buildHabitModules(db)`, dispatches, recomputes that module's
`widgetSummary()`, writes it back with `HomeWidget.saveWidgetData` +
`HomeWidget.updateWidget()` so the tile reflects the action immediately,
then closes `db`. No new dispatch logic — this is the same lookup loop
`_dispatch` in `notification_action_handler.dart` already does, called
from a different trigger.

### Android implementation

`home_widget` (new dependency, `pubspec.yaml` confirmed clean of it) wraps
most of this:
- A Kotlin class extending the package's `HomeWidgetProvider` in
  `android/app/src/main/kotlin/dev/shurjomoy/habit_tracker/` — thin
  boilerplate, not hand-rolled `AppWidgetProvider` remote-view plumbing.
- `res/xml/water_widget_info.xml` (+ one per widget if more than one
  module ships a widget) declaring size/update-period metadata, and
  `res/layout/water_widget.xml` for the actual `RemoteViews` layout — this
  part is genuinely native (XML layout resources), no Dart involved.
- `AndroidManifest.xml` gains a `<receiver>` entry per widget (same file
  that already has `flutter_local_notifications`' receivers registered —
  precedent for this app having native manifest entries beyond Flutter's
  own).
- Tap-to-log wiring uses `home_widget`'s interactive-widget support
  (`registerInteractivityCallback`, backed by `PendingIntent` broadcasts
  the plugin's own receiver forwards into the Dart background isolate) —
  this is the piece that makes Android's "no app open" ask literally true.
- Refresh piggybacks on the periodic top-up that already exists for
  notifications: `core/notifications/notification_workmanager.dart`'s
  Android-only WorkManager job is the natural place to also call
  `HomeWidget.updateWidget()` for every module with a live widget, no new
  scheduling infrastructure needed.

### iOS implementation

This is **not** achievable in pure Dart and is the main complexity/scope
driver. A WidgetKit widget is a **separate Xcode target** — `ios/
Runner.xcodeproj` today has exactly one native target (`Runner`); shipping
a widget means adding a Widget Extension target with its own `Info.plist`,
provisioning profile, and entitlements file. Concretely:
- A new Swift/SwiftUI `TimelineProvider` + `View` (hand-written Swift, no
  Flutter engine runs inside a widget extension process — Apple's sandbox
  gives it a tight memory ceiling incompatible with embedding Flutter).
  `home_widget`'s iOS support is a thin `HomeWidgetKit` Swift helper for
  reading the shared data, not a widget generator — the SwiftUI layout
  itself is on us.
- An **App Group** entitlement shared between `Runner` and the new
  extension target, since the extension process can't call back into the
  Dart app's `AppDatabase`/Drift at all — it can only read whatever the
  main app last wrote to the shared `UserDefaults(suiteName:)` App Group
  container. `home_widget`'s `HomeWidget.setAppGroupId(...)` on the Dart
  side is what targets that same container from `saveWidgetData`.
- Tapping the widget in v1 uses a deep-link `widgetURL`/Link — opens the
  app via the same URL-scheme mechanism `home_widget` exposes, landing on
  the relevant screen the way a notification tap already does via
  `HabitTrackerApp`'s cold-start deep link. This is genuinely just "open
  the app," not "log without opening" — flagged explicitly rather than
  glossed over.
- **True headless action on iOS requires iOS 17+ App Intents**: a Swift
  `AppIntent` conforming type that runs *in the widget's own process*,
  meaning it cannot call Dart/Drift directly either — it would have to
  write a "pending action" marker into the same App Group container for
  the main app to reconcile next launch/resume, or `home_widget`'s
  interactivity support would need equivalent App Intents plumbing (needs
  a version-compatibility check against whatever `home_widget` release is
  pinned — not confirmed here). This is real, additional Swift work on top
  of the display-only widget, not a checkbox — treated as out of scope for
  v1.

### Data refresh strategy

No polling loop. The widget's cached view is refreshed at the same points
data already changes, reusing existing call sites rather than adding a new
trigger mechanism:
1. **After any mutating action**, in both directions: the foreground
   quick-action chip (`WaterModule`/`MedicineModule`'s `quickActions`
   controller calls) and the widget's own background callback (above) both
   call `HomeWidget.saveWidgetData` + `HomeWidget.updateWidget()`
   immediately after the mutation, the same way
   `handleNotificationAction` re-runs `planAndApplyNotifications` right
   after a Done/Skip today ("conveyor belt" comment in that file).
2. **App foreground resume** — `HabitTrackerApp.didChangeAppLifecycleState`
   in `main.dart` already re-plans notifications on every resume; add a
   sibling call refreshing widget data there, so backgrounding the app
   after logging elsewhere (e.g. via notification action) still syncs the
   tile.
3. **Periodic top-up** — the existing Android-only WorkManager job
   (`notification_workmanager.dart`) gets one more line calling
   `HomeWidget.updateWidget()`; no separate periodic job.

iOS caveat: even with an explicit `WidgetCenter.shared.reloadTimelines()`
call, WidgetKit budgets a limited number of reloads per day system-wide
(on the order of dozens, not unlimited) and iOS decides final timing —
the app can request a refresh, not guarantee one fires instantly. This is
an OS-level constraint, not something this design controls.

### New dependency

`home_widget: ^0.x` (check latest at implementation time) added to
`pubspec.yaml`'s `dependencies:` — confirmed not currently present.

## Out of scope

- iOS App Intents / true headless iOS actions (v2 candidate, see above).
- Prayer module's widget action button (checklist-toggle semantics don't
  map onto a single stable action id the way Water/Medicine do) — Prayer
  gets a display-only widget summary in v1 at most.
- Widget resizing beyond one fixed small size per module.
- Wear OS complications / Apple Watch — home-screen phone widgets only.
- Per-medicine widget instances (one combined "next dose" summary only).

## Open Questions

1. **Which modules ship a widget in v1** — all three (Water, Medicine,
   Prayer display-only) or just Water, given Water's action semantics are
   the simplest (single stable quick-add amount, no per-instance id)?
2. **`home_widget` version** — does the currently-latest release actually
   support Android background interactivity callbacks the way this spec
   assumes? Needs a version-pin spike before implementation starts, not
   assumed from the package's README alone.
3. **iOS v1 scope** — ship the display-only/deep-link widget at all in
   this run, or defer all of iOS until App Intents headless support is
   in scope, given the separate-target/App-Group/Swift work is
   substantial on its own?
4. **App Group identifier** — needs to be decided and reserved in the
   Apple Developer portal ahead of implementation (e.g.
   `group.dev.shurjomoy.habitTracker`), separate from the app's own bundle
   id `dev.shurjomoy.habitTracker`.
5. **Multiple widget sizes** — small-only, or also a medium size showing
   more than one module's summary in one tile?
6. **Medicine's `primaryActionSourceId` staleness** — a widget's cached
   data can be minutes old; if the due dose it names gets marked done
   from inside the app before the widget refreshes, what should the stale
   tap do (no-op via existing dose-status guards, or a "already handled"
   toast)? Worth confirming `markDoseDone`'s existing idempotency covers
   this before assuming it's free.

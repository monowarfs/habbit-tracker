# Android App Shortcuts / iOS Home Screen Quick Actions

**Date:** 2026-07-21
**Status:** Draft — pending review

## Problem

Feature Atlas gap analysis (Must Have, complexity S, inspired by Streaks):
long-pressing the app icon on Android/iOS should surface a small static menu
— "Log water", "Mark dose taken", "Mark prayer" — that jumps straight into
the action without opening the app to the dashboard first. Nothing like
this exists today; the `quick_actions` package is not in `pubspec.yaml`.

## Naming collision — read this first

`HabitModule` already has a method called `quickActions` (added Run 15,
`lib/core/modules/habit_module.dart:231`):

```dart
List<Widget> quickActions(WidgetRef ref);
```

This is the **in-app dashboard's quick-actions row** — each module returns
live `Widget`s (an `ActionChip` wrapped in `Consumer`/`Builder`) that read
current Riverpod state and call a **controller** method when tapped. Water's
implementation (`lib/features/water/water_module.dart:230-248`) is
representative:

```dart
@override
List<Widget> quickActions(WidgetRef ref) {
  final settings = ref.watch(waterSettingsProvider).value;
  if (settings == null || settings.quickAddAmountsMl.isEmpty) return const [];
  final amountMl = settings.quickAddAmountsMl.first;
  return [
    Consumer(
      builder: (context, innerRef, _) => ActionChip(
        avatar: const Icon(Icons.add, size: 16),
        label: Text(formatWaterAmount(context, amountMl, unit)),
        onPressed: () => innerRef
            .read(waterControllerProvider.notifier)
            .logQuickAdd(amountMl),
      ),
    ),
  ];
}
```

Medicine and Prayer are the same shape: watch a live "today" provider, pick
the first actionable item, wrap an `ActionChip` whose `onPressed` calls a
controller method (`medicineControllerProvider.notifier.markDoseDone(...)`,
`prayerControllerProvider.notifier.togglePrayed(...)`).

This feature is a **different, OS-level concept that happens to share the
English phrase "quick actions"**: Android calls them "app shortcuts" (this
package uses Android's *dynamic* shortcuts API — registered at runtime via
`setShortcutItems`, not the XML-declared *static* shortcuts variant), iOS
calls them "Home Screen Quick Actions". Consequences of the collision:

- **`HabitModule.quickActions(WidgetRef ref)` cannot be reused as-is.** It
  returns bound `Widget`s that require a live `WidgetRef` and a
  `BuildContext` (for `AppLocalizations.of(context)` and number formatting).
  OS shortcuts are registered once at startup, before any widget tree
  exists, as plain data (`ShortcutItem(type, localizedTitle, icon)`) — there
  is no `Widget`, no `Ref`, and often no `BuildContext` at registration time.
- **What *is* reusable is the pattern one layer down**: each module's
  `onPressed` closure calls straight into a controller/repository method
  with no other UI dependency (`logQuickAdd(amountMl)`,
  `markDoseDone(doseId)`, `togglePrayed(recordId, ...)`). The OS-shortcut
  handler needs the same kind of headless call, just reached a different
  way (see Design).
- **To avoid the two concepts reading as one thing in code**, this doc calls
  the existing dashboard method "in-app quick actions" and the new feature
  "home screen shortcuts" throughout, and the new code lives under
  `core/shortcuts/`, never `core/quick_actions/` or anything using the
  bare word the plugin itself is named after only in the dependency line.

## Design

### Dependency

Add `quick_actions: ^1.1.0` to `pubspec.yaml` (not present today — verified
against the current dependency list, which has no OS-shortcut integration
of any kind).

### What ships in v1: a fixed, static set — one per module

Per the Atlas note, this is not a dynamic "top N due items" list. OS
shortcut slots are scarce (Android typically allows 4-5, iOS allows 4), and
none of the three modules' "next actionable item" is knowable synchronously
before `runApp` anyway (it requires a DB read). v1 registers exactly **one
static shortcut per module** (3 total), fixed label/icon, chosen once at
startup:

| shortcut `type` | Label (reuses existing l10n keys) | Icon |
|---|---|---|
| `water` | `waterQuickAddAction` (or equivalent existing key) | water drop |
| `medicine` | `medicineMarkDoneAction` | pill/check |
| `prayer` | `prayerMarkPrayedAction` | mosque/check |

The shortcut `type` string is deliberately just the module's existing
`HabitModule.id` (`'water'`/`'medicine'`/`'prayer'`) — no new id scheme,
and it lets dispatch key off `type` the exact same way
`notification_action_handler.dart`'s `_dispatch` already keys off
`moduleId` (see below).

**What each shortcut actually does** is *not* "open the dashboard's
quick-actions row" — it performs one fixed, unconditional action for that
module headlessly (Water: log the first configured quick-add amount;
Medicine: mark the earliest `due` dose done; Prayer: mark the earliest
`due` prayer prayed), matching what today's in-app chip does when it's
visible, minus the "only shown if something is actually due" conditionality
— v1 fires the action regardless and lets each module's own domain logic
no-op or handle the "nothing due" case gracefully (Water always has a
configured amount to log; Medicine/Prayer need a "nothing due, log nothing,
just open the module" fallback — see `onQuickAction` below).

Icons: Android dynamic shortcuts need a drawable resource name (not an
`IconData`); iOS needs either an SF Symbol name or an asset-catalog icon
name. This means new platform icon assets are a real sub-task here, not a
config line — flagged explicitly since it's easy to scope out by accident.

### Registering shortcuts — where and when

`quick_actions`' `QuickActions.initialize(handler)` callback fires for
**both** a shortcut tap that launched the app cold *and* a tap while the
app is already running — unlike `flutter_local_notifications`, which needs
the separate `checkLaunchDeepLink()` cold-start check `main.dart` already
does today (`lib/main.dart:47-48`, backed by
`NotificationService.checkLaunchDeepLink()`,
`lib/core/notifications/notification_service.dart:232-239`). One handler
covers both cases; there is no shortcut equivalent of
`HabitTrackerApp.initialDeepLink`/`initState`'s `addPostFrameCallback` dance
needed for *registering* the callback (though routing the result still
needs the router, see Dispatch below).

`localizedTitle` is a plain, already-resolved string, not a live-localized
OS-level lookup — the same problem `AppSettings.screenPrivacyEnabled` solved
for a different plain-value/no-context setting. Follow that precedent
exactly: register/re-register shortcuts from `HabitTrackerApp.build()`
(`lib/main.dart`) via `ref.listen<Locale>(localeControllerProvider, ...)`,
resolving strings with `lookupAppLocalizations(locale)` (a real top-level
function in the generated l10n file,
`lib/core/l10n/app_localizations.dart:1823` — no `BuildContext` required),
calling `setShortcutItems` once on first build and again on every locale
change. `QuickActions.initialize(handler)` itself is wired once, in
`main()` next to `NotificationBootstrap.init(...)` (`lib/main.dart:44-46`),
since the handler only needs the `container`, not a locale.

### Dispatch — headless, no live `WidgetRef`

New `HabitModule` method, sibling to `onNotificationAction`:

```dart
Future<void> onQuickAction();
```

Each module implements it by doing, headlessly, what its in-app
`quickActions(WidgetRef ref)` closure's `onPressed` does — but hitting the
repository directly instead of a Riverpod controller, exactly the way
`onNotificationAction` already bypasses controllers today (e.g. Medicine's
`onNotificationAction` calls `_repository.markDoseDone(sourceId, ...)`
directly, `lib/features/medicine/medicine_module.dart:193-208`). No new
architectural pattern — same shape, reused:

- **Water**: log `waterSettings.quickAddAmountsMl.first` via
  `_repository.logEntry(...)` (whatever `WaterRepositoryImpl`'s equivalent
  of the controller's `logQuickAdd` calls under the hood).
- **Medicine**: query today's doses, pick the earliest `due` one, call
  `_repository.markDoseDone(doseId, fromOtherSource: false)`; no-op if
  nothing is due.
- **Prayer**: query today's records, pick the earliest `due` one, call the
  repository's toggle-prayed equivalent; no-op if nothing is due.

Top-level dispatcher in a new `lib/core/shortcuts/quick_action_handler.dart`
mirrors `handleNotificationAction`/`_dispatch`
(`lib/core/notifications/notification_action_handler.dart:84-97`) almost
line for line: build modules via `buildHabitModules(db)`, find the one
whose `id == shortcutType`, call `module.onQuickAction()`.

### After the action: navigate

Unlike a notification tap, a shortcut tap has no per-instance
`deepLinkRoute` to decode — but each module already has a stable "open this
module's home" route (the same one its bottom-nav tab uses). After
`onQuickAction()` completes, the handler calls
`container.read(appRouterProvider).go('/<moduleId>')` so the user lands on
the module screen and can see what just happened — same
`container.read(appRouterProvider).go(route)` mechanism `main.dart` already
uses for the notification deep link (`lib/main.dart:45`), reused as-is, no
new router wiring.

### Cold start vs warm start — both go through one path

Because `QuickActions.initialize(handler)`'s callback fires for both cases,
`main()` needs only:

```dart
const QuickActions().initialize((type) async {
  await handleQuickAction(type: type, db: db);
  container.read(appRouterProvider).go('/$type');
});
```

placed next to the existing `NotificationBootstrap.init(...)` call
(`lib/main.dart:44-46`), before `runApp`. No `initialDeepLink`-style
constructor field, no `addPostFrameCallback` — the callback itself already
only fires post-registration, and `initialize` covers the cold-launch case
internally. This is simpler than the notification precedent specifically
*because* the plugin unifies what `flutter_local_notifications` splits into
`checkLaunchDeepLink()` (cold) + `onDidReceiveNotificationResponse` (warm).

## Out of scope

- Dynamic/conditional shortcuts (e.g. hiding the Medicine shortcut when
  nothing is due, or showing a specific dose name) — v1 is a fixed static
  set of 3, per the Atlas complexity-S scope. Revisit only if user feedback
  asks for it; would require re-calling `setShortcutItems` from the same
  app-resume trigger `planAndApplyNotifications` already uses
  (`lib/main.dart:104-108`), not new plumbing.
- Actual icon asset creation (Android drawable / iOS asset catalog) is
  flagged as needed but not designed here — a design/asset task, not an
  architecture one.
- Prayer's/Medicine's "nothing due" UX (silently no-op vs. showing a toast)
  — left to whoever implements, not an architectural decision.
- Any change to `HabitModule.quickActions(WidgetRef ref)` (the existing
  in-app dashboard row) — untouched by this feature.
- watchOS/Android widget-based launchers — out of scope, home screen
  long-press shortcuts only.

## Global constraints

- New dependency: `quick_actions` (pubspec.yaml).
- New `HabitModule` method: `Future<void> onQuickAction();` — implemented
  by Water/Medicine/Prayer, headless (no `Ref`), same constraint
  `onNotificationAction` already documents on the interface.
- New file: `lib/core/shortcuts/quick_action_handler.dart` (dispatcher,
  mirrors `notification_action_handler.dart`'s `_dispatch`).
- Shortcut `type` strings are exactly the existing `HabitModule.id` values
  (`'water'`, `'medicine'`, `'prayer'`) — no separate id scheme.
- Exactly 3 static shortcuts registered, one per module, no dynamic
  content.
- `QuickActions.initialize(...)` wired in `main()` next to
  `NotificationBootstrap.init(...)`; `setShortcutItems(...)` (re-)called
  from `HabitTrackerApp.build()`'s existing `ref.listen` block area
  (alongside the `screenPrivacyEnabled` listener), keyed off
  `localeControllerProvider` so shortcut labels stay in the user's chosen
  language.

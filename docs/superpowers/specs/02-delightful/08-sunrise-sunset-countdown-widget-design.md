# Sunrise/Sunset Countdown Widget for Next Prayer

**Category:** Delightful · **Atlas complexity:** M · **Retention impact:** Medium
**Date:** 2026-07-23
**Status:** Draft — implementation-ready

## Problem

The existing home-widget foundation is real but narrower than "widgets
+wearable already shipped" suggests at a glance — grepping the actual
platform code changes the scope of this feature materially:

- **Only Water has a shipped widget today, and it's Android-only.**
  `android/app/src/main/kotlin/dev/shurjomoy/habit_tracker
  /HabitWidgetProvider.kt`'s `getModuleId()` (lines 78-82) is hardcoded:
  `return "water"` with a comment "Default to 'water' for single-widget
  setups." There is exactly one widget descriptor,
  `android/app/src/main/res/xml/water_widget_info.xml`, and no Medicine or
  Prayer equivalent XML/provider exists anywhere in `android/`. On iOS,
  `find ios -iname "*widget*"` turns up nothing beyond the standard
  `Runner` Xcode project — **no WidgetKit extension target exists at
  all**. `home_widget`'s Flutter-side plumbing
  (`lib/core/widgets/widget_refresh_helper.dart`,
  `HomeWidget.saveWidgetData`/`updateWidget`/`registerInteractivityCallback`
  in `lib/main.dart:71-77`) is genuinely platform-generic and already
  calls every module's `widgetSummary()` (`lib/core/modules/habit_module
  .dart`'s contract; `WaterModule.widgetSummary()` at `water_module.dart
  :423-450`, `PrayerModule.widgetSummary()` at `prayer_module.dart
  :472-515`), but nothing on the native iOS side is there to render it,
  and nothing on the native Android side renders anything but the one
  hardcoded Water tile. A Prayer countdown widget needs **new native
  code on both platforms**, not just a new Dart-side data shape — this
  is the single most important scoping correction from the original
  high-level draft.
- **The refresh cadence is not what "live" implies.**
  `water_widget_info.xml`'s `android:updatePeriodMillis="1800000"` (30
  minutes — already effectively the practical floor; Android silently
  clamps anything under ~30 min) is the OS-driven `onUpdate()` tick.
  Actual pushes of fresh data happen via
  `HomeWidget.saveWidgetData`+`updateWidget()` calls from
  `refreshWidgetsForModule`/`refreshAllWidgets`
  (`widget_refresh_helper.dart:17-62`), triggered from: app-resume, any
  mutating action's post-write hook, and Android's WorkManager top-up
  which runs **every 8 hours**
  (`lib/core/notifications/notification_workmanager.dart:36-41`,
  `frequency: const Duration(hours: 8)`, deliberately **not registered on
  iOS** at all per that file's own comment, lines 12-16). So on Android,
  a countdown tile is realistically accurate to within "however long
  since the user last opened the app or the 8-hour tick last fired" —
  not the 30-min widget-system floor even, since nothing currently forces
  a refresh call every 30 minutes; on iOS there is no periodic refresh
  mechanism whatsoever today. **A literal ticking "42 min" that
  decrements itself is not achievable through `home_widget`'s Flutter-side
  API on either platform** — that requires each platform's own
  native timeline/scheduling primitive (Android Glance's
  `GlanceAppWidget` + `PeriodicWorkRequest` chaining down to ~15 min at
  best, or iOS WidgetKit's `TimelineProvider`/`TimelineEntry` array,
  which *can* pre-compute several future entries so the OS renders
  "42 min" → "41 min" → … locally without round-tripping to the app —
  neither of which any current file in this repo implements).
- **The domain data already exists and needs no new calculation.**
  `calculatePrayerTimes()` (`lib/features/prayer/domain/usecases
  /calculate_prayer_times.dart:24-63`) returns all five UTC instants for a
  given day/location/method. `PrayerModule.widgetSummary()`
  (`prayer_module.dart:472-515`) already derives "first pending prayer +
  its scheduled time" via `effectivePrayerStatus`/`cutoffForPrayer`
  (imported at lines 19-20) for its existing (currently Water-only-shipped)
  widget summary shape — the derivation this feature needs is a strict
  subset of logic Prayer's own module file already runs every refresh.

## Design

### 1. Data: extend `WidgetSummaryData`, no new domain calculation

`PrayerModule.widgetSummary()` (`prayer_module.dart:472-515`) already
computes `firstPending` (a `PrayerRecord`) and formats `label · timeStr`.
Add one field to the existing shared shape
(`lib/core/widgets/widget_summary_data.dart:8-76`) rather than a
parallel type:

```dart
/// Countdown target instant for a "next X in Y" tile (UTC). `null` for
/// modules with no countdown concept (Water/Medicine today).
final DateTime? countdownTargetAt;
```
(added to the constructor, `toJson()`/`fromJson()`/`toRawJson()`, same
pattern as every other field — a ~6-line diff, not a new class).
`PrayerModule.widgetSummary()` sets `countdownTargetAt:
firstPending.scheduledFor` alongside its existing `headline`. The Ramadan
Sehri/Iftar countdown (`01-ramadan-mode-design.md`) and this feature
reuse the exact same field — no divergent countdown data model between
the two specs.

### 2. Android: new widget variant, native-code work required

- New `android/app/src/main/res/xml/prayer_widget_info.xml`, mirroring
  `water_widget_info.xml` (same `updatePeriodMillis="1800000"` floor —
  no attempt to force a tighter native tick given the effort budget; see
  Out of scope).
- `HabitWidgetProvider.kt`'s `getModuleId()` (lines 78-82) must stop being
  hardcoded — needs real per-`appWidgetId`→module-id storage (Android's
  `AppWidgetManager`/`SharedPreferences` keyed by `appWidgetId`, the
  standard multi-widget-type pattern) instead of always returning
  `"water"`. This is a real, non-trivial change to existing shipped code,
  not just an additive one — flagged explicitly since it's easy to
  under-scope as "just add a new XML file."
- `onUpdate()` (`HabitWidgetProvider.kt:20-76`) gains rendering for a
  countdown headline: given `countdownTargetAt` (epoch millis, extracted
  the same regex-based way `extractField()` already parses `headline`/
  `primaryActionLabel` today, lines 85-88) and the device's current time,
  compute `remaining = countdownTargetAt - now` in Kotlin at render time
  and format it (`"42 min"` / `"2h 15m"`) — this is what makes the
  30-min-stale snapshot at least *display* a locally-accurate-at-render
  number rather than a number frozen at last data push, partially
  softening the "not truly live" gap without needing Glance/WorkManager
  chaining.

### 3. iOS: out of scope for this pass, explicitly

No WidgetKit extension target exists in `ios/`. Standing one up (a new
Xcode target, a `TimelineProvider`, App Group data sharing for
`home_widget`'s iOS-side storage) is a materially larger, Xcode-project-
level change than anything else in this spec and cannot be described
usefully as Dart-only design. This spec covers **Android only**; iOS
follow-on is a separate, larger effort — see Out of scope.

### 4. Rollover across midnight / past Isha

`PrayerModule.widgetSummary()`'s existing loop over `records` already
only considers same-day records (`recordsInRange(today, today)`,
line 482) — after Isha's cutoff passes with no next same-day record
pending, `firstPending` stays `null` and the method already returns
`null` (line 504), which today means "no widget tile shown at all." The
countdown variant should instead roll to tomorrow's Fajr: extend the
query to `recordsInRange(today, today.addDays(1))` when today's records
are all resolved, so the tile reads "Fajr in 6h 12m" through the night
rather than going blank — a small, explicit widening of the existing
range query, not new materialization logic (`materializeRecords` already
keeps a 30-day rolling window per `prayer_module.dart:136`/D-13's
precedent).

### New l10n keys (`app_en.arb`/`app_bn.arb`)

- `prayerCountdownWidgetDescription` — "Shows time remaining until the next prayer" (the `android:description` string resource referenced by the new `prayer_widget_info.xml`, same role as `@string/widget_water_description` already referenced by `water_widget_info.xml:10`)
- `prayerCountdownFormatMinutes` — "{minutes} min" (used only if a Dart-side fallback formatter is also needed for in-app preview; the Kotlin-side render is native-formatted independently, see Design §2)
- `prayerCountdownFormatHoursMinutes` — "{hours}h {minutes}m"

## Out of scope

- **A true native-timeline countdown** (Android Glance `GlanceAppWidget` w/ chained `PeriodicWorkRequest`, or iOS `TimelineProvider` pre-computed entries) — the honest, tastefully-scoped v1 here is "render remaining-time-at-last-refresh, refreshed at existing cadences," not a literal per-minute ticking clock. Revisit if user feedback says the ~30-min-to-8-hour Android gap (and iOS's app-resume-only gap) is unacceptable.
- **iOS entirely** — no WidgetKit extension exists; standing one up is a separate, larger, Xcode-native effort outside this spec's scope.
- **Interactive widget actions** (marking a prayer done, snoozing) from this tile — display only, matching the original draft's own non-goal.
- **New calculation/materialization logic** — this only consumes `PrayerModule.widgetSummary()`'s existing derivation plus the range-widening in Design §4.
- **Wear OS complication countdown** — `core/wearable/wearable_sync_helper.dart` is untouched by this spec; a complication countdown, if wanted, is its own follow-on given it has its own separate rendering surface.
- **Water/Medicine countdown tiles** — `countdownTargetAt` stays `null` for both; only Prayer populates it in this pass, though the field is shared infrastructure if a future spec wants it.
- **Fixing `getModuleId()`'s hardcoding as a general-purpose multi-widget system** beyond what's needed for exactly two widget types (Water, Prayer-countdown) — no speculative N-widget registry.

## Global Constraints

- **No new Dart/Flutter dependency** — `home_widget: ^0.9.3` (`pubspec.yaml:30`) already covers the Flutter-side data-passing needed; the gap is entirely native-code (Kotlin) and (out of scope, for now) native iOS work, not a package gap.
- **No schema/DB migration** — `countdownTargetAt` lives only in the ephemeral `WidgetSummaryData` JSON blob written via `HomeWidget.saveWidgetData` (`widget_refresh_helper.dart:28-31`), never persisted to Drift.
- **Real native-code diff, not Dart-only**: `HabitWidgetProvider.kt`'s hardcoded `getModuleId()` must become widget-instance-aware (Design §2) — this is the change most likely to be under-scoped if treated as "just add a countdown field."
- New l10n keys listed above (both `app_en.arb`/`app_bn.arb`), used for the Android string resources and any in-app preview surface.
- `WidgetSummaryData.countdownTargetAt` (new nullable `DateTime` field) — additive to an existing shared type, no breaking change to Water/Medicine's existing `widgetSummary()` implementations (both simply never set it, default `null`).

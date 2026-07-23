# Sunrise/Sunset Countdown Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Prayer countdown widget tile on Android that shows "Fajr in
6h 12m" / "Dhuhr in 42 min" — a time-remaining display for the next
pending prayer, rendered locally at native update cadences. Per
`docs/superpowers/specs/02-delightful/08-sunrise-sunset-countdown-widget-design.md`.

**Architecture:** Extend the existing `WidgetSummaryData` shared shape
with a `countdownTargetAt` nullable field (UTC epoch millis). `PrayerModule`
populates it with the next pending prayer's `scheduledFor`. The Android
`HabitWidgetProvider.kt` gains countdown rendering: at `onUpdate()` time,
it reads `countdownTargetAt` from the JSON blob and computes
`remaining = targetAt - now` in Kotlin, formatting it as `"42 min"` or
`"2h 15m"`. The hardcoded `getModuleId()` becomes widget-instance-aware
via Android's `AppWidgetManager` + `SharedPreferences` keyed by
`appWidgetId`. A new `prayer_widget_info.xml` registers the prayer widget
type. No new Dart/Flutter dependencies. No schema migration.

**Tech Stack:** Kotlin (Android native), Flutter/Dart, `home_widget: ^0.9.3`
(existing), `gen_l10n`, `flutter_test`.

## Global Constraints

- **No new Dart/Flutter dependency** — `home_widget: ^0.9.3` already
  covers Flutter-side data passing; the gap is entirely native Kotlin
  code and a new Android XML widget descriptor.
- **No schema/DB migration** — `countdownTargetAt` lives only in the
  ephemeral `WidgetSummaryData` JSON blob written via
  `HomeWidget.saveWidgetData`, never persisted to Drift.
- **Android only** — iOS has no WidgetKit extension; iOS follow-on is a
  separate, larger effort.
- **Display only** — no interactive actions (mark prayer done, snooze)
  from this tile, matching the spec's non-goal.
- New l10n keys in **both** `lib/core/l10n/app_en.arb` and
  `lib/core/l10n/app_bn.arb`; run `flutter gen-l10n` after each ARB edit.
- Per CLAUDE.md spec-implementation workflow: one commit per task, run
  only that task's own test file, pipe `build_runner`/`test`/`gen-l10n`
  output through `| tail -10`.

---

### Task 1: Add `countdownTargetAt` to `WidgetSummaryData`

**Files:**
- Modify: `lib/core/widgets/widget_summary_data.dart`
- Test: `test/core/widgets/widget_summary_data_test.dart` (create if not exists)

**Description:**
Add a `DateTime? countdownTargetAt` field to `WidgetSummaryData`:
1. Add the field to the constructor (nullable, optional, defaults to
   `null`).
2. Add it to `toJson()`: `'countdownTargetAt': countdownTargetAt?.toUtc().millisecondsSinceEpoch`.
3. Add it to `fromJson()`: `countdownTargetAt: json['countdownTargetAt'] != null ? DateTime.fromMillisecondsSinceEpoch(json['countdownTargetAt'] as int, isUtc: true) : null`.
4. The field is `null` for Water and Medicine (they don't set it), so
   their existing `widgetSummary()` implementations are unchanged.

**Acceptance criteria:**
- `WidgetSummaryData` compiles with the new field.
- `toJson()` round-trips `countdownTargetAt` correctly (non-null and
  null cases).
- Water/Medicine's existing `widgetSummary()` methods still compile
  without changes (field is optional with default `null`).

**Test:** Unit test: construct `WidgetSummaryData` with and without
`countdownTargetAt`, verify `toJson()`/`fromJson()` round-trip.

**Effort:** S

---

### Task 2: Populate `countdownTargetAt` in `PrayerModule.widgetSummary()`

**Files:**
- Modify: `lib/features/prayer/prayer_module.dart` (the `widgetSummary()`
  method, lines ~472-515)
- Test: `test/features/prayer/prayer_module_test.dart`

**Description:**
In `PrayerModule.widgetSummary()`:
1. When `firstPending` is non-null, set
   `countdownTargetAt: firstPending.scheduledFor` in the
   `WidgetSummaryData` constructor call.
2. **Midnight rollover fix (Design §4):** Change the records query from
   `recordsInRange(today, today)` to `recordsInRange(today,
   today.addDays(1))` when all of today's records are resolved (i.e.
   `firstPending` is null after the today-only query). This makes the
   widget show "Fajr in 6h 12m" overnight instead of going blank.
   The query widens to include tomorrow's first record.
3. The headline remains unchanged (e.g. "Fajr · 5:30 AM"); the
   countdown is a separate field, not a headline rewrite.

**Acceptance criteria:**
- `PrayerModule.widgetSummary()` returns `WidgetSummaryData` with
  `countdownTargetAt` set to the next pending prayer's scheduled time.
- After Isha, the widget rolls to tomorrow's Fajr (countdown continues
  overnight).
- When no prayers are pending (all done for today and tomorrow), returns
  `null` (no tile shown).

**Test:** Unit test with mock repository: verify `countdownTargetAt` is
set correctly for various states (morning, after Isha, all done).

**Effort:** M

---

### Task 3: Create `prayer_widget_info.xml` descriptor

**Files:**
- Create: `android/app/src/main/res/xml/prayer_widget_info.xml`
- Modify: `android/app/src/main/AndroidManifest.xml` (register the new
  widget receiver intent filter)

**Description:**
1. Create `prayer_widget_info.xml` mirroring `water_widget_info.xml`:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
       android:minWidth="110dp"
       android:minHeight="110dp"
       android:targetCellWidth="2"
       android:targetCellHeight="2"
       android:updatePeriodMillis="1800000"
       android:initialLayout="@layout/widget_habit"
       android:resizeMode="horizontal|vertical"
       android:widgetCategory="home_screen"
       android:description="@string/widget_prayer_description" />
   ```
   Reuses the same `widget_habit.xml` layout (headline + optional action
   button) — the countdown rendering happens in the Kotlin provider, not
   in a separate layout.
2. Register the prayer widget intent filter in `AndroidManifest.xml`:
   ```xml
   <receiver android:exported="true" android:name=".HabitWidgetProvider"
       android:label="@string/widget_prayer_name">
       <intent-filter>
           <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
       </intent-filter>
       <meta-data
           android:name="android.appwidget.provider"
           android:resource="@xml/prayer_widget_info" />
   </receiver>
   ```
   Note: both Water and Prayer widgets use the same
   `HabitWidgetProvider` class — the `appWidgetId` distinguishes them.
3. Add l10n keys:
   - `app_en.arb`: `"widget_prayer_name": "Prayer Countdown"`,
     `"widget_prayer_description": "Shows time remaining until the next prayer"`
   - `app_bn.arb`: `"widget_prayer_name": "নামাজ কাউন্টডাউন"`,
     `"widget_prayer_description": "পরবর্তী নামাজ পর্যন্ত বাকি সময় দেখায়"`
4. Add Android string resources:
   - `android/app/src/main/res/values/strings.xml`: add
     `widget_prayer_name` and `widget_prayer_description` referencing
     the l10n values (or hardcode English if l10n integration into
     Android resources is deferred).

**Acceptance criteria:**
- `prayer_widget_info.xml` exists and is valid.
- AndroidManifest registers the prayer widget receiver.
- The widget appears in the Android widget picker as "Prayer Countdown".

**Test:** Manual: long-press home screen → Widgets → verify "Prayer
Countdown" appears. Automated: N/A for XML resources.

**Effort:** S

---

### Task 4: Make `getModuleId()` widget-instance-aware

**Files:**
- Modify: `android/app/src/main/kotlin/dev/shurjomoy/habit_tracker/HabitWidgetProvider.kt`
- Create: (no new files — logic is in the existing provider)

**Description:**
Replace the hardcoded `return "water"` in `getModuleId()` (lines 78-82)
with per-widget-instance storage:

1. When a widget is first added (`APPWIDGET_UPDATE` with a new
   `appWidgetId`), the Flutter side calls `HomeWidget.saveWidgetData` with
   the module id. But we need a way to know *which* widget instance
   corresponds to which module. Two approaches:

   **Approach A (simpler, recommended):** Use `AppWidgetManager` metadata.
   The Flutter side, when saving widget data, also writes a mapping
   `widget_module_$appWidgetId = moduleId` via `HomeWidget.saveWidgetData`.
   But `appWidgetId` isn't known on the Dart side until the widget is
   placed.

   **Approach B (cleaner):** Store a global mapping in
   `SharedPreferences` (via `HomeWidget`'s storage). On each `onUpdate()`,
   iterate all widget IDs, check if a `widget_summary_prayer` key exists
   — if so, that widget ID is a Prayer widget. This avoids needing
   `appWidgetId` on the Dart side:

   ```kotlin
   private fun getModuleId(context: Context, appWidgetId: Int): String {
       val prefs = HomeWidgetPlugin.getData(context)
       // Check if this widget has a prayer summary stored
       val prayerSummary = prefs.getString("widget_summary_prayer", null)
       if (prayerSummary != null) {
           return "prayer"
       }
       return "water" // default fallback
   }
   ```

   **Approach C (most robust, recommended for long-term):** Use Android's
   `AppWidgetManager.getAppWidgetInfo()` to read a `widget_module` extra
   from the widget provider info's `<meta-data>`. This requires a second
   Kotlin class (`PrayerWidgetProvider`) extending `AppWidgetProvider`
   with its own `getModuleId()` override returning `"prayer"`.

   **Recommended: Approach C** — create a thin `PrayerWidgetProvider.kt`
   subclass that overrides `getModuleId()` to return `"prayer"`. Both
   providers share the same `onUpdate()` logic (inherit from
   `HabitWidgetProvider`), but each knows its own module id. This is the
   standard Android multi-widget pattern and avoids fragile string-key
   probing.

   Implementation:
   ```kotlin
   // PrayerWidgetProvider.kt
   class PrayerWidgetProvider : HabitWidgetProvider() {
       override fun getModuleId(context: Context, appWidgetId: Int): String {
           return "prayer"
       }
   }
   ```
   Update `AndroidManifest.xml` to reference `PrayerWidgetProvider` for
   the prayer widget's `<receiver>` instead of `HabitWidgetProvider`.
   Make `getModuleId()` in `HabitWidgetProvider` `open` (not `private`).

**Acceptance criteria:**
- Adding a Water widget shows Water data.
- Adding a Prayer widget shows Prayer data.
- Both widget types coexist without interfering.
- `getModuleId()` is no longer hardcoded to `"water"` in the base class.

**Test:** Manual: add both widget types, verify each shows correct data.
Unit test: N/A for Kotlin provider logic (Android instrumented test
would be ideal but is out of scope for this plan).

**Effort:** M

---

### Task 5: Add countdown rendering to `onUpdate()`

**Files:**
- Modify: `android/app/src/main/kotlin/dev/shurjomoy/habit_tracker/HabitWidgetProvider.kt`

**Description:**
In `onUpdate()`, after extracting `headline` from the JSON blob, also
extract `countdownTargetAt` and compute a countdown string:

1. Extract `countdownTargetAt` (epoch millis) from the JSON:
   ```kotlin
   val countdownTargetStr = extractFieldNumeric(summaryJson, "countdownTargetAt")
   ```
   Add a numeric field extractor (the existing `extractField` only handles
   strings):
   ```kotlin
   private fun extractFieldNumeric(json: String, field: String): Long? {
       val pattern = "\"$field\":\\s*(\\d+)".toRegex()
       return pattern.find(json)?.groupValues?.get(1)?.toLongOrNull()
   }
   ```

2. If `countdownTargetAt` is non-null, compute remaining:
   ```kotlin
   val now = System.currentTimeMillis()
   val remaining = countdownTargetAt - now
   if (remaining > 0) {
       val countdownText = formatCountdown(remaining)
       // Show countdown below headline or replace headline
       views.setTextViewText(R.id.widget_headline, "$headline\n$countdownText")
   }
   ```

3. Add `formatCountdown()`:
   ```kotlin
   private fun formatCountdown(millis: Long): String {
       val totalMinutes = millis / 60000
       val hours = totalMinutes / 60
       val minutes = totalMinutes % 60
       return when {
           hours > 0 -> "${hours}h ${minutes}m"
           else -> "${minutes} min"
       }
   }
   ```

4. If `countdownTargetAt` is null or in the past, show only the headline
   (no countdown — matches Water/Medicine behavior).

**Acceptance criteria:**
- Prayer widget shows "Fajr · 5:30 AM\n6h 12m" (headline + countdown).
- Countdown is computed at render time (local `now`), not at data-push
  time — so even a stale snapshot shows a locally-accurate remaining.
- Water widget is unaffected (no `countdownTargetAt` → no countdown
  shown).

**Test:** Manual: add Prayer widget, verify countdown appears and
decrements on each `onUpdate()` cycle. Unit test: N/A (Kotlin, Android
runtime).

**Effort:** M

---

### Task 6: Add in-app widget preview with countdown

**Files:**
- Create: `lib/features/prayer/presentation/widgets/prayer_widget_preview.dart`
- Modify: `lib/features/prayer/presentation/screens/prayer_settings_screen.dart`
  (or a new `prayer_widget_preview_screen.dart`)

**Description:**
Add a preview of how the Prayer widget will look on the home screen,
shown in Prayer settings or a dedicated preview screen. This helps the
user understand what the widget does before adding it.

1. Create `PrayerWidgetPreview` widget that mimics the Android widget's
   appearance: a card with the headline and a live countdown (using
   `Stream.periodic` or a `Timer` to tick every minute, reading the next
   pending prayer from the prayer provider).

2. Add the preview to Prayer settings (below existing settings options)
   or as a bottom sheet triggered from a "Widget Preview" button.

3. The preview uses the same `formatCountdown` logic as the Kotlin side,
   but in Dart:
   ```dart
   String formatCountdown(Duration remaining) {
     final hours = remaining.inHours;
     final minutes = remaining.inMinutes % 60;
     if (hours > 0) return '${hours}h ${minutes}m';
     return '${minutes} min';
   }
   ```

**Acceptance criteria:**
- Preview shows a card styled like the actual widget.
- Countdown ticks every minute in the preview.
- Preview is accessible from Prayer settings.

**Test:** Widget test: verify preview renders with countdown text.

**Effort:** S

---

### Task 7: Localization keys

**Files:**
- Modify: `lib/core/l10n/app_en.arb`
- Modify: `lib/core/l10n/app_bn.arb`

**Description:**
Add all new l10n keys needed by this feature:

**English (`app_en.arb`):**
```json
"widgetPrayerName": "Prayer Countdown",
"widgetPrayerDescription": "Shows time remaining until the next prayer",
"prayerCountdownWidgetPreview": "Widget Preview",
"prayerCountdownFormatMinutes": "{minutes} min",
"prayerCountdownFormatHoursMinutes": "{hours}h {minutes}m"
```

**Bangla (`app_bn.arb`):**
```json
"widgetPrayerName": "নামাজ কাউন্টডাউন",
"widgetPrayerDescription": "পরবর্তী নামাজ পর্যন্ত বাকি সময় দেখায়",
"prayerCountdownWidgetPreview": "উইজেট পূর্বরূপ",
"prayerCountdownFormatMinutes": "{minutes} মিনিট",
"prayerCountdownFormatHoursMinutes": "{hours}ঘ {minutes}মি"
```

Run `flutter gen-l10n` after editing both ARB files.

**Acceptance criteria:**
- `flutter gen-l10n` succeeds without errors.
- All new keys are accessible via `AppLocalizations`.

**Test:** `flutter gen-l10n` compiles cleanly.

**Effort:** S

---

### Task 8: Update widget refresh to include Prayer data

**Files:**
- Modify: `lib/core/widgets/widget_refresh_helper.dart`

**Description:**
Ensure `refreshAllWidgets()` already handles Prayer — check that it
iterates all modules (including Prayer) and saves their summaries.
Currently `refreshAllWidgets()` at line 43-61 iterates
`buildHabitModules(db)` which includes all registered modules, so Prayer's
`widgetSummary()` is already called. No code change needed here — just
verification.

However, ensure that after any Prayer action (prayer logged, Qadha
recorded), `refreshWidgetsForModule(db, 'prayer')` is called. Check
Prayer's `onNotificationAction` and any post-write hooks.

**Acceptance criteria:**
- After logging a prayer, the widget data is refreshed.
- `refreshAllWidgets()` includes Prayer data.

**Test:** Manual: log a prayer, verify widget updates on next
`onUpdate()` cycle.

**Effort:** S

---

### Task 9: Tests

**Files:**
- Create: `test/core/widgets/widget_summary_data_countdown_test.dart`
- Modify: `test/features/prayer/prayer_module_test.dart`

**Description:**
1. **`widget_summary_data_countdown_test.dart`:** Unit tests for
   `WidgetSummaryData` with `countdownTargetAt`:
   - Round-trip: construct with `countdownTargetAt`, serialize, deserialize,
     verify field matches.
   - Null case: construct without `countdownTargetAt`, verify
     `fromJson()` produces `null`.
   - Midnight boundary: `countdownTargetAt` near midnight serializes
     correctly.

2. **`prayer_module_test.dart` additions:**
   - Test: `widgetSummary()` returns `countdownTargetAt` matching the
     next pending prayer's `scheduledFor`.
   - Test: After Isha, `widgetSummary()` returns tomorrow's Fajr
     `scheduledFor` (midnight rollover).
   - Test: When all prayers done, `widgetSummary()` returns `null`.

**Acceptance criteria:**
- All new tests pass.
- Existing tests are not broken.

**Test:** `flutter test test/core/widgets/widget_summary_data_countdown_test.dart`
and `flutter test test/features/prayer/prayer_module_test.dart`.

**Effort:** M

---

### Task 10: Manual integration verification

**Files:**
- None (verification only)

**Description:**
End-to-end manual testing on a real Android device/emulator:

1. Add a Water widget to the home screen → verify it shows Water data
   (regression check).
2. Add a Prayer widget to the home screen → verify it shows the next
   pending prayer with a countdown.
3. Wait for `onUpdate()` cycle (30 min) or trigger via app resume →
   verify countdown updates.
4. Log a prayer → verify widget refreshes to show the next prayer.
5. After Isha → verify widget shows tomorrow's Fajr countdown.
6. Verify both widgets coexist on the home screen without interference.
7. Verify widget deep-link tap opens the app to the Prayer screen.

**Acceptance criteria:**
- All 7 scenarios pass on a real device.

**Test:** Manual testing checklist.

**Effort:** S

---

## Summary

| Task | Description | Effort |
|------|-------------|--------|
| T1 | Add `countdownTargetAt` to `WidgetSummaryData` | S |
| T2 | Populate `countdownTargetAt` in `PrayerModule.widgetSummary()` | M |
| T3 | Create `prayer_widget_info.xml` + AndroidManifest registration | S |
| T4 | Make `getModuleId()` widget-instance-aware (Approach C) | M |
| T5 | Add countdown rendering to `onUpdate()` in Kotlin | M |
| T6 | Add in-app widget preview | S |
| T7 | Localization keys (en/bn) | S |
| T8 | Verify widget refresh includes Prayer data | S |
| T9 | Tests | M |
| T10 | Manual integration verification | S |

**Total effort:** M (matching spec complexity)
**Critical path:** T1 → T2 → T5 (data shape → Prayer population → Kotlin rendering)
**Parallelizable:** T3 (XML) and T7 (l10n) can run alongside T1-T2; T4 (module ID) can run alongside T5.

## Key Risks

1. **`getModuleId()` hardcoding** — The most non-trivial change. Approach C
   (separate `PrayerWidgetProvider` subclass) is the cleanest but requires
   careful AndroidManifest wiring. Test on a real device early.
2. **Widget layout reuse** — Both Water and Prayer use `widget_habit.xml`.
   If Prayer needs a different layout (e.g. larger countdown text), a
   separate `widget_prayer_countdown.xml` layout file would be needed.
   For v1, reuse the same layout.
3. **`home_widget` storage semantics** — `HomeWidgetPlugin.getData(context)`
   returns a shared `SharedPreferences`. Verify that `widget_summary_prayer`
   and `widget_summary_water` keys don't collide or overwrite each other.
   The existing `refreshWidgetsForModule` already uses module-scoped keys
   (`widget_summary_$moduleId`), so this should be safe.
4. **30-minute update floor** — Android clamps `updatePeriodMillis` to
   ~30 min minimum. The countdown is computed at render time from
   `countdownTargetAt - now`, so even a stale snapshot shows a locally
   accurate number. This is the spec's explicit v1 trade-off.

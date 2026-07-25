# Implementation Plan: Advanced Widget Layouts

**Spec:** `10-advanced-widget-layouts-design.md`
**Complexity:** M · **Estimated effort:** 4-5 days
**Depends on:** Existing `home_widget` infrastructure, spec 07 (entitlements)

---

## Task 1: Audit existing widget infrastructure

Review the current widget setup:
- `home_widget` package integration in `main.dart`.
- `widget_refresh_helper.dart` — data pipeline.
- Native widget code in `android/app/src/main/` and `ios/Runner/`.
- Determine: App Widget vs. Glance on Android; WidgetKit family support
  on iOS.

---

## Task 2: Create combined widget data aggregator

**File:** `lib/core/widgets/combined_widget_data.dart`

Reads summaries from multiple modules:
```dart
class CombinedWidgetData {
  final WidgetSummaryData? water;
  final WidgetSummaryData? medicine;
  final WidgetSummaryData? prayer;
  // ... more modules if premium pack installed

  Future<CombinedWidgetData> fromStorage() async {
    // Read all widget_summary_$moduleId keys from home_widget
  }
}
```

---

## Task 3: Create Android combined widget

**File:** `android/app/src/main/kotlin/.../CombinedWidget.kt`

Using Glance or App Widget:
- Small (2×2): single module, user's choice.
- Medium (4×2): 2-3 modules side by side.
- Large (4×4): all enabled modules in a grid.

**File:** `android/app/src/main/res/layout/widget_combined_small.xml`
**File:** `android/app/src/main/res/layout/widget_combined_medium.xml`
**File:** `android/app/src/main/res/layout/widget_combined_large.xml`

Layout XML files for each size variant.

---

## Task 4: Create iOS combined widget

**File:** `ios/Runner/Widgets/CombinedWidget.swift`

Using WidgetKit:
- `systemSmall`: single module summary.
- `systemMedium`: 2-3 modules.
- `systemLarge`: all modules.

**File:** `ios/Runner/Widgets/CombinedWidgetTimelineProvider.swift`

Timeline provider that reads from `home_widget` shared storage.

---

## Task 5: Update widget refresh for combined widget

**File:** `lib/core/widgets/widget_refresh_helper.dart`

Modify `refreshAllWidgets()` to also save combined widget data (a JSON
blob containing all module summaries).

---

## Task 6: Add widget premium gating

Register/unregister the combined widget provider based on entitlement
status. On Android, use dynamic component registration. On iOS, use
widget intent configuration.

---

## Task 7: Create widget configuration UI

**File:** `lib/core/widgets/widget_config_screen.dart`

When the user adds the combined widget, show a configuration screen:
- Select which modules to display (checkboxes).
- Select widget size (small/medium/large).
- Premium check before allowing configuration.

---

## Task 8: Add localization strings

en/bn ARB keys for widget labels, configuration text.

---

## Review checklist

- [ ] Combined widget renders correctly at all sizes.
- [ ] Widget data updates when app data changes.
- [ ] Premium gating works (non-premium users can't add widget).
- [ ] Widget handles empty module data gracefully.
- [ ] Widget refresh doesn't drain battery.
- [ ] en/bn text renders correctly in widget.

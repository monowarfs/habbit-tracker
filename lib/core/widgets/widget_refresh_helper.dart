import 'dart:io';

import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/widgets/widget_summary_data.dart';
import 'package:home_widget/home_widget.dart';

/// Saves a module's [WidgetSummaryData] to `home_widget`'s shared
/// storage and requests a widget UI refresh. Called from:
/// - The foreground after any mutating action
/// - The app-resume lifecycle hook
/// - The WorkManager periodic top-up
/// - The widget's own background tap handler (after dispatching the action)
///
/// No-op on non-Android/iOS platforms (home_widget has no desktop/web impl).
///
/// Family/multi-profile (Task 9): every call site here takes `AppDatabase`
/// directly, no `Ref` — same non-Ref constraint as `notification_planner
/// .dart`'s `planAndApplyNotifications`. `HabitModule.widgetSummary()`
/// itself is pinned to the `'system'` profile (each module's own
/// `_fixedProfileId`), so the OS home-screen widget always reflects that
/// profile's data regardless of which profile is active in the
/// foreground app — consistent with every other background/widget entry
/// point, not yet true per-profile widget data (would need a profile id
/// threaded through the `HabitModule` contract itself).
Future<void> refreshWidgetsForModule(
  AppDatabase db,
  String moduleId,
) async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  try {
    final modules = await visibleHabitModulesFromDb(db);
    for (final module in modules) {
      if (module.id != moduleId) continue;
      final summary = await module.widgetSummary();
      if (summary != null) {
        await HomeWidget.saveWidgetData(
          'widget_summary_$moduleId',
          summary.toRawJson(),
        );
      } else {
        await HomeWidget.saveWidgetData('widget_summary_$moduleId', null);
      }
    }
    await HomeWidget.updateWidget();
  } on Object catch (e) {
    logger.e('widget refresh failed for $moduleId', error: e);
  }
}

/// Refreshes widget data for all registered modules.
Future<void> refreshAllWidgets(AppDatabase db) async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  try {
    final modules = await visibleHabitModulesFromDb(db);
    for (final module in modules) {
      final summary = await module.widgetSummary();
      if (summary != null) {
        await HomeWidget.saveWidgetData(
          'widget_summary_${module.id}',
          summary.toRawJson(),
        );
      } else {
        await HomeWidget.saveWidgetData('widget_summary_${module.id}', null);
      }
    }
    await HomeWidget.updateWidget();
  } on Object catch (e) {
    logger.e('widget refresh all failed', error: e);
  }
}

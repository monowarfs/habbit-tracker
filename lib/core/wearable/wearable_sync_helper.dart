import 'dart:io';

import 'package:flutter/services.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';

/// MethodChannel name for the Wear OS Data Layer bridge.
const wearSyncChannel = 'dev.shurjomoy.habit_tracker/wear_sync';

/// Pushes a cross-module summary to the Wear OS Data Layer API via a
/// native Kotlin bridge. Called from the same trigger points as
/// `refreshAllWidgets`: foreground resume, WorkManager top-up, and after
/// any mutating quick-action.
///
/// No-op on non-Android platforms.
Future<void> syncWearableData(AppDatabase db) async {
  if (!Platform.isAndroid) return;
  try {
    final modules = await visibleHabitModulesFromDb(db);
    final summaries = <String, Object?>{};
    var totalPending = 0;
    for (final module in modules) {
      final summary = await module.widgetSummary();
      if (summary != null) {
        summaries[module.id] = summary.toJson();
        totalPending += summary.pendingCount ?? 0;
      }
    }
    // The wearable complication shows a single cross-module pending count.
    // Per-module data is available for future per-complication expansion.
    await const MethodChannel(wearSyncChannel).invokeMethod<void>(
      'syncWearableData',
      {
        'modules': summaries,
        'totalPending': totalPending,
      },
    );
  } on Object catch (e) {
    // MethodChannel may not be available in test/emulator without the
    // native side registered — log, don't throw.
    logger.e('wearable sync failed', error: e);
  }
}

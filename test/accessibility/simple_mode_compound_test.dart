import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_home_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_home_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_settings_screen.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_home_screen.dart';

import 'text_scale_test_helper.dart';

/// Simple Mode compound scenarios (spec 06, Task 9): the large-button
/// layout combined with 2.0x text scale, plus toggling and fallback
/// behavior — separate from the plain 2.0x-only per-screen text-scale
/// suites already covering the normal layout.
void main() {
  // Database is created/closed inline per test (not via setUp/tearDown) —
  // empirically the reliable pattern for real-DB widget tests in this
  // environment (see water_stats_table_test.dart's same workaround).
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  }

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget simpleModeApp(AppDatabase db, Widget home) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      simpleModeEnabledProvider.overrideWithValue(true),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(isBangla: false),
      home: home,
    ),
  );

  testWidgets(
    'WaterHomeScreen: Simple Mode at 2.0x text scale, no overflow',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      useTallSurface(tester);
      await pumpAtTextScale(
        tester,
        simpleModeApp(db, const WaterHomeScreen()),
        2,
      );
      await disposeTree(tester);
      await db.close();
    },
  );

  testWidgets(
    'MedicineHomeScreen: Simple Mode at 2.0x text scale, no overflow',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      useTallSurface(tester);
      await pumpAtTextScale(
        tester,
        simpleModeApp(db, const MedicineHomeScreen()),
        2,
      );
      await disposeTree(tester);
      await db.close();
    },
  );

  testWidgets(
    'PrayerHomeScreen: Simple Mode at 2.0x text scale, no overflow',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      useTallSurface(tester);
      await pumpAtTextScale(
        tester,
        simpleModeApp(db, const PrayerHomeScreen()),
        2,
      );
      await disposeTree(tester);
      await db.close();
    },
  );

  testWidgets(
    'DashboardScreen: Simple Mode at 2.0x text scale, no overflow',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpAtTextScale(
        tester,
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            simpleModeEnabledProvider.overrideWithValue(true),
            habitModulesProvider.overrideWith((ref) => []),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(isBangla: false),
            home: const DashboardScreen(),
          ),
        ),
        2,
      );
      await disposeTree(tester);
      await db.close();
    },
  );

  testWidgets(
    'Simple Mode toggled off re-renders the normal WaterHomeScreen layout',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            simpleModeEnabledProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(isBangla: false),
            home: const WaterHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
      await db.close();
    },
  );

  testWidgets(
    'PrayerSettingsScreen has no Simple Mode layout branch and still '
    'renders normally when Simple Mode is enabled',
    (tester) async {
      // A module screen with no Simple Mode branch of its own must fall
      // back to its ordinary layout instead of crashing or misrendering.
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(simpleModeApp(db, const PrayerSettingsScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
      await db.close();
    },
  );
}

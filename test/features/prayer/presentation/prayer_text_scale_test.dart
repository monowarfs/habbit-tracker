import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_home_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_qadha_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_settings_screen.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_stats_screen.dart';

import '../../../accessibility/text_scale_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Widget app(Widget home) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(isBangla: false),
      home: home,
    ),
  );

  testWidgets(
    'PrayerHomeScreen at 2.0x: no overflow (checklist rows)',
    (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpAtTextScale(tester, app(const PrayerHomeScreen()), 2.0);
      await disposeTree(tester);
    },
  );

  testWidgets('PrayerStatsScreen at 2.0x: no overflow', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAtTextScale(tester, app(const PrayerStatsScreen()), 2.0);
    await disposeTree(tester);
  });

  testWidgets('PrayerQadhaScreen at 2.0x: no overflow', (tester) async {
    await pumpAtTextScale(tester, app(const PrayerQadhaScreen()), 2.0);
    await disposeTree(tester);
  });

  testWidgets('PrayerSettingsScreen at 2.0x: no overflow', (tester) async {
    await pumpAtTextScale(tester, app(const PrayerSettingsScreen()), 2.0);
    await disposeTree(tester);
  });
}

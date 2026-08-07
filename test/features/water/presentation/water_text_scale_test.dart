import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_add_entry_screen.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_home_screen.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_settings_screen.dart';

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

  testWidgets('WaterHomeScreen at 2.0x: no overflow', (tester) async {
    await pumpAtTextScale(tester, app(const WaterHomeScreen()), 2);
    await disposeTree(tester);
  });

  testWidgets('WaterAddEntryScreen at 2.0x: no overflow', (tester) async {
    await pumpAtTextScale(tester, app(const WaterAddEntryScreen()), 2);
    await disposeTree(tester);
  });

  testWidgets('WaterSettingsScreen at 2.0x: no overflow', (tester) async {
    await pumpAtTextScale(tester, app(const WaterSettingsScreen()), 2);
    await disposeTree(tester);
  });
}

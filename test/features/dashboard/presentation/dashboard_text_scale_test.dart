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

import '../../../accessibility/text_scale_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  for (final scale in [1.5, 2.0]) {
    for (final isDark in [false, true]) {
      for (final locale in [const Locale('en'), const Locale('bn')]) {
        testWidgets(
          'Dashboard at ${scale}x, ${isDark ? 'dark' : 'light'} theme, '
          '${locale.languageCode}: no overflow',
          (tester) async {
            // A tall, fixed viewport so the dashboard's cards fit within
            // ListView's sliver cache extent even with larger text —
            // see dashboard_screen_test.dart's same setup for why.
            tester.view.physicalSize = const Size(800, 3600);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await pumpAtTextScale(
              tester,
              ProviderScope(
                overrides: [
                  habitModulesProvider.overrideWith((ref) => []),
                  databaseProvider.overrideWithValue(db),
                ],
                child: MaterialApp(
                  locale: locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: isDark
                      ? AppTheme.dark(isBangla: locale.languageCode == 'bn')
                      : AppTheme.light(isBangla: locale.languageCode == 'bn'),
                  home: const DashboardScreen(),
                ),
              ),
              scale,
            );

            await disposeTree(tester);
          },
        );
      }
    }
  }
}

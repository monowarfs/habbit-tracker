import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/settings/presentation/screens/theme_settings_screen.dart';

Future<void> _pumpThemeSettings(
  WidgetTester tester,
  AppDatabase db,
  SettingsRepository repo,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepositoryImpl(db);
  });
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('defaults to on for a fresh install', (tester) async {
    await _pumpThemeSettings(tester, db, repo);

    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Seasonal color accents'),
    );
    expect(tile.value, isTrue);

    await disposeTree(tester);
  });

  testWidgets('toggling off persists the opt-out', (tester) async {
    await _pumpThemeSettings(tester, db, repo);

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Seasonal color accents'),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Seasonal color accents'),
    );
    expect(tile.value, isFalse);

    await disposeTree(tester);
  });
}

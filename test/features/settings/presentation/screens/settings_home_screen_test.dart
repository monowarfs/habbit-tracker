import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:habit_tracker/features/settings/presentation/screens/settings_home_screen.dart';

const _channel = MethodChannel('d.flutter.localnotifications');

Future<void> _pumpSettingsHome(
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
        home: SettingsHomeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepositoryImpl(db);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (method) async {
          switch (method.method) {
            case 'canScheduleExactNotifications':
              return true;
            case 'initialize':
              return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    db.close();
  });

  testWidgets('shows "Not set" for a fresh install with no display name '
      'set yet', (tester) async {
    await _pumpSettingsHome(tester, db, repo);

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('setting a display name persists it and updates the '
      'subtitle', (tester) async {
    await _pumpSettingsHome(tester, db, repo);

    // Write directly to the repo — the stream provider will pick it up.
    await repo.updateDisplayName('Nadia');
    // Allow the stream to propagate and the widget to rebuild.
    await tester.pump();
    await tester.pump();

    expect(find.text('Nadia'), findsOneWidget);
    expect(find.text('Not set'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/presentation/screens/settings_home_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets(
    'the sound toggle defaults off and persists when switched on',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsHomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(
        SwitchListTile,
        l10n.settingsSoundToggle,
      );
      expect(tile, findsOneWidget);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    },
  );

}

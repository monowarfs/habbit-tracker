import 'dart:async';

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
  // A tall, fixed viewport so the settings list — which keeps growing as
  // more toggles land — never scrolls a later tile (e.g. "Adaptive
  // Reminders") past ListView's sliver cache extent, same fix as
  // `dashboard_screen_test.dart`'s `_pump` helper.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
    unawaited(db.close());
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
      await tester.scrollUntilVisible(tile, 500);
      expect(tile, findsOneWidget);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      // Drive the switch directly via its callback instead of a
      // hit-tested tap — the exact final scroll offset (and thus the
      // tile's on-screen position) is sensitive to how many tiles sit
      // above it, so a coordinate-based tap is fragile (same fix as the
      // adaptive-reminder toggle test below).
      tester.widget<SwitchListTile>(tile).onChanged!(true);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(tile).value, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'the audio cues toggle defaults on and persists when switched off',
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
        l10n.settingsAudioCuesLabel,
      );
      await tester.scrollUntilVisible(tile, 500);
      expect(tile, findsOneWidget);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);

      // Drive the switch directly via its callback — same fix as the
      // sound toggle test above.
      tester.widget<SwitchListTile>(tile).onChanged!(false);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'the Simple Mode toggle defaults off and persists when switched on',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await _pumpSettingsHome(tester, db, repo);
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(
        SwitchListTile,
        l10n.settingsSimpleModeLabel,
      );
      expect(tile, findsOneWidget);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      // Drive the switch directly via its callback — same fix as the
      // sound/audio-cues toggles above (scroll position is fragile).
      tester.widget<SwitchListTile>(tile).onChanged!(true);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(tile).value, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'the adaptive reminder toggle defaults off and persists when switched '
    'on',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // A tall, fixed viewport so this tile — pushed further down by the
      // Simple Mode toggle added above it — stays within ListView's
      // sliver cache extent (same fix as `_pumpSettingsHome`).
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
        l10n.adaptiveReminderTitle,
      );
      expect(tile, findsOneWidget);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);

      // The tile lives far enough down the settings list that scrolling it
      // into view is unreliable across environments — the finder itself
      // works regardless of scroll position, so drive the switch directly
      // via its callback instead of a hit-tested tap.
      tester.widget<SwitchListTile>(tile).onChanged!(true);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(tile).value, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}

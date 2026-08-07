import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/profiles/profile_repository.dart';
import 'package:habit_tracker/core/profiles/profile_switcher.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // setActiveProfile updates app_settings.active_profile_id — real app
    // boot always seeds this singleton row first (`ProfileRepository
    // .setActiveProfile`'s own doc comment); reproduce that here or the
    // switch silently no-ops.
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.appSettingsTable)
        .insert(
          AppSettingsRow(
            id: 'singleton',
            locale: 'en',
            themeMode: 'system',
            waterUnit: 'ml',
            pinEnabled: false,
            pinLockTimeoutSeconds: 0,
            biometricEnabled: true,
            screenPrivacyEnabled: false,
            soundEnabled: false,
            audioCuesEnabled: true,
            ramadanAutoDetectEnabled: true,
            adaptiveReminderEnabled: false,
            quietHoursEnabled: false,
            quietHoursStart: '22:00',
            quietHoursEnd: '07:00',
            seasonalAccentsEnabled: true,
            recapEnabled: true,
            reengagementNudgeEnabled: true,
            recalibrationPromptsEnabled: true,
            driveBackupReminderEnabled: false,
            activePaletteId: 'teal',
            activeIconPackId: 'default',
            lastRecapYear: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> pumpSwitcher(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              Scaffold(appBar: AppBar(actions: const [ProfileSwitcher()])),
        ),
        GoRoute(
          path: '/settings/profiles',
          builder: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the active profile initial and opens the switcher '
      'sheet on tap', (tester) async {
    await pumpSwitcher(tester);

    expect(find.text('M'), findsOneWidget); // 'Me' -> initial

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.text('Switch Profile'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget); // active profile
  });

  testWidgets('switching to a newly created profile updates the avatar', (
    tester,
  ) async {
    final repo = ProfileRepository(db);
    final kid = await repo.createProfile('Kid', 'ocean');

    await pumpSwitcher(tester);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Kid'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfileSwitcher)),
    );
    expect((await container.read(activeProfileProvider.future)).id, kid.id);
  });
}

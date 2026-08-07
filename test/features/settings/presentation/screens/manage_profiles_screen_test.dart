import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/profiles/profile_repository.dart';
import 'package:habit_tracker/features/settings/presentation/screens/manage_profiles_screen.dart';

void main() {
  late AppDatabase db;
  late AppLocalizations l10n;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester, {bool premium = false}) async {
    final router = GoRouter(
      initialLocation: '/profiles',
      routes: [
        GoRoute(
          path: '/profiles',
          builder: (_, _) => const ManageProfilesScreen(),
        ),
        GoRoute(
          path: '/settings/purchase',
          builder: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          isPremiumUserProvider.overrideWithValue(premium),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the system profile and disables delete when it is '
      'the only one', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Me'), findsOneWidget);
    final deleteButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.delete_outline),
    );
    expect(deleteButton.onPressed, isNull);
  });

  testWidgets(
    'tapping the visibility icon toggles leaderboardOptedOut',
    (tester) async {
      await pumpScreen(tester);

      expect(
        find.byIcon(Icons.visibility_outlined),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      final profiles = await ProfileRepository(db).listProfiles();
      expect(profiles.single.leaderboardOptedOut, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    },
  );

  testWidgets('tapping Add Profile as a non-premium user opens the '
      'purchase screen instead of the dialog', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'a premium user can add a profile, which then appears in the list '
    'and both profiles get an enabled delete button',
    (tester) async {
      await pumpScreen(tester, premium: true);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Kid');
      await tester.tap(find.text(l10n.commonSave));
      await tester.pumpAndSettle();

      expect(find.text('Kid'), findsOneWidget);
      final deleteButtons = tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(deleteButtons, hasLength(2));
      expect(deleteButtons.every((b) => b.onPressed != null), isTrue);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ManageProfilesScreen)),
      );
      expect(
        (await container.read(activeProfileProvider.future)).id,
        'system',
      );
    },
  );
}

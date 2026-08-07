import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/gamification/leaderboard/leaderboard_metric.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/profiles/profile_repository.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/leaderboard/presentation/screens/leaderboard_screen.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id, this.statusByProfile);
  @override
  final String id;
  final Map<String, Map<LocalDate, ModuleDayStatus>> statusByProfile;

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(
    DateRange range, {
    String? profileId,
  }) async => statusByProfile[profileId] ?? {};
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<HabitModule> modules = const [],
  }) async {
    final router = GoRouter(
      initialLocation: '/leaderboard',
      routes: [
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) => const LeaderboardScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          visibleHabitModulesProvider.overrideWith((ref) => modules),
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

  testWidgets(
    'shows the single-profile message when only one profile exists',
    (tester) async {
      await pumpScreen(tester);

      expect(find.text('Add another profile to compare'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    },
  );

  testWidgets(
    'shows a ranked list with metric selector for 2+ profiles',
    (tester) async {
      final repo = ProfileRepository(db);
      await repo.listProfiles(); // seeds 'system'
      await repo.createProfile('Kid', 'blue');

      final today = localDayKey(clock.now());
      final water = _FakeModule('water', {
        'system': {
          today: const ModuleDayStatus(
            kind: ModuleDayStatusKind.complete,
            value: 1,
          ),
        },
      });

      await pumpScreen(tester, modules: [water]);

      expect(find.text('Add another profile to compare'), findsNothing);
      expect(find.text('Me (You)'), findsOneWidget);
      expect(find.text('Kid'), findsOneWidget);
      expect(find.byType(SegmentedButton<LeaderboardMetric>), findsOneWidget);
    },
  );
}

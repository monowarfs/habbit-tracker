import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id);
  @override
  final String id;

  @override
  ModuleMetadata get metadata => ModuleMetadata(
    displayName: id,
    icon: Icons.circle,
    accentColor: Colors.blue,
  );

  @override
  Widget dashboardSummary(WidgetRef ref) => Card(child: Text('$id summary'));

  @override
  Widget? nextUpcoming(WidgetRef ref) => null;

  @override
  List<Widget> quickActions(WidgetRef ref) => const [];

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async =>
      {};
}

Future<void> _pump(
  WidgetTester tester,
  List<HabitModule> modules,
  AppDatabase db,
) async {
  // A tall, fixed viewport so the dashboard's growing list of cards
  // (VirtualCompanion/WeeklyQuestList/BossChallengeCard/XpLevelDisplay/...)
  // never scrolls a later module's dashboardSummary() card past
  // ListView's sliver cache extent — past that point it's simply never
  // built, and find.text can't see content that was never mounted, no
  // matter how much the test scrolls or settles (found while adding
  // XpLevelDisplay: the default 800x600 test surface was already close
  // to this edge before that card, tipped over by it).
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitModulesProvider.overrideWith((ref) => modules),
        databaseProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('0 modules: shows the empty state, no summary cards', (
    tester,
  ) async {
    await _pump(tester, [], db);
    expect(find.textContaining('summary'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets("1 module: shows exactly that module's summary card", (
    tester,
  ) async {
    await _pump(tester, [_FakeModule('water')], db);
    expect(find.text('water summary'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('3 modules: shows all three summary cards', (tester) async {
    await _pump(
      tester,
      [_FakeModule('water'), _FakeModule('medicine'), _FakeModule('prayer')],
      db,
    );
    expect(find.text('water summary'), findsOneWidget);
    expect(find.text('medicine summary'), findsOneWidget);
    expect(find.text('prayer summary'), findsOneWidget);
    await disposeTree(tester);
  });

  group('dashboard greeting', () {
    testWidgets('morning, no display name set: shows the name-less '
        'morning greeting', (tester) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 8)), () async {
        await _pump(tester, [_FakeModule('water')], db);
        expect(find.text('Good morning'), findsOneWidget);
      });
      await disposeTree(tester);
    });

    testWidgets('evening, display name set: shows the named evening '
        'greeting', (tester) async {
      final repo = SettingsRepositoryImpl(db);
      await repo.updateDisplayName('Nadia');

      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 18)), () async {
        await _pump(tester, [_FakeModule('water')], db);
        expect(find.text('Good evening, Nadia'), findsOneWidget);
      });
      await disposeTree(tester);
    });

    testWidgets('night bucket: shows the name-less night greeting', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 23)), () async {
        await _pump(tester, [_FakeModule('water')], db);
        expect(find.text('Hello'), findsOneWidget);
      });
      await disposeTree(tester);
    });
  });
}

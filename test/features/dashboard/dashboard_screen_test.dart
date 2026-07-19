import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';

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

Future<void> _pump(WidgetTester tester, List<HabitModule> modules) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [habitModulesProvider.overrideWith((ref) => modules)],
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
  testWidgets('0 modules: shows the empty state, no summary cards', (
    tester,
  ) async {
    await _pump(tester, []);
    expect(find.textContaining('summary'), findsNothing);
  });

  testWidgets("1 module: shows exactly that module's summary card", (
    tester,
  ) async {
    await _pump(tester, [_FakeModule('water')]);
    expect(find.text('water summary'), findsOneWidget);
  });

  testWidgets('3 modules: shows all three summary cards', (tester) async {
    await _pump(tester, [
      _FakeModule('water'),
      _FakeModule('medicine'),
      _FakeModule('prayer'),
    ]);
    expect(find.text('water summary'), findsOneWidget);
    expect(find.text('medicine summary'), findsOneWidget);
    expect(find.text('prayer summary'), findsOneWidget);
  });
}

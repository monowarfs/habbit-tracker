import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/reports/presentation/screens/reports_screen.dart';

class _EmptyModule extends Fake implements HabitModule {
  @override
  String get id => 'water';
  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Water',
    icon: Icons.water_drop,
    accentColor: Colors.blue,
  );
  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async =>
      {};
}

void main() {
  testWidgets('shows an empty state when no module has data for the period', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 15)), () async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitModulesProvider.overrideWith((ref) => [_EmptyModule()]),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ReportsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No data'), findsWidgets);
    });
  });
}

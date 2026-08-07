import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/analytics/presentation/screens/heatmap_screen.dart';

class _FakeModule extends Fake implements HabitModule {
  @override
  String get id => 'water';

  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Water',
    icon: Icons.water_drop,
    accentColor: Colors.blue,
  );

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async {
    return {
      range.start: const ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: 2000,
      ),
    };
  }
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [habitModulesProvider.overrideWith((ref) => [_FakeModule()])],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HeatmapScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows every visible module by name, and a legend', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 15)), () async {
      await _pumpScreen(tester);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });
  });

  testWidgets('the next-year chevron is disabled once at the current year', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 15)), () async {
      await _pumpScreen(tester);
      final nextButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(nextButton.onPressed, isNull);
    });
  });

  testWidgets('the previous-year chevron steps the displayed year back', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 15)), () async {
      await _pumpScreen(tester);
      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOneWidget);
    });
  });
}

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/analytics/presentation/screens/year_comparison_screen.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

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
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(
    DateRange range, {
    String? profileId,
  }) async => {
    range.start: const ModuleDayStatus(
      kind: ModuleDayStatusKind.complete,
      value: 2000,
    ),
  };
}

/// Same shape as [_FakeModule] but with a per-day value hook, for the
/// "shift into next month" regression test.
class _ConfigurableModule extends Fake implements HabitModule {
  _ConfigurableModule(this._valueFor);

  final num Function(LocalDate day) _valueFor;

  @override
  String get id => 'water';

  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Water',
    icon: Icons.water_drop,
    accentColor: Colors.blue,
  );

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(
    DateRange range, {
    String? profileId,
  }) async {
    final map = <LocalDate, ModuleDayStatus>{};
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      map[day] = ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: _valueFor(day),
      );
      day = day.addDays(1);
    }
    return map;
  }
}

AppSettings _settings({DateTime? installDate}) => AppSettings(
  locale: AppLocale.en,
  themeMode: AppThemeMode.system,
  waterUnit: WaterUnit.ml,
  pinEnabled: false,
  pinLockTimeoutSeconds: 0,
  biometricEnabled: true,
  screenPrivacyEnabled: false,
  soundEnabled: false,
  quietHoursEnabled: false,
  quietHoursStart: const LocalTime(22, 0),
  quietHoursEnd: const LocalTime(7, 0),
  seasonalAccentsEnabled: false,
  installDate: installDate,
);

Future<void> _pumpScreen(WidgetTester tester, {DateTime? installDate}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitModulesProvider.overrideWith((ref) => [_FakeModule()]),
        appSettingsProvider.overrideWithValue(
          AsyncData(_settings(installDate: installDate)),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: YearComparisonScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty state for a user with under a year of '
      'history', (tester) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 15)), () async {
      await _pumpScreen(
        tester,
        installDate: DateTime.utc(2026), // ~5 months ago
      );
      expect(
        find.text('Not enough history yet (need 1 year)'),
        findsOneWidget,
      );
      expect(find.byType(PeriodBarChart), findsNothing);
    });
  });

  testWidgets(
    'shows a comparison chart per visible module for an eligible user',
    (tester) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 15)), () async {
        await _pumpScreen(
          tester,
          installDate: DateTime.utc(2024), // well over a year
        );
        expect(find.text('Water'), findsOneWidget);
        expect(find.byType(PeriodBarChart), findsOneWidget);
        expect(find.text('vs. Last Year'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'shifting the month anchor from December into January keeps every '
    "day's real data - a raw month+1 (instead of LocalDate.addMonths) "
    'would silently drop day 1 to a zeroed-out lookup',
    (tester) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 12, 15)), () async {
        const jan1NextYear = LocalDate(2027, 1, 1);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitModulesProvider.overrideWith(
                (ref) => [
                  _ConfigurableModule(
                    (day) => day == jan1NextYear ? 99 : 5,
                  ),
                ],
              ),
              appSettingsProvider.overrideWithValue(
                AsyncData(_settings(installDate: DateTime.utc(2024))),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: YearComparisonScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default period is month, anchored at December - tap "next".
        await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
        await tester.pumpAndSettle();

        final chart = tester.widget<PeriodBarChart>(
          find.byType(PeriodBarChart),
        );
        expect(chart.points.first.value, 99);
      });
    },
  );
}

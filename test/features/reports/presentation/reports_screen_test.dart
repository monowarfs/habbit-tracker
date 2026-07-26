import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
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

class _DataModule extends Fake implements HabitModule {
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
    final result = <LocalDate, ModuleDayStatus>{};
    var day = range.start;
    while (day.compareTo(range.end) <= 0) {
      result[day] = const ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: 1,
      );
      day = day.addDays(1);
    }
    return result;
  }
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

  testWidgets(
    'the share-month button is disabled for week/year, and enabled once '
    "switched to month with a module that has this period's data",
    (tester) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 7, 15)), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitModulesProvider.overrideWith((ref) => [_DataModule()]),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ReportsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default period is week -> disabled.
        expect(
          tester
              .widget<IconButton>(
                find.ancestor(
                  of: find.byIcon(Icons.ios_share),
                  matching: find.byType(IconButton),
                ),
              )
              .onPressed,
          isNull,
        );

        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<IconButton>(
                find.ancestor(
                  of: find.byIcon(Icons.ios_share),
                  matching: find.byType(IconButton),
                ),
              )
              .onPressed,
          isNotNull,
        );
      });
    },
  );

  testWidgets(
    'tapping Export as a non-premium user shows an upsell instead of a '
    'format picker',
    (tester) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 15)), () async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitModulesProvider.overrideWith((ref) => [_DataModule()]),
              isPremiumUserProvider.overrideWithValue(false),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ReportsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.file_download_outlined));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.reportsExportPremiumRequired),
          findsOneWidget,
        );
        expect(find.text(l10n.reportsExportSheetTitle), findsNothing);
      });
    },
  );

  testWidgets(
    'tapping Export as a premium user opens the format picker with a '
    'module preview',
    (tester) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 6, 15)), () async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitModulesProvider.overrideWith((ref) => [_DataModule()]),
              isPremiumUserProvider.overrideWithValue(true),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ReportsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.file_download_outlined));
        await tester.pumpAndSettle();

        expect(find.text(l10n.reportsExportSheetTitle), findsOneWidget);
        expect(find.text(l10n.reportsExportIncludes('Water')), findsOneWidget);
        expect(find.text(l10n.reportsExportFormatPdf), findsOneWidget);
        expect(find.text(l10n.reportsExportFormatCsv), findsOneWidget);
      });
    },
  );
}

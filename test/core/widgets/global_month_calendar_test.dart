import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/global_month_calendar.dart';

void main() {
  group('combinedDayStatusKind', () {
    test('all complete -> complete', () {
      expect(
        combinedDayStatusKind([
          ModuleDayStatusKind.complete,
          ModuleDayStatusKind.complete,
        ]),
        ModuleDayStatusKind.complete,
      );
    });
    test('mixed complete/missed -> partial', () {
      expect(
        combinedDayStatusKind([
          ModuleDayStatusKind.complete,
          ModuleDayStatusKind.missed,
        ]),
        ModuleDayStatusKind.partial,
      );
    });
    test('all missed -> missed', () {
      expect(
        combinedDayStatusKind([ModuleDayStatusKind.missed]),
        ModuleDayStatusKind.missed,
      );
    });
    test('empty or all none -> none', () {
      expect(combinedDayStatusKind([]), ModuleDayStatusKind.none);
      expect(
        combinedDayStatusKind([ModuleDayStatusKind.none]),
        ModuleDayStatusKind.none,
      );
    });
  });

  testWidgets('renders a cell per day of the month and calls onDayTap', (
    tester,
  ) async {
    LocalDate? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AppSemanticColors.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GlobalMonthCalendar(
            month: const LocalDate(2026, 6, 1),
            statusesByModule: {
              'water': {
                const LocalDate(2026, 6, 1): const ModuleDayStatus(
                  kind: ModuleDayStatusKind.complete,
                  value: 1,
                ),
              },
            },
            onDayTap: (day) => tapped = day,
          ),
        ),
      ),
    );
    await tester.tap(find.text('1').first);
    expect(tapped, const LocalDate(2026, 6, 1));
  });
}

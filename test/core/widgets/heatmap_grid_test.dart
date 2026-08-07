import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/heatmap_grid.dart';

void main() {
  Future<void> pumpGrid(
    WidgetTester tester, {
    required Map<LocalDate, ModuleDayStatus> dayStatus,
    required int year,
    LocalDate? today,
    void Function(LocalDate day)? onDayTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HeatmapGrid(
            dayStatus: dayStatus,
            year: year,
            today: today,
            onDayTap: onDayTap,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders one column per full calendar week covering the year', (
    tester,
  ) async {
    await pumpGrid(
      tester,
      dayStatus: const {},
      year: 2026,
      today: const LocalDate(2026, 12, 31),
    );
    // 2026-01-01 is a Thursday and 2026-12-31 is a Thursday, so the
    // padded grid spans 53 Monday-start weeks.
    expect(find.byType(Column), findsNWidgets(53));
  });

  testWidgets('calls onDayTap for a past in-year day', (tester) async {
    LocalDate? tapped;
    await pumpGrid(
      tester,
      dayStatus: {
        const LocalDate(2026, 3, 5): const ModuleDayStatus(
          kind: ModuleDayStatusKind.complete,
          value: 2000,
        ),
      },
      year: 2026,
      today: const LocalDate(2026, 6, 15),
      onDayTap: (day) => tapped = day,
    );

    expect(
      find.bySemanticsLabel('2026-03-05, complete, 2000'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('2026-03-05, complete, 2000'));
    expect(tapped, const LocalDate(2026, 3, 5));
  });

  testWidgets('does not call onDayTap for a day after today', (tester) async {
    LocalDate? tapped;
    await pumpGrid(
      tester,
      dayStatus: const {},
      year: 2026,
      today: const LocalDate(2026, 1, 15),
      onDayTap: (day) => tapped = day,
    );

    final futureDay = find.bySemanticsLabel('2026-06-15, no data');
    expect(futureDay, findsOneWidget);
    await tester.tap(futureDay, warnIfMissed: false);
    expect(tapped, isNull);
  });

  testWidgets(
    'a missed day has a distinct Semantics label from a no-data day',
    (tester) async {
      await pumpGrid(
        tester,
        dayStatus: {
          const LocalDate(2026, 2, 10): const ModuleDayStatus(
            kind: ModuleDayStatusKind.missed,
            value: 0,
          ),
        },
        year: 2026,
        today: const LocalDate(2026, 6, 15),
      );

      expect(find.bySemanticsLabel('2026-02-10, missed, 0'), findsOneWidget);
    },
  );
}

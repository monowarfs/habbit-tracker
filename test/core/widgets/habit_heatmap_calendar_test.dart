import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/habit_heatmap_calendar.dart';

void main() {
  group('heatmapAlphaFor', () {
    test('none returns 0 (caller uses the neutral surface color)', () {
      expect(
        heatmapAlphaFor(
          const ModuleDayStatus(kind: ModuleDayStatusKind.none, value: 0),
          10,
        ),
        0,
      );
    });

    test('missed returns 1 (caller uses errorContainer)', () {
      expect(
        heatmapAlphaFor(
          const ModuleDayStatus(kind: ModuleDayStatusKind.missed, value: 0),
          10,
        ),
        1,
      );
    });

    test('partial always stays below the complete band, even with a '
        'higher raw value than a complete day', () {
      // Regression test for the v1 bug: a partial day with 3/4 doses
      // must never out-color a complete day with 2/2 doses.
      final partialHighValue = heatmapAlphaFor(
        const ModuleDayStatus(kind: ModuleDayStatusKind.partial, value: 3),
        4,
      );
      final completeLowValue = heatmapAlphaFor(
        const ModuleDayStatus(kind: ModuleDayStatusKind.complete, value: 2),
        4,
      );
      expect(partialHighValue, lessThan(0.40));
      expect(completeLowValue, greaterThanOrEqualTo(0.55));
      expect(partialHighValue, lessThan(completeLowValue));
    });

    test('complete ratio scales within its band by value/maxValue', () {
      final low = heatmapAlphaFor(
        const ModuleDayStatus(kind: ModuleDayStatusKind.complete, value: 1),
        4,
      );
      final high = heatmapAlphaFor(
        const ModuleDayStatus(kind: ModuleDayStatusKind.complete, value: 4),
        4,
      );
      expect(low, greaterThanOrEqualTo(0.55));
      expect(high, lessThanOrEqualTo(0.95));
      expect(high, greaterThan(low));
    });

    test('a maxValue of 0 does not divide by zero', () {
      expect(
        () => heatmapAlphaFor(
          const ModuleDayStatus(kind: ModuleDayStatusKind.complete, value: 0),
          0,
        ),
        returnsNormally,
      );
    });
  });

  group('HabitHeatmapCalendar widget', () {
    testWidgets('renders a cell per day and calls onDayTap for a past day', (
      tester,
    ) async {
      LocalDate? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitHeatmapCalendar(
              month: const LocalDate(2026, 6, 1),
              today: const LocalDate(2026, 6, 15),
              dayStatus: {
                const LocalDate(2026, 6, 5): const ModuleDayStatus(
                  kind: ModuleDayStatusKind.complete,
                  value: 2000,
                ),
              },
              accentColor: Colors.blue,
              maxValue: 2000,
              onDayTap: (day) => tapped = day,
            ),
          ),
        ),
      );

      await tester.tap(find.text('5'));
      expect(tapped, const LocalDate(2026, 6, 5));
    });

    testWidgets('does not wire onDayTap for a day after today', (
      tester,
    ) async {
      LocalDate? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitHeatmapCalendar(
              month: const LocalDate(2026, 6, 1),
              today: const LocalDate(2026, 6, 15),
              dayStatus: const {},
              accentColor: Colors.blue,
              maxValue: 1,
              onDayTap: (day) => tapped = day,
            ),
          ),
        ),
      );

      // The 20th is after `today` (the 15th) — tapping it must not fire.
      await tester.tap(find.text('20'), warnIfMissed: false);
      expect(tapped, isNull);
    });

    testWidgets('the complete-cell color is measurably distinct from '
        'the neutral surface in both light and dark themes', (tester) async {
      Future<Color?> renderedColor(Brightness brightness) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: HabitHeatmapCalendar(
                month: const LocalDate(2026, 6, 1),
                today: const LocalDate(2026, 6, 15),
                dayStatus: {
                  const LocalDate(2026, 6, 5): const ModuleDayStatus(
                    kind: ModuleDayStatusKind.complete,
                    value: 10,
                  ),
                },
                accentColor: Colors.blue,
                maxValue: 10,
                onDayTap: (_) {},
              ),
            ),
          ),
        );
        final container = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('5'),
                matching: find.byType(Container),
              )
              .first,
        );
        return (container.decoration as BoxDecoration?)?.color;
      }

      final lightColor = await renderedColor(Brightness.light);
      final darkColor = await renderedColor(Brightness.dark);
      final lightSurface = ThemeData(
        brightness: Brightness.light,
      ).colorScheme.surfaceContainerHighest;
      final darkSurface = ThemeData(
        brightness: Brightness.dark,
      ).colorScheme.surfaceContainerHighest;
      expect(lightColor, isNot(equals(lightSurface)));
      expect(darkColor, isNot(equals(darkSurface)));
    });

    testWidgets('a complete-cell has a Semantics label describing its status', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitHeatmapCalendar(
              month: const LocalDate(2026, 6, 1),
              today: const LocalDate(2026, 6, 15),
              dayStatus: {
                const LocalDate(2026, 6, 5): const ModuleDayStatus(
                  kind: ModuleDayStatusKind.complete,
                  value: 2200,
                ),
              },
              accentColor: Colors.blue,
              maxValue: 2200,
              onDayTap: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('2026-06-05, complete, 2200'),
        findsOneWidget,
      );
      semanticsHandle.dispose();
    });
  });
}

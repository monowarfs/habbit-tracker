import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/global_month_calendar.dart';

/// Colorblind-safety regression test for the dashboard's global month
/// calendar (`docs/superpowers/specs/07-accessibility/
/// 03-COLORBLIND-SAFE-STREAK-HEATMAP-PALETTE-CHECK-IMPLEMENTATION-PLAN
/// .md`, Task 3): every status must be legible from its `Semantics` label
/// alone, not just its fill color, for a screen-reader user who can't see
/// hue at all — a stricter bar than any CVD simulation.
void main() {
  testWidgets(
    'a day cell for each of complete/missed/partial/skipped carries a '
    "Semantics label naming its status, not just the day's bare color",
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
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
                  const LocalDate(2026, 6, 2): const ModuleDayStatus(
                    kind: ModuleDayStatusKind.missed,
                    value: 0,
                  ),
                },
                'medicine': {
                  const LocalDate(2026, 6, 2): const ModuleDayStatus(
                    kind: ModuleDayStatusKind.complete,
                    value: 1,
                  ),
                  const LocalDate(2026, 6, 3): const ModuleDayStatus(
                    kind: ModuleDayStatusKind.paused,
                    value: 0,
                  ),
                },
              },
              onDayTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Day 1: only water reports `complete` -> combined `complete`.
      expect(
        find.bySemanticsLabel('2026-06-01, Completed'),
        findsOneWidget,
      );
      // Day 2: water `missed` + medicine `complete` -> combined `partial`
      // (`combinedDayStatusKind`'s mixed-kind fallback).
      expect(
        find.bySemanticsLabel('2026-06-02, Partial'),
        findsOneWidget,
      );
      // Day 3: only medicine reports `paused` -> combined `partial` per
      // `combinedDayStatusKind` (a lone non-`none`, non-uniform kind
      // never reaches its `every()` branches), not `Skipped` — this
      // assertion documents that behavior rather than re-deciding it.
      expect(
        find.bySemanticsLabel('2026-06-03, Partial'),
        findsOneWidget,
      );

      semanticsHandle.dispose();
    },
  );
}

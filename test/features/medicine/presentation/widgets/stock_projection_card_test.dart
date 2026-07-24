import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/medicine/domain/entities/stock_projection.dart';
import 'package:habit_tracker/features/medicine/presentation/widgets/stock_projection_card.dart';
import 'package:intl/intl.dart';

Future<void> _pump(WidgetTester tester, StockProjection projection) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: StockProjectionCard(projection: projection)),
    ),
  );
}

void main() {
  testWidgets(
    'a high-confidence projection shows the projection body with no '
    'footnote',
    (tester) async {
      final projectedDate = DateTime.utc(2026, 7, 20);
      await _pump(
        tester,
        StockProjection(
          projectedDate: projectedDate,
          daysRemaining: 20,
          averageRatePerDay: 1,
          sampleSize: 15,
          confidence: 'high',
          currentStock: 20,
        ),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final expectedDate = DateFormat.yMMMd(
        'en',
      ).format(projectedDate.toLocal());
      expect(
        find.text(l10n.stockProjectionBody(20, expectedDate)),
        findsOneWidget,
      );
      expect(find.text(l10n.stockProjectionLowConfidence), findsNothing);
    },
  );

  testWidgets('a low-confidence projection shows the footnote', (
    tester,
  ) async {
    await _pump(
      tester,
      StockProjection(
        projectedDate: DateTime.utc(2026, 7, 5),
        daysRemaining: 5,
        averageRatePerDay: 2,
        sampleSize: 2,
        confidence: 'low',
        currentStock: 10,
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.stockProjectionLowConfidence), findsOneWidget);
  });

  testWidgets('a null projection shows "not enough data"', (tester) async {
    await _pump(
      tester,
      const StockProjection(
        sampleSize: 0,
        confidence: 'low',
        currentStock: 30,
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.stockProjectionNoData), findsOneWidget);
    // No footnote piled on top of the no-data message.
    expect(find.text(l10n.stockProjectionLowConfidence), findsNothing);
  });

  testWidgets('zero stock shows "Stock depleted"', (tester) async {
    await _pump(
      tester,
      const StockProjection(
        daysRemaining: 0,
        sampleSize: 0,
        confidence: 'low',
        currentStock: 0,
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.stockProjectionAlreadyOut), findsOneWidget);
    expect(find.text(l10n.stockProjectionLowConfidence), findsNothing);
  });
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/dismissible_hint_card.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_settings_screen.dart';

Future<void> _pumpWaterSettings(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WaterSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('shows three goal presets, Standard pre-selected for the '
      'seeded 2000ml default', (tester) async {
    await _pumpWaterSettings(tester, db);

    expect(find.text('Light · 1.5L'), findsOneWidget);
    expect(find.text('Standard · 2L'), findsOneWidget);
    expect(find.text('Active · 3L'), findsOneWidget);

    final standardChip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text('Standard · 2L'),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(standardChip.selected, isTrue);

    final lightChip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text('Light · 1.5L'),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(lightChip.selected, isFalse);

    await disposeTree(tester);
  });

  testWidgets('tapping a preset updates the goal field and its own '
      'selected state', (tester) async {
    await _pumpWaterSettings(tester, db);

    await tester.tap(find.text('Light · 1.5L'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '1500'), findsOneWidget);

    final lightChip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text('Light · 1.5L'),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(lightChip.selected, isTrue);

    await disposeTree(tester);
  });

  testWidgets(
    'shows the hydration hint card until dismissed, then never again',
    (tester) async {
      await _pumpWaterSettings(tester, db);

      expect(
        find.text(
          'Water helps regulate temperature, joints, and energy — most '
          "adults need roughly 2-3 liters a day, more if it's hot or "
          "you're active.",
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(DismissibleHintCard), findsNothing);

      await disposeTree(tester);
      await _pumpWaterSettings(tester, db);
      expect(find.byType(DismissibleHintCard), findsNothing);

      await disposeTree(tester);
    },
  );
}

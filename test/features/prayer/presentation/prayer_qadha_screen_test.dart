import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/dismissible_hint_card.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_qadha_screen.dart';

Future<void> _pumpPrayerQadha(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PrayerQadhaScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    'shows the Qadha hint card until dismissed, then never again',
    (tester) async {
      await _pumpPrayerQadha(tester, db);

      expect(
        find.text(
          "Qadha lets you make up a missed prayer later — it's a normal "
          'part of practice, not a separate obligation on top of your '
          'regular five.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DismissibleHintCard), findsNothing);

      await disposeTree(tester);
      await _pumpPrayerQadha(tester, db);
      expect(find.byType(DismissibleHintCard), findsNothing);

      await disposeTree(tester);
    },
  );
}

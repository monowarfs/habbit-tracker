import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/xp_level_display.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 8, 5);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpDisplay(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: XpLevelDisplay()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('zero XP shows Level 1 and a 0-progress bar', (tester) async {
    await pumpDisplay(tester);

    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('0/100 XP to next level'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.0);

    await disposeTree(tester);
  });

  testWidgets('shows progress within the current level', (tester) async {
    final repository = XpRepository(db);
    await repository.awardXp(
      moduleId: 'water',
      eventType: 'action',
      amount: 150,
      now: now,
    );

    await pumpDisplay(tester);

    // 150 XP: level 2 (threshold 100), 50 XP into a 200-XP-wide level.
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('50/200 XP to next level'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('reacts live to a new XP award', (tester) async {
    await pumpDisplay(tester);
    expect(find.text('Level 1'), findsOneWidget);

    await XpRepository(db).awardXp(
      moduleId: 'water',
      eventType: 'day_complete',
      amount: 100,
      now: now,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Level 2'), findsOneWidget);

    await disposeTree(tester);
  });
}

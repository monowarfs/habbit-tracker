import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/personal_record_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/personal_record_section.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget buildApp({required int currentStreak}) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        extensions: const [
          AppSemanticColors.light,
          ModuleThemeAccents.defaults,
        ],
      ),
      home: Scaffold(
        body: PersonalRecordSection(
          moduleId: 'water',
          currentStreak: currentStreak,
          accentColor: Colors.teal,
        ),
      ),
    ),
  );

  testWidgets('shows the persisted record when the streak does not beat it', (
    tester,
  ) async {
    await PersonalRecordRepository(
      db,
    ).setRecord(
      moduleId: 'water',
      recordType: 'longest_streak',
      value: 20,
      profileId: 'system',
    );

    await tester.pumpWidget(buildApp(currentStreak: 5));
    await tester.pumpAndSettle();

    expect(find.text('Longest Streak: 20 days'), findsOneWidget);
    expect(find.text('New Record!'), findsNothing);
  });

  testWidgets(
    'shows a "New Record!" badge and celebration when the streak beats the '
    'persisted record',
    (tester) async {
      await PersonalRecordRepository(
        db,
      ).setRecord(
        moduleId: 'water',
        recordType: 'longest_streak',
        value: 5,
        profileId: 'system',
      );

      await tester.pumpWidget(buildApp(currentStreak: 8));
      await tester.pumpAndSettle();

      expect(find.text('Longest Streak: 8 days'), findsOneWidget);
      expect(find.text('Previous: 5 days'), findsOneWidget);
      // Badge chip + celebration overlay title both read "New Record!".
      expect(find.text('New Record!'), findsWidgets);
    },
  );

  testWidgets('creates the record on first-ever check for a module', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(currentStreak: 3));
    await tester.pumpAndSettle();

    final record =
        await PersonalRecordRepository(
          db,
        ).getRecord(
          moduleId: 'water',
          recordType: 'longest_streak',
          profileId: 'system',
        );
    expect(record!.recordValue, 3);
  });
}

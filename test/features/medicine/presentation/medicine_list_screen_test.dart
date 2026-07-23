import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/illustrations/pill_calendar_painter.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_list_screen.dart';

Future<void> _pumpMedicineList(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MedicineListScreen(),
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

  testWidgets('empty active tab: shows the message and its illustration '
      "in Medicine's own accent color", (tester) async {
    await _pumpMedicineList(tester, db);

    expect(find.text('No medicines yet'), findsOneWidget);
    final customPaint = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .firstWhere((w) => w.painter is PillCalendarPainter);
    final painter = customPaint.painter! as PillCalendarPainter;
    expect(painter.color, ModuleAccents.medicine);

    await disposeTree(tester);
  });

  testWidgets('populated active tab: the empty-state message no longer '
      'shows', (tester) async {
    final repo = MedicineRepositoryImpl(db);
    await repo.createMedicine(name: 'Amoxicillin', stockEnabled: false);

    await _pumpMedicineList(tester, db);

    // Only assert the text, not "no PillCalendarPainter anywhere" — the
    // Archived tab's own `_MedicineListView` may also be built by
    // `TabBarView` even off-screen, and it's still legitimately empty
    // (nothing was archived), so it would still paint its own
    // illustration. That's correct behavior, not something to assert
    // against here.
    expect(find.text('No medicines yet'), findsNothing);

    await disposeTree(tester);
  });
}

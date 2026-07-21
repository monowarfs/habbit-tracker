import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
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

/// Finds the vertical position of [text] relative to the other items in
/// the list, to assert drag-to-reorder actually moved it.
double _yOf(WidgetTester tester, String text) =>
    tester.getCenter(find.text(text)).dy;

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('empty state: no medicines yet', (tester) async {
    await _pumpMedicineList(tester, db);

    expect(find.text('No medicines yet'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('active tab renders medicines in sortOrder', (tester) async {
    final repo = MedicineRepositoryImpl(db);
    await repo.createMedicine(name: 'Amoxicillin', stockEnabled: false);
    await repo.createMedicine(name: 'Ibuprofen', stockEnabled: false);

    await _pumpMedicineList(tester, db);

    expect(_yOf(tester, 'Amoxicillin'), lessThan(_yOf(tester, 'Ibuprofen')));
    await disposeTree(tester);
  });
}

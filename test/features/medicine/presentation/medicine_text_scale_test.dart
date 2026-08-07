import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_detail_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_home_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_list_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_stats_screen.dart';

import '../../../accessibility/text_scale_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Widget app(Widget home) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(isBangla: false),
      home: home,
    ),
  );

  testWidgets('MedicineHomeScreen at 2.0x: no overflow', (tester) async {
    await pumpAtTextScale(tester, app(const MedicineHomeScreen()), 2);
    await disposeTree(tester);
  });

  testWidgets('MedicineListScreen at 2.0x: no overflow (dose-timeline rows)', (
    tester,
  ) async {
    final repo = MedicineRepositoryImpl(db);
    await repo.createMedicine(name: 'Amoxicillin', stockEnabled: false);

    // Tall surface so dense dose-timeline rows stay within the sliver
    // cache extent at 2x text.
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAtTextScale(tester, app(const MedicineListScreen()), 2);
    await disposeTree(tester);
  });

  testWidgets('MedicineDetailScreen at 2.0x: no overflow', (tester) async {
    final repo = MedicineRepositoryImpl(db);
    final created = await repo.createMedicine(
      name: 'Amoxicillin',
      stockEnabled: true,
      stockCount: 30,
      stockThreshold: 5,
    );
    final medicineId = (created as Success<Medicine>).value.id;
    await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );

    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAtTextScale(
      tester,
      app(MedicineDetailScreen(medicineId: medicineId)),
      2,
    );
    await disposeTree(tester);
  });

  testWidgets('MedicineStatsScreen at 2.0x: no overflow', (tester) async {
    await pumpAtTextScale(tester, app(const MedicineStatsScreen()), 2);
    await disposeTree(tester);
  });
}

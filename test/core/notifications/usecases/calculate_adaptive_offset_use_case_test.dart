import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:habit_tracker/core/notifications/usecases/calculate_adaptive_offset_use_case.dart';

import '../../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late NotificationLedgerRepository ledgerRepo;
  late CalculateAdaptiveOffsetUseCase useCase;
  final now = DateTime.utc(2026, 6, 30);

  setUp(() {
    db = testDatabase();
    ledgerRepo = NotificationLedgerRepository(db);
    useCase = CalculateAdaptiveOffsetUseCase(ledgerRepo);
  });

  tearDown(() => db.close());

  Future<void> seedDoneRow({
    required String id,
    required String moduleId,
    required String sourceType,
    required DateTime scheduledFor,
    required int offsetMinutes,
  }) async {
    await ledgerRepo.insertScheduled(
      id: id,
      moduleId: moduleId,
      sourceType: sourceType,
      sourceId: id,
      title: 'title',
      body: 'body',
      scheduledFor: scheduledFor,
      deepLinkRoute: '/$moduleId',
    );
    await ledgerRepo.markActioned(
      id,
      action: 'done',
      actionAt: scheduledFor.add(Duration(minutes: offsetMinutes)),
    );
  }

  test('empty ledger returns empty list', () async {
    expect(await useCase.execute(now: now), isEmpty);
  });

  test('below minSamples is excluded', () async {
    for (var i = 0; i < 9; i++) {
      await seedDoneRow(
        id: 'r$i',
        moduleId: 'water',
        sourceType: 'water_reminder',
        scheduledFor: DateTime.utc(2026, 6, 20, 8).add(Duration(days: i)),
        offsetMinutes: 15,
      );
    }
    expect(await useCase.execute(now: now), isEmpty);
  });

  test('consistent offset with odd sample count -> correct median', () async {
    for (var i = 0; i < 11; i++) {
      await seedDoneRow(
        id: 'r$i',
        moduleId: 'water',
        sourceType: 'water_reminder',
        scheduledFor: DateTime.utc(2026, 6, 1, 8).add(Duration(days: i)),
        offsetMinutes: 30,
      );
    }
    final result = await useCase.execute(now: now);
    expect(result, hasLength(1));
    expect(result.single.moduleId, 'water');
    expect(result.single.sourceType, 'water_reminder');
    expect(result.single.offsetMinutes, 30);
    expect(result.single.sampleCount, 11);
    expect(result.single.confidence, 'medium');
  });

  test('alternating offsets with even sample count -> median of middle two', () async {
    final offsets = [10, 20, 10, 20, 10, 20, 10, 20, 10, 20];
    for (var i = 0; i < offsets.length; i++) {
      await seedDoneRow(
        id: 'r$i',
        moduleId: 'water',
        sourceType: 'water_reminder',
        scheduledFor: DateTime.utc(2026, 6, 1, 8).add(Duration(days: i)),
        offsetMinutes: offsets[i],
      );
    }
    final result = await useCase.execute(now: now);
    expect(result.single.offsetMinutes, 15);
  });

  test('all-same-time -> 0 offset', () async {
    for (var i = 0; i < 10; i++) {
      await seedDoneRow(
        id: 'r$i',
        moduleId: 'water',
        sourceType: 'water_reminder',
        scheduledFor: DateTime.utc(2026, 6, 1, 8).add(Duration(days: i)),
        offsetMinutes: 0,
      );
    }
    final result = await useCase.execute(now: now);
    expect(result.single.offsetMinutes, 0);
  });

  test('offsets clamp to maxOffsetMinutes', () async {
    for (var i = 0; i < 10; i++) {
      await seedDoneRow(
        id: 'r$i',
        moduleId: 'water',
        sourceType: 'water_reminder',
        scheduledFor: DateTime.utc(2026, 6, 1, 8).add(Duration(days: i)),
        offsetMinutes: 500,
      );
    }
    final result = await useCase.execute(now: now);
    expect(result.single.offsetMinutes, 120);
  });

  test('>=20 samples -> high confidence', () async {
    for (var i = 0; i < 20; i++) {
      await seedDoneRow(
        id: 'r$i',
        moduleId: 'medicine',
        sourceType: 'medicine_dose',
        scheduledFor: DateTime.utc(2026, 6, 1, 8).add(Duration(days: i)),
        offsetMinutes: 5,
      );
    }
    final result = await useCase.execute(now: now);
    expect(result.single.confidence, 'high');
  });

  test('multiple source types produce separate adjustments', () async {
    for (var i = 0; i < 10; i++) {
      await seedDoneRow(
        id: 'water$i',
        moduleId: 'water',
        sourceType: 'water_reminder',
        scheduledFor: DateTime.utc(2026, 6, 1, 8).add(Duration(days: i)),
        offsetMinutes: 10,
      );
    }
    for (var i = 0; i < 10; i++) {
      await seedDoneRow(
        id: 'med$i',
        moduleId: 'medicine',
        sourceType: 'medicine_dose',
        scheduledFor: DateTime.utc(2026, 6, 1, 9).add(Duration(days: i)),
        offsetMinutes: -20,
      );
    }
    final result = await useCase.execute(now: now);
    expect(result, hasLength(2));
    final water = result.firstWhere((r) => r.moduleId == 'water');
    final medicine = result.firstWhere((r) => r.moduleId == 'medicine');
    expect(water.offsetMinutes, 10);
    expect(medicine.offsetMinutes, -20);
  });
}

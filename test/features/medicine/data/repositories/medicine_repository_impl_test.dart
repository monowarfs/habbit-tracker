import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_stock_event.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';

void main() {
  late AppDatabase db;
  late MedicineRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MedicineRepositoryImpl(db);
  });

  tearDown(() => db.close());

  Future<String> seedMedicine() async {
    final result = await repo.createMedicine(
      name: 'Vitamin D',
      stockEnabled: false,
    );
    if (result case Success(:final value)) return value.id;
    throw StateError('seed failed: $result');
  }

  test(
    'allDoses/allStockEvents return restored rows; restoreDose returns the new id',
    () async {
      final medicineId = await seedMedicine();
      final scheduleResult = await repo.createSchedule(
        medicineId: medicineId,
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 6, 1),
      );
      final String scheduleId;
      if (scheduleResult case Success(:final value)) {
        scheduleId = value.id;
      } else {
        throw StateError('seed failed: $scheduleResult');
      }

      final newDoseId = await repo.restoreDose(
        MedicineDose(
          id: 'old-id',
          medicineId: medicineId,
          scheduleId: scheduleId,
          scheduledFor: DateTime.utc(2026, 6, 1, 8),
          storedStatus: MedicineDoseStatus.done,
          graceWindowMinutes: 30,
          stockDeltaApplied: -1,
        ),
      );
      expect(newDoseId, isNot('old-id'));

      await repo.restoreStockEvent(
        MedicineStockEvent(
          id: 'old-event-id',
          medicineId: medicineId,
          doseId: newDoseId,
          delta: -1,
          reason: MedicineStockEventReason.doseTaken,
          occurredAt: DateTime.utc(2026, 6, 1, 8),
        ),
      );

      final doses = await repo.allDoses();
      expect(doses, hasLength(1));
      expect(doses.first.storedStatus, MedicineDoseStatus.done);
      final events = await repo.allStockEvents();
      expect(events, hasLength(1));
      expect(events.first.doseId, newDoseId);
    },
  );

  test(
    'wipeAll deletes medicines, schedules, doses, and stock events',
    () async {
      final medicineId = await seedMedicine();
      await repo.restoreStockEvent(
        MedicineStockEvent(
          id: 'x',
          medicineId: medicineId,
          delta: 10,
          reason: MedicineStockEventReason.manualRefill,
          occurredAt: DateTime.utc(2026, 6),
        ),
      );

      await repo.wipeAll();

      expect(await repo.allMedicines(), isEmpty);
      expect(await repo.allSchedules(), isEmpty);
      expect(await repo.allDoses(), isEmpty);
      expect(await repo.allStockEvents(), isEmpty);
    },
  );
}

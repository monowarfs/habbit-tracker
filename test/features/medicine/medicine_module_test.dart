import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/medicine_module.dart';
import 'package:mocktail/mocktail.dart';

class _MockMedicineRepository extends Mock implements MedicineRepository {}

void main() {
  late _MockMedicineRepository repo;
  late MedicineModule module;

  setUpAll(() {
    // mocktail requires a fallback instance for any non-primitive type used
    // with `any()` (here, `dosesInRange(LocalDate, LocalDate)`).
    registerFallbackValue(const LocalDate(2026, 1, 1));
  });

  setUp(() {
    repo = _MockMedicineRepository();
    module = MedicineModule(repo);
  });

  test('pendingNotifications maps due doses within 3 days to '
      'PendingNotification with sourceType medicine_dose', () async {
    final now = DateTime.utc(2026, 6, 1, 7);
    final dose = MedicineDose(
      id: 'd1',
      medicineId: 'm1',
      scheduleId: 's1',
      scheduledFor: DateTime.utc(2026, 6, 1, 8),
      storedStatus: MedicineDoseStatus.upcoming,
      graceWindowMinutes: 30,
    );
    const medicine = Medicine(id: 'm1', name: 'X', stockEnabled: false);

    when(() => repo.materializeDoses(any())).thenAnswer((_) async {});
    when(
      () => repo.dosesInRange(any(), any()),
    ).thenAnswer((_) async => [dose]);
    when(() => repo.medicineById('m1')).thenAnswer((_) async => medicine);
    when(
      () => repo.medicinesNeedingLowStockAlert(),
    ).thenAnswer((_) async => []);

    await withClock(Clock.fixed(now), () async {
      final notifications = await module.pendingNotifications();
      expect(notifications, hasLength(1));
      expect(notifications.single.sourceType, 'medicine_dose');
      expect(notifications.single.deepLinkRoute, '/medicine/dose/d1');
    });
  });

  test('pendingNotifications excludes doses whose medicine is archived '
      '(FR-M-10 defensive re-check)', () async {
    final now = DateTime.utc(2026, 6, 1, 7);
    final dose = MedicineDose(
      id: 'd1',
      medicineId: 'm1',
      scheduleId: 's1',
      scheduledFor: DateTime.utc(2026, 6, 1, 8),
      storedStatus: MedicineDoseStatus.upcoming,
      graceWindowMinutes: 30,
    );
    final archivedMedicine = Medicine(
      id: 'm1',
      name: 'X',
      stockEnabled: false,
      archivedAt: DateTime.utc(2026, 5),
    );

    when(() => repo.materializeDoses(any())).thenAnswer((_) async {});
    when(
      () => repo.dosesInRange(any(), any()),
    ).thenAnswer((_) async => [dose]);
    when(
      () => repo.medicineById('m1'),
    ).thenAnswer((_) async => archivedMedicine);
    when(
      () => repo.medicinesNeedingLowStockAlert(),
    ).thenAnswer((_) async => []);

    await withClock(Clock.fixed(now), () async {
      final notifications = await module.pendingNotifications();
      expect(notifications, isEmpty);
    });
  });

  test('pendingNotifications includes a low_stock notification for '
      'medicines returned by medicinesNeedingLowStockAlert', () async {
    final now = DateTime.utc(2026, 6, 1, 7);
    final medicine = Medicine(
      id: 'm1',
      name: 'X',
      stockEnabled: true,
      stockCount: 0,
      stockThreshold: 5,
      lowStockNotifiedAt: now,
    );
    when(() => repo.materializeDoses(any())).thenAnswer((_) async {});
    when(() => repo.dosesInRange(any(), any())).thenAnswer((_) async => []);
    when(
      () => repo.medicinesNeedingLowStockAlert(),
    ).thenAnswer((_) async => [medicine]);

    await withClock(Clock.fixed(now), () async {
      final notifications = await module.pendingNotifications();
      expect(
        notifications.where((n) => n.sourceType == 'low_stock'),
        hasLength(1),
      );
    });
  });

  test('onNotificationAction(done) marks the dose done', () async {
    when(
      () => repo.markDoseDone(
        any(),
        fromOtherSource: any(named: 'fromOtherSource'),
      ),
    ).thenAnswer((_) async => const Result.success(null));

    await module.onNotificationAction('d1', NotificationActionType.done);

    verify(
      () => repo.markDoseDone('d1', fromOtherSource: false),
    ).called(1);
  });

  test('onNotificationAction(skip) marks the dose skipped', () async {
    when(
      () => repo.markDoseSkipped(any()),
    ).thenAnswer((_) async => const Result.success(null));

    await module.onNotificationAction('d1', NotificationActionType.skip);

    verify(() => repo.markDoseSkipped('d1')).called(1);
  });

  test('onNotificationAction(snooze) never mutates dose data', () async {
    await module.onNotificationAction('d1', NotificationActionType.snooze);
    verifyNever(
      () => repo.markDoseDone(
        any(),
        fromOtherSource: any(named: 'fromOtherSource'),
      ),
    );
    verifyNever(() => repo.markDoseSkipped(any()));
  });
}

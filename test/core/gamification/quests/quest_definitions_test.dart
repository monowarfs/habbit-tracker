import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/quests/medicine_quests.dart';
import 'package:habit_tracker/core/gamification/quests/prayer_quests.dart';
import 'package:habit_tracker/core/gamification/quests/water_quests.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:mocktail/mocktail.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id, this._byDay);
  @override
  final String id;
  final Map<LocalDate, ModuleDayStatus> _byDay;

  @override
  ModuleMetadata get metadata => ModuleMetadata(
    displayName: id,
    icon: Icons.circle,
    accentColor: Colors.blue,
  );

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(
    DateRange range, {
    String? profileId,
  }) async => _byDay;
}

class _MockMedicineRepository extends Mock implements MedicineRepository {}

const _weekRange = DateRange(
  start: LocalDate(2026, 8, 3),
  end: LocalDate(2026, 8, 9),
);

void main() {
  group('waterQuestDefinitions', () {
    test("has 2 quests with the plan's targets", () {
      final module = _FakeModule('water', const {});
      final defs = waterQuestDefinitions(module, _weekRange);
      expect(defs.map((d) => d.questKey), [
        'water_goal_5_of_7',
        'water_no_skip_week',
      ]);
      expect(defs[0].target, 5);
      expect(defs[1].target, 7);
      expect(defs.every((d) => d.moduleId == 'water'), isTrue);
    });

    test('goal_5_of_7 counts only complete days', () async {
      final module = _FakeModule('water', {
        for (var d = 3; d <= 9; d++)
          LocalDate(2026, 8, d): ModuleDayStatus(
            kind: d <= 5
                ? ModuleDayStatusKind.complete
                : ModuleDayStatusKind.partial,
            value: 0,
          ),
      });
      final defs = waterQuestDefinitions(module, _weekRange);
      expect(await defs[0].progressEvaluator(), 3);
    });

    test('no_skip_week counts complete and partial days', () async {
      final module = _FakeModule('water', {
        const LocalDate(2026, 8, 3): const ModuleDayStatus(
          kind: ModuleDayStatusKind.complete,
          value: 0,
        ),
        const LocalDate(2026, 8, 4): const ModuleDayStatus(
          kind: ModuleDayStatusKind.partial,
          value: 0,
        ),
        const LocalDate(2026, 8, 5): const ModuleDayStatus(
          kind: ModuleDayStatusKind.missed,
          value: 0,
        ),
      });
      final defs = waterQuestDefinitions(module, _weekRange);
      expect(await defs[1].progressEvaluator(), 2);
    });
  });

  group('prayerQuestDefinitions', () {
    test("has 2 quests with the plan's targets", () {
      final module = _FakeModule('prayer', const {});
      final defs = prayerQuestDefinitions(module, _weekRange);
      expect(defs.map((d) => d.questKey), [
        'prayer_5_of_7',
        'prayer_no_skip_week',
      ]);
      expect(defs[0].target, 5);
      expect(defs[1].target, 7);
    });
  });

  group('medicineQuestDefinitions', () {
    late _MockMedicineRepository repository;

    setUp(() => repository = _MockMedicineRepository());

    test("has 2 quests with the plan's targets", () {
      final module = _FakeModule('medicine', const {});
      final defs = medicineQuestDefinitions(
        module,
        repository,
        _weekRange,
        profileId: 'system',
      );
      expect(defs.map((d) => d.questKey), [
        'medicine_perfect_week',
        'medicine_90_percent',
      ]);
      expect(defs[0].target, 7);
      expect(defs[1].target, 90);
    });

    test('90_percent computes on-time+late as a percentage of total', () async {
      when(
        () => repository.dosesInRange(
          _weekRange.start,
          _weekRange.end,
          profileId: 'system',
        ),
      ).thenAnswer(
        (_) async => [
          MedicineDose(
            id: '1',
            medicineId: 'm',
            scheduleId: 's',
            scheduledFor: DateTime(2026, 8, 3, 8),
            storedStatus: MedicineDoseStatus.done,
            graceWindowMinutes: 30,
            statusChangedAt: DateTime(2026, 8, 3, 8),
          ),
          MedicineDose(
            id: '2',
            medicineId: 'm',
            scheduleId: 's',
            scheduledFor: DateTime(2026, 8, 4, 8),
            storedStatus: MedicineDoseStatus.done,
            graceWindowMinutes: 30,
            statusChangedAt: DateTime(2026, 8, 4, 8),
          ),
          MedicineDose(
            id: '3',
            medicineId: 'm',
            scheduleId: 's',
            scheduledFor: DateTime(2026, 8, 5, 8),
            storedStatus: MedicineDoseStatus.skipped,
            graceWindowMinutes: 30,
          ),
        ],
      );
      final module = _FakeModule('medicine', const {});
      final defs = medicineQuestDefinitions(
        module,
        repository,
        _weekRange,
        profileId: 'system',
      );
      // 2 of 3 doses taken -> 67%.
      expect(await defs[1].progressEvaluator(), 67);
    });

    test('90_percent is 0 when there are no doses this week', () async {
      when(
        () => repository.dosesInRange(
          _weekRange.start,
          _weekRange.end,
          profileId: 'system',
        ),
      ).thenAnswer((_) async => []);
      final module = _FakeModule('medicine', const {});
      final defs = medicineQuestDefinitions(
        module,
        repository,
        _weekRange,
        profileId: 'system',
      );
      expect(await defs[1].progressEvaluator(), 0);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/boss/boss_quest_definitions.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

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

const _weekRange = DateRange(
  start: LocalDate(2026, 8, 3),
  end: LocalDate(2026, 8, 9),
);

void main() {
  test(
    'all 3 modules have a boss definition with a higher-than-regular target',
    () {
      for (final id in ['water', 'medicine', 'prayer']) {
        final module = _FakeModule(id, const {});
        final def = bossDefinitionFor(id, module, _weekRange);
        expect(def, isNotNull, reason: '$id should have a boss definition');
        expect(def!.moduleId, id);
      }
      expect(
        bossDefinitionFor(
          'water',
          _FakeModule('water', const {}),
          _weekRange,
        )!.target,
        6,
      );
      expect(
        bossDefinitionFor(
          'medicine',
          _FakeModule('medicine', const {}),
          _weekRange,
        )!.target,
        7,
      );
      expect(
        bossDefinitionFor(
          'prayer',
          _FakeModule('prayer', const {}),
          _weekRange,
        )!.target,
        5,
      );
    },
  );

  test('an unknown module id has no boss definition', () {
    expect(
      bossDefinitionFor('sleep', _FakeModule('sleep', const {}), _weekRange),
      isNull,
    );
  });

  test('water boss progress counts only complete days', () async {
    final module = _FakeModule('water', {
      for (var d = 3; d <= 9; d++)
        LocalDate(2026, 8, d): ModuleDayStatus(
          kind: d <= 6
              ? ModuleDayStatusKind.complete
              : ModuleDayStatusKind.partial,
          value: 0,
        ),
    });
    final def = bossDefinitionFor('water', module, _weekRange)!;
    expect(await def.progressEvaluator(), 4);
  });
}

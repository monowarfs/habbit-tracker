import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/combo/combo_detector.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id, this._kind);
  @override
  final String id;
  final ModuleDayStatusKind _kind;

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
  }) async => {
    range.start: ModuleDayStatus(kind: _kind, value: 0),
  };
}

const _today = LocalDate(2026, 8, 5);

void main() {
  const detector = ComboDetector();

  test('2+ modules all complete -> true', () async {
    final modules = [
      _FakeModule('water', ModuleDayStatusKind.complete),
      _FakeModule('medicine', ModuleDayStatusKind.complete),
    ];
    expect(
      await detector.isComboDay(date: _today, modules: modules),
      isTrue,
    );
  });

  test('a single enabled module never combos, even if complete', () async {
    final modules = [_FakeModule('water', ModuleDayStatusKind.complete)];
    expect(
      await detector.isComboDay(date: _today, modules: modules),
      isFalse,
    );
  });

  test('partial completion -> false', () async {
    final modules = [
      _FakeModule('water', ModuleDayStatusKind.complete),
      _FakeModule('medicine', ModuleDayStatusKind.partial),
    ];
    expect(
      await detector.isComboDay(date: _today, modules: modules),
      isFalse,
    );
  });

  test('zero modules -> false', () async {
    expect(await detector.isComboDay(date: _today, modules: []), isFalse);
  });

  test('completedModuleCount counts only complete-kind days', () async {
    final modules = [
      _FakeModule('water', ModuleDayStatusKind.complete),
      _FakeModule('medicine', ModuleDayStatusKind.partial),
      _FakeModule('prayer', ModuleDayStatusKind.complete),
    ];
    expect(
      await detector.completedModuleCount(date: _today, modules: modules),
      2,
    );
  });
}

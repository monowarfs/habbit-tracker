import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/combo/combo_detector.dart';
import 'package:habit_tracker/core/gamification/combo/combo_event_emitter.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';
import 'package:habit_tracker/core/gamification/xp_values.dart';
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
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async => {
    range.start: ModuleDayStatus(kind: _kind, value: 0),
  };
}

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 8, 5);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a combo day awards XP and returns the event', () async {
    final modules = [
      _FakeModule('water', ModuleDayStatusKind.complete),
      _FakeModule('medicine', ModuleDayStatusKind.complete),
    ];
    final emitter = ComboEventEmitter(
      comboDetector: const ComboDetector(),
      modules: modules,
      xpRepository: XpRepository(db),
    );

    final event = await emitter.checkAndEmit(now: now);

    expect(event, isNotNull);
    expect(event!.modulesCompleted, 2);
    expect(event.totalActiveModules, 2);
    expect(event.date, const LocalDate(2026, 8, 5));
    expect(await XpRepository(db).totalXp(), XpValues.comboBonus);
  });

  test('a non-combo day returns null and awards nothing', () async {
    final modules = [
      _FakeModule('water', ModuleDayStatusKind.complete),
      _FakeModule('medicine', ModuleDayStatusKind.partial),
    ];
    final emitter = ComboEventEmitter(
      comboDetector: const ComboDetector(),
      modules: modules,
      xpRepository: XpRepository(db),
    );

    final event = await emitter.checkAndEmit(now: now);

    expect(event, isNull);
    expect(await XpRepository(db).totalXp(), 0);
  });

  test(
    'a second checkAndEmit the same day returns null (already awarded)',
    () async {
      final modules = [
        _FakeModule('water', ModuleDayStatusKind.complete),
        _FakeModule('medicine', ModuleDayStatusKind.complete),
      ];
      final emitter = ComboEventEmitter(
        comboDetector: const ComboDetector(),
        modules: modules,
        xpRepository: XpRepository(db),
      );

      final first = await emitter.checkAndEmit(now: now);
      final second = await emitter.checkAndEmit(now: now);

      expect(first, isNotNull);
      expect(second, isNull);
      // Only one award, not two.
      expect(await XpRepository(db).totalXp(), XpValues.comboBonus);
    },
  );

  test('a single module never combos even when complete', () async {
    final modules = [_FakeModule('water', ModuleDayStatusKind.complete)];
    final emitter = ComboEventEmitter(
      comboDetector: const ComboDetector(),
      modules: modules,
      xpRepository: XpRepository(db),
    );

    expect(await emitter.checkAndEmit(now: now), isNull);
  });

  test('the next day can combo again independently', () async {
    final modules = [
      _FakeModule('water', ModuleDayStatusKind.complete),
      _FakeModule('medicine', ModuleDayStatusKind.complete),
    ];
    final xpRepository = XpRepository(db);
    final emitter = ComboEventEmitter(
      comboDetector: const ComboDetector(),
      modules: modules,
      xpRepository: xpRepository,
    );

    await emitter.checkAndEmit(now: now);
    final tomorrow = await emitter.checkAndEmit(
      now: now.add(const Duration(days: 1)),
    );

    expect(tomorrow, isNotNull);
    expect(await xpRepository.totalXp(), XpValues.comboBonus * 2);
  });
}

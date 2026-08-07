import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/personal_record_repository.dart';
import 'package:habit_tracker/core/analytics/record_backfill.dart';
import 'package:habit_tracker/core/database/app_database.dart';
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
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async =>
      _byDay;
}

void main() {
  late AppDatabase db;
  late PersonalRecordRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PersonalRecordRepository(db);
  });

  tearDown(() => db.close());

  const range = DateRange(
    start: LocalDate(2026, 6, 1),
    end: LocalDate(2026, 6, 10),
  );

  test('persists the all-time longest streak computed from history', () async {
    final module = _FakeModule('water', {
      for (var d = 1; d <= 10; d++)
        LocalDate(2026, 6, d): ModuleDayStatus(
          kind: d <= 6
              ? ModuleDayStatusKind.complete
              : ModuleDayStatusKind.missed,
          value: 1,
        ),
    });

    await backfillPersonalRecords(modules: [module], repo: repo, range: range);

    final record = await repo.getRecord(
      moduleId: 'water',
      recordType: 'longest_streak',
    );
    expect(record!.recordValue, 6);
  });

  test('is a no-op for a module that already has a record', () async {
    await repo.setRecord(
      moduleId: 'water',
      recordType: 'longest_streak',
      value: 99,
    );
    final module = _FakeModule('water', {
      const LocalDate(2026, 6, 1): const ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: 1,
      ),
    });

    await backfillPersonalRecords(modules: [module], repo: repo, range: range);

    final record = await repo.getRecord(
      moduleId: 'water',
      recordType: 'longest_streak',
    );
    expect(record!.recordValue, 99);
  });

  test('does not create a record when history has no complete days', () async {
    final module = _FakeModule('medicine', {
      const LocalDate(2026, 6, 1): const ModuleDayStatus(
        kind: ModuleDayStatusKind.missed,
        value: 0,
      ),
    });

    await backfillPersonalRecords(modules: [module], repo: repo, range: range);

    expect(
      await repo.getRecord(moduleId: 'medicine', recordType: 'longest_streak'),
      isNull,
    );
  });

  test('backfills each module independently', () async {
    final water = _FakeModule('water', {
      const LocalDate(2026, 6, 1): const ModuleDayStatus(
        kind: ModuleDayStatusKind.complete,
        value: 1,
      ),
    });
    final prayer = _FakeModule('prayer', {
      for (var d = 1; d <= 3; d++)
        LocalDate(2026, 6, d): const ModuleDayStatus(
          kind: ModuleDayStatusKind.complete,
          value: 1,
        ),
    });

    await backfillPersonalRecords(
      modules: [water, prayer],
      repo: repo,
      range: range,
    );

    expect(
      (await repo.getRecord(
        moduleId: 'water',
        recordType: 'longest_streak',
      ))!.recordValue,
      1,
    );
    expect(
      (await repo.getRecord(
        moduleId: 'prayer',
        recordType: 'longest_streak',
      ))!.recordValue,
      3,
    );
  });
}

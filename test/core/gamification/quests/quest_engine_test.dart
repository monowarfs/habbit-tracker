import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/quests/quest_engine.dart';
import 'package:habit_tracker/core/gamification/quests/quest_repository.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:mocktail/mocktail.dart';

const _profileId = 'system';

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

class _MockMedicineRepository extends Mock implements MedicineRepository {}

void main() {
  late AppDatabase db;
  late QuestEngine engine;
  late _MockMedicineRepository medicineRepository;
  // 2026-08-05 is a Wednesday in ISO week 2026-W32 (Monday 2026-08-03).
  final now = DateTime.utc(2026, 8, 5);

  setUpAll(() {
    registerFallbackValue(const LocalDate(2026, 1, 1));
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    medicineRepository = _MockMedicineRepository();
    when(
      () => medicineRepository.dosesInRange(
        any(),
        any(),
        profileId: any(named: 'profileId'),
      ),
    ).thenAnswer((_) async => []);
  });

  tearDown(() => db.close());

  test("generateWeek creates rows for every module's quests", () async {
    final modules = [
      _FakeModule('water', const {}),
      _FakeModule('medicine', const {}),
      _FakeModule('prayer', const {}),
    ];
    engine = QuestEngine(
      repository: QuestRepository(db),
      modules: modules,
      medicineRepository: medicineRepository,
    );
    await engine.generateWeek(now: now, profileId: _profileId);
    final rows = await QuestRepository(
      db,
    ).watchCurrentWeek(weekKey: '2026-W32', profileId: _profileId).first;
    // 2 water + 2 medicine + 2 prayer + 1 boss (prayer is 2026-W32's
    // spotlighted module, week 32 % 3 == 2) = 7.
    expect(rows, hasLength(7));
    expect(rows.where((r) => r.isBoss == 1), hasLength(1));
  });

  test('generateWeek is safe to call twice (no duplicate rows)', () async {
    // Only water is registered, and prayer (not water) is 2026-W32's
    // spotlighted boss module — no boss row gets created here.
    final modules = [_FakeModule('water', const {})];
    engine = QuestEngine(
      repository: QuestRepository(db),
      modules: modules,
      medicineRepository: medicineRepository,
    );
    await engine.generateWeek(now: now, profileId: _profileId);
    await engine.generateWeek(now: now, profileId: _profileId);
    final rows = await QuestRepository(
      db,
    ).watchCurrentWeek(weekKey: '2026-W32', profileId: _profileId).first;
    expect(rows, hasLength(2)); // 2 regular water quests, no duplicates.
  });

  test("evaluateModule updates only the affected module's quests", () async {
    final waterByDay = {
      for (var d = 3; d <= 9; d++)
        LocalDate(2026, 8, d): const ModuleDayStatus(
          kind: ModuleDayStatusKind.complete,
          value: 0,
        ),
    };
    final modules = [
      _FakeModule('water', waterByDay),
      _FakeModule('prayer', const {}),
    ];
    engine = QuestEngine(
      repository: QuestRepository(db),
      modules: modules,
      medicineRepository: medicineRepository,
    );
    await engine.evaluateModule('water', now: now, profileId: _profileId);

    final rows = await QuestRepository(
      db,
    ).watchCurrentWeek(weekKey: '2026-W32', profileId: _profileId).first;
    final waterGoal = rows.firstWhere(
      (r) => r.questKey == 'water_goal_5_of_7',
    );
    expect(waterGoal.progressCurrent, 5); // clamped to target.
    expect(waterGoal.completedAt, isNotNull);

    // Prayer (not water) is 2026-W32's spotlighted boss module, so
    // evaluateModule('water') must generate prayer's boss row (via its
    // internal generateWeek() call) but leave its progress untouched —
    // only evaluating the module actually written to.
    final bossQuest = rows.firstWhere(
      (r) => r.questKey == 'boss_prayer_5of5_5days',
    );
    expect(bossQuest.isBoss, 1);
    expect(bossQuest.progressCurrent, 0);
    expect(bossQuest.completedAt, isNull);

    final prayerQuests = rows.where(
      (r) => r.moduleId == 'prayer' && r.isBoss == 0,
    );
    expect(prayerQuests.every((r) => r.progressCurrent == 0), isTrue);
  });

  test(
    'evaluateModule generates the week first if quests do not exist yet',
    () async {
      // Only water is registered, and prayer (not water) is 2026-W32's
      // spotlighted boss module — no boss row gets created here.
      final modules = [_FakeModule('water', const {})];
      engine = QuestEngine(
        repository: QuestRepository(db),
        modules: modules,
        medicineRepository: medicineRepository,
      );
      // No prior generateWeek() call.
      await engine.evaluateModule('water', now: now, profileId: _profileId);
      final rows = await QuestRepository(
        db,
      ).watchCurrentWeek(weekKey: '2026-W32', profileId: _profileId).first;
      expect(rows, hasLength(2)); // 2 regular water quests.
    },
  );
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/leaderboard/leaderboard_metric.dart';
import 'package:habit_tracker/core/gamification/leaderboard/score_computer.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

const _today = LocalDate(2026, 8, 7);

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id, this.statusByProfile);
  @override
  final String id;

  /// profileId -> day -> status.
  final Map<String, Map<LocalDate, ModuleDayStatus>> statusByProfile;

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(
    DateRange range, {
    String? profileId,
  }) async => statusByProfile[profileId] ?? {};
}

ModuleDayStatus _complete() =>
    const ModuleDayStatus(kind: ModuleDayStatusKind.complete, value: 1);

void main() {
  late AppDatabase db;
  late XpRepository xpRepository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    xpRepository = XpRepository(db);
  });

  tearDown(() => db.close());

  group('currentStreak metric', () {
    test('returns the longest current streak across modules', () async {
      final water = _FakeModule('water', {
        'alice': {
          for (var i = 0; i < 3; i++) _today.addDays(-i): _complete(),
        },
      });
      final medicine = _FakeModule('medicine', {
        'alice': {
          for (var i = 0; i < 7; i++) _today.addDays(-i): _complete(),
        },
      });
      final computer = ScoreComputer(
        modules: [water, medicine],
        xpRepository: xpRepository,
      );

      final result = await computer.computeScore(
        profileId: 'alice',
        metric: LeaderboardMetric.currentStreak,
        today: _today,
      );

      expect(result.value, 7);
      expect(result.activeModuleIds, {'water', 'medicine'});
    });

    test('a profile with no data scores 0 with no active modules', () async {
      final water = _FakeModule('water', {});
      final computer = ScoreComputer(
        modules: [water],
        xpRepository: xpRepository,
      );

      final result = await computer.computeScore(
        profileId: 'bob',
        metric: LeaderboardMetric.currentStreak,
        today: _today,
      );

      expect(result.value, 0);
      expect(result.activeModuleIds, isEmpty);
    });
  });

  group('weeklyCompletion metric', () {
    test(
      'is 100% only on days every active module is complete',
      () async {
        final water = _FakeModule('water', {
          'alice': {
            for (var i = 0; i < 7; i++) _today.addDays(-i): _complete(),
          },
        });
        final medicine = _FakeModule('medicine', {
          'alice': {
            // Only 3 of the last 7 days complete.
            for (var i = 0; i < 3; i++) _today.addDays(-i): _complete(),
          },
        });
        final computer = ScoreComputer(
          modules: [water, medicine],
          xpRepository: xpRepository,
        );

        final result = await computer.computeScore(
          profileId: 'alice',
          metric: LeaderboardMetric.weeklyCompletion,
          today: _today,
        );

        expect(result.value, closeTo(3 / 7 * 100, 0.001));
      },
    );

    test('ignores modules the profile has no data in at all', () async {
      final water = _FakeModule('water', {
        'alice': {
          for (var i = 0; i < 7; i++) _today.addDays(-i): _complete(),
        },
      });
      // Medicine has zero data for alice -> not "active", excluded.
      final medicine = _FakeModule('medicine', {});
      final computer = ScoreComputer(
        modules: [water, medicine],
        xpRepository: xpRepository,
      );

      final result = await computer.computeScore(
        profileId: 'alice',
        metric: LeaderboardMetric.weeklyCompletion,
        today: _today,
      );

      expect(result.value, 100);
      expect(result.activeModuleIds, {'water'});
    });
  });

  group('level metric', () {
    test("derives level from the profile's own XP balance", () async {
      await xpRepository.awardXp(
        moduleId: 'water',
        eventType: 'log',
        amount: 500,
        now: DateTime(2026, 8),
        profileId: 'alice',
      );
      final computer = ScoreComputer(modules: [], xpRepository: xpRepository);

      final result = await computer.computeScore(
        profileId: 'alice',
        metric: LeaderboardMetric.level,
        today: _today,
      );

      expect(result.value, greaterThan(1));
      expect(result.activeModuleIds, isEmpty);
    });

    test('profiles never awarded XP score level 1', () async {
      final computer = ScoreComputer(modules: [], xpRepository: xpRepository);

      final result = await computer.computeScore(
        profileId: 'bob',
        metric: LeaderboardMetric.level,
        today: _today,
      );

      expect(result.value, 1);
    });
  });
}

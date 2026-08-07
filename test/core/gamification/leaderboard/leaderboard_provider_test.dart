import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/leaderboard/leaderboard_metric.dart';
import 'package:habit_tracker/core/gamification/leaderboard/leaderboard_provider.dart';
import 'package:habit_tracker/core/gamification/xp_providers.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/profiles/profile.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id, this.statusByProfile);
  @override
  final String id;
  final Map<String, Map<LocalDate, ModuleDayStatus>> statusByProfile;

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(
    DateRange range, {
    String? profileId,
  }) async => statusByProfile[profileId] ?? {};
}

Profile _profile(
  String id,
  String name, {
  bool leaderboardOptedOut = false,
}) => Profile(
  id: id,
  displayName: name,
  avatarColor: 'teal',
  createdAt: 0,
  leaderboardOptedOut: leaderboardOptedOut,
);

Map<LocalDate, ModuleDayStatus> _streakOf(int days, LocalDate today) => {
  for (var i = 0; i < days; i++)
    today.addDays(-i): const ModuleDayStatus(
      kind: ModuleDayStatusKind.complete,
      value: 1,
    ),
};

void main() {
  late AppDatabase db;
  final today = localDayKey(clock.now());

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test(
    'ranks profiles by score descending, ties share a rank',
    () async {
      final water = _FakeModule('water', {
        'alice': _streakOf(5, today),
        'bob': _streakOf(5, today),
        'carol': _streakOf(2, today),
      });
      final container = ProviderContainer(
        overrides: [
          profileListProvider.overrideWith(
            (ref) async => [
              _profile('alice', 'Alice'),
              _profile('bob', 'Bob'),
              _profile('carol', 'Carol'),
            ],
          ),
          activeProfileProvider.overrideWith(
            (ref) async => _profile('alice', 'Alice'),
          ),
          visibleHabitModulesProvider.overrideWith((ref) => [water]),
          xpRepositoryProvider.overrideWithValue(XpRepository(db)),
        ],
      );
      addTearDown(container.dispose);

      final entries = await container.read(
        householdLeaderboardProvider(LeaderboardMetric.currentStreak).future,
      );

      expect(entries.map((e) => e.profileId), ['alice', 'bob', 'carol']);
      expect(entries[0].rank, 1);
      expect(entries[1].rank, 1);
      expect(entries[2].rank, 3);
      expect(entries[0].isCurrentUser, isTrue);
      expect(entries[1].isCurrentUser, isFalse);
    },
  );

  test('opted-out profiles are excluded entirely', () async {
    final water = _FakeModule('water', {
      'alice': _streakOf(5, today),
      'bob': _streakOf(5, today),
    });
    final container = ProviderContainer(
      overrides: [
        profileListProvider.overrideWith(
          (ref) async => [
            _profile('alice', 'Alice'),
            _profile('bob', 'Bob', leaderboardOptedOut: true),
          ],
        ),
        activeProfileProvider.overrideWith(
          (ref) async => _profile('alice', 'Alice'),
        ),
        visibleHabitModulesProvider.overrideWith((ref) => [water]),
        xpRepositoryProvider.overrideWithValue(XpRepository(db)),
      ],
    );
    addTearDown(container.dispose);

    final entries = await container.read(
      householdLeaderboardProvider(LeaderboardMetric.currentStreak).future,
    );

    expect(entries.map((e) => e.profileId), ['alice']);
  });

  test(
    'a profile with zero module overlap has no comparable data',
    () async {
      final water = _FakeModule('water', {'alice': _streakOf(5, today)});
      final medicine = _FakeModule('medicine', {
        'bob': _streakOf(3, today),
      });
      final container = ProviderContainer(
        overrides: [
          profileListProvider.overrideWith(
            (ref) async => [
              _profile('alice', 'Alice'),
              _profile('bob', 'Bob'),
            ],
          ),
          activeProfileProvider.overrideWith(
            (ref) async => _profile('alice', 'Alice'),
          ),
          visibleHabitModulesProvider.overrideWith((ref) => [water, medicine]),
          xpRepositoryProvider.overrideWithValue(XpRepository(db)),
        ],
      );
      addTearDown(container.dispose);

      final entries = await container.read(
        householdLeaderboardProvider(LeaderboardMetric.currentStreak).future,
      );

      expect(entries, hasLength(2));
      expect(entries.every((e) => !e.hasData), isTrue);
      expect(entries.every((e) => e.rank == 0), isTrue);
    },
  );

  test('level metric is always comparable, no overlap needed', () async {
    final container = ProviderContainer(
      overrides: [
        profileListProvider.overrideWith(
          (ref) async => [
            _profile('alice', 'Alice'),
            _profile('bob', 'Bob'),
          ],
        ),
        activeProfileProvider.overrideWith(
          (ref) async => _profile('alice', 'Alice'),
        ),
        visibleHabitModulesProvider.overrideWith((ref) => []),
        xpRepositoryProvider.overrideWithValue(XpRepository(db)),
      ],
    );
    addTearDown(container.dispose);

    final entries = await container.read(
      householdLeaderboardProvider(LeaderboardMetric.level).future,
    );

    expect(entries, hasLength(2));
    expect(entries.every((e) => e.hasData), isTrue);
  });
}

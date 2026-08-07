import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/gamification/xp_award_helper.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';
import 'package:habit_tracker/core/gamification/xp_values.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

const _profileId = 'system';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id, this._kind);
  @override
  final String id;
  final ModuleDayStatusKind _kind;

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(
    DateRange range, {
    String? profileId,
  }) async => {
    for (var d = range.start; d.compareTo(range.end) <= 0; d = d.addDays(1))
      d: ModuleDayStatus(kind: _kind, value: 0),
  };
}

/// A throwaway provider whose body calls the `Ref`-based
/// [awardActionXp] under test — the standard way to exercise a plain
/// function taking `Ref` outside a widget, since `ProviderContainer`
/// doesn't implement `Ref` directly.
typedef _Args = ({String moduleId, String? sourceId});

// The generated family type is verbose and Riverpod-version-specific;
// left to inference rather than spelled out by hand.
// ignore: specify_nonobvious_property_types
final _testProvider = FutureProvider.autoDispose.family<void, _Args>((
  ref,
  args,
) {
  return awardActionXp(
    ref,
    moduleId: args.moduleId,
    actionSourceId: args.sourceId,
    profileId: _profileId,
  );
});

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer buildContainer(List<HabitModule> modules) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        habitModulesProvider.overrideWithValue(modules),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'awards action XP unconditionally when no actionSourceId given',
    () async {
      final container = buildContainer([
        _FakeModule('water', ModuleDayStatusKind.none),
      ]);
      final provider = _testProvider((moduleId: 'water', sourceId: null));
      await container.read(provider.future);
      // .refresh forces a real second execution — see the dedup test
      // below for why a second .read alone wouldn't actually re-run this.
      container.invalidate(provider);
      await container.read(provider.future);
      final total = await XpRepository(db).totalXp(profileId: _profileId);
      expect(total, XpValues.waterAction * 2);
    },
  );

  test('dedupes the action award by actionSourceId when given', () async {
    final container = buildContainer([
      _FakeModule('medicine', ModuleDayStatusKind.none),
    ]);
    final provider = _testProvider((moduleId: 'medicine', sourceId: 'dose-1'));
    await container.read(provider.future);
    // .refresh forces a real second execution — a second .read on the
    // same family args would just return the cached result without
    // re-running awardActionXp at all, silently passing without
    // actually exercising the dedup path.
    container.invalidate(provider);
    await container.read(provider.future);
    final total = await XpRepository(db).totalXp(profileId: _profileId);
    expect(total, XpValues.medicineAction); // only the first call counted.
  });

  test(
    'a different actionSourceId is awarded independently of an earlier one',
    () async {
      final container = buildContainer([
        _FakeModule('medicine', ModuleDayStatusKind.none),
      ]);
      await container.read(
        _testProvider((moduleId: 'medicine', sourceId: 'dose-1')).future,
      );
      await container.read(
        _testProvider((moduleId: 'medicine', sourceId: 'dose-2')).future,
      );
      final total = await XpRepository(db).totalXp(profileId: _profileId);
      expect(total, XpValues.medicineAction * 2);
    },
  );

  test(
    'awards day-complete XP once when the day is complete, dedupes on repeat',
    () async {
      final container = buildContainer([
        _FakeModule('water', ModuleDayStatusKind.complete),
      ]);
      final provider = _testProvider((moduleId: 'water', sourceId: null));
      await container.read(provider.future);
      container.invalidate(provider);
      await container.read(provider.future);
      final ledger = await XpRepository(db).recentLedger(profileId: _profileId);
      final dayCompleteAwards = ledger.where(
        (r) => r.eventType == 'day_complete',
      );
      expect(dayCompleteAwards, hasLength(1));
      expect(dayCompleteAwards.single.xpAmount, XpValues.waterDayComplete);
    },
  );

  test('does not award day-complete XP when the day is not complete', () async {
    final container = buildContainer([
      _FakeModule('water', ModuleDayStatusKind.partial),
    ]);
    await container.read(
      _testProvider((moduleId: 'water', sourceId: null)).future,
    );
    final ledger = await XpRepository(db).recentLedger(profileId: _profileId);
    expect(ledger.where((r) => r.eventType == 'day_complete'), isEmpty);
  });

  test(
    'still awards action XP when the module is not registered '
    '(day-complete step is skipped, not a crash)',
    () async {
      final container = buildContainer([]); // 'water' not registered.
      await container.read(
        _testProvider((moduleId: 'water', sourceId: null)).future,
      );
      final total = await XpRepository(db).totalXp(profileId: _profileId);
      expect(total, XpValues.waterAction);
    },
  );
}

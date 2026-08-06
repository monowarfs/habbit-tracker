import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';

void main() {
  late AppDatabase db;
  late XpRepository repo;
  final now = DateTime.utc(2026, 8, 5);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = XpRepository(db);
  });

  tearDown(() => db.close());

  test('totalXp is 0 before any award (lazy-seeded singleton)', () async {
    expect(await repo.totalXp(), 0);
  });

  test('awardXp inserts a ledger row and increments the balance', () async {
    await repo.awardXp(
      moduleId: 'water',
      eventType: 'action',
      amount: 5,
      now: now,
    );
    expect(await repo.totalXp(), 5);

    final ledger = await repo.recentLedger();
    expect(ledger, hasLength(1));
    expect(ledger.single.moduleId, 'water');
    expect(ledger.single.eventType, 'action');
    expect(ledger.single.xpAmount, 5);
  });

  test('multiple awards accumulate', () async {
    await repo.awardXp(
      moduleId: 'water',
      eventType: 'action',
      amount: 5,
      now: now,
    );
    await repo.awardXp(
      moduleId: 'medicine',
      eventType: 'action',
      amount: 3,
      now: now,
    );
    await repo.awardXp(
      moduleId: 'prayer',
      eventType: 'action',
      amount: 2,
      now: now,
    );
    expect(await repo.totalXp(), 10);
  });

  test('watchTotalXp emits the running total reactively', () async {
    final values = <int>[];
    final subscription = repo.watchTotalXp().listen(values.add);
    await Future<void>.delayed(Duration.zero);
    await repo.awardXp(
      moduleId: 'water',
      eventType: 'action',
      amount: 5,
      now: now,
    );
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(values, contains(5));
  });

  test('hasAwarded is false before an award, true after', () async {
    expect(
      await repo.hasAwarded(
        moduleId: 'water',
        eventType: 'day_complete',
        sourceId: '2026-08-05',
      ),
      isFalse,
    );
    await repo.awardXp(
      moduleId: 'water',
      eventType: 'day_complete',
      amount: 15,
      now: now,
      sourceId: '2026-08-05',
    );
    expect(
      await repo.hasAwarded(
        moduleId: 'water',
        eventType: 'day_complete',
        sourceId: '2026-08-05',
      ),
      isTrue,
    );
  });

  test(
    'hasAwarded is scoped to the exact moduleId/eventType/sourceId',
    () async {
      await repo.awardXp(
        moduleId: 'water',
        eventType: 'day_complete',
        amount: 15,
        now: now,
        sourceId: '2026-08-05',
      );
      expect(
        await repo.hasAwarded(
          moduleId: 'medicine',
          eventType: 'day_complete',
          sourceId: '2026-08-05',
        ),
        isFalse,
      );
      expect(
        await repo.hasAwarded(
          moduleId: 'water',
          eventType: 'day_complete',
          sourceId: '2026-08-06',
        ),
        isFalse,
      );
    },
  );

  test('recentLedger returns newest first and respects limit', () async {
    for (var i = 0; i < 3; i++) {
      await repo.awardXp(
        moduleId: 'water',
        eventType: 'action',
        amount: i,
        now: now.add(Duration(minutes: i)),
      );
    }
    final ledger = await repo.recentLedger(limit: 2);
    expect(ledger, hasLength(2));
    expect(ledger.first.xpAmount, 2); // most recent first.
    expect(ledger.last.xpAmount, 1);
  });

  group('awardXp AwardResult', () {
    test('leveledUpTo is null when the award stays within the level', () async {
      final result = await repo.awardXp(
        moduleId: 'water',
        eventType: 'action',
        amount: 50,
        now: now,
      );
      expect(result.totalXp, 50);
      expect(result.leveledUpTo, isNull);
    });

    test('leveledUpTo is the new level when a threshold is crossed', () async {
      // Level 2 starts at 100 XP.
      final result = await repo.awardXp(
        moduleId: 'water',
        eventType: 'action',
        amount: 100,
        now: now,
      );
      expect(result.totalXp, 100);
      expect(result.leveledUpTo, 2);
    });

    test('leveledUpTo is null once already past the threshold', () async {
      await repo.awardXp(
        moduleId: 'water',
        eventType: 'action',
        amount: 150,
        now: now,
      );
      final result = await repo.awardXp(
        moduleId: 'water',
        eventType: 'action',
        amount: 10,
        now: now,
      );
      expect(result.totalXp, 160);
      expect(result.leveledUpTo, isNull);
    });

    test(
      'leveledUpTo reflects the highest level reached across a jump',
      () async {
        // Level 3 starts at 300 XP — a single big award (e.g. boss_cleared)
        // can jump straight past level 2's threshold too.
        final result = await repo.awardXp(
          moduleId: 'water',
          eventType: 'boss_cleared',
          amount: 350,
          now: now,
        );
        expect(result.leveledUpTo, 3);
      },
    );
  });

  group('deductXp', () {
    test(
      'deducts from the balance and records a negative ledger row',
      () async {
        await repo.awardXp(
          moduleId: 'water',
          eventType: 'action',
          amount: 500,
          now: now,
        );
        await repo.deductXp(
          amount: 300,
          now: now.add(const Duration(minutes: 1)),
          reason: 'shop_purchase_x',
        );
        expect(await repo.totalXp(), 200);

        final ledger = await repo.recentLedger();
        expect(ledger.first.moduleId, 'system');
        expect(ledger.first.eventType, 'shop_purchase');
        expect(ledger.first.xpAmount, -300);
        expect(ledger.first.sourceId, 'shop_purchase_x');
      },
    );

    test('throws when balance is less than the deduction amount', () async {
      await repo.awardXp(
        moduleId: 'water',
        eventType: 'action',
        amount: 100,
        now: now,
      );
      await expectLater(
        repo.deductXp(amount: 200, now: now, reason: 'shop_purchase_x'),
        throwsStateError,
      );
      expect(await repo.totalXp(), 100);
    });
  });
}

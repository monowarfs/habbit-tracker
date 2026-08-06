import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/gamification/shop/shop_catalog.dart';
import 'package:habit_tracker/core/gamification/shop/shop_repository.dart';
import 'package:habit_tracker/core/gamification/xp_repository.dart';

void main() {
  late AppDatabase db;
  late ShopRepository shopRepository;
  late XpRepository xpRepository;
  final now = DateTime.utc(2026, 8, 6);
  final item = shopCatalog.firstWhere((i) => i.id == 'minimal_icon');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    shopRepository = ShopRepository(db);
    xpRepository = XpRepository(db);
  });

  tearDown(() => db.close());

  test('currentBalance mirrors XpRepository.totalXp', () async {
    await xpRepository.awardXp(
      moduleId: 'water',
      eventType: 'action',
      amount: 400,
      now: now,
    );
    expect(await shopRepository.currentBalance(), 400);
  });

  test('unlockedItemIds is empty before any purchase', () async {
    expect(await shopRepository.unlockedItemIds(), isEmpty);
  });

  test('purchaseItem deducts XP and records the unlock', () async {
    await xpRepository.awardXp(
      moduleId: 'water',
      eventType: 'action',
      amount: item.costXp,
      now: now,
    );
    await shopRepository.purchaseItem(item: item, now: now);

    expect(await shopRepository.currentBalance(), 0);
    expect(await shopRepository.unlockedItemIds(), {item.id});
  });

  test('purchaseItem throws on insufficient XP, no partial state', () async {
    await expectLater(
      shopRepository.purchaseItem(item: item, now: now),
      throwsStateError,
    );
    expect(await shopRepository.currentBalance(), 0);
    expect(await shopRepository.unlockedItemIds(), isEmpty);
  });

  test('purchaseItem throws when the item is already owned', () async {
    await xpRepository.awardXp(
      moduleId: 'water',
      eventType: 'action',
      amount: item.costXp * 2,
      now: now,
    );
    await shopRepository.purchaseItem(item: item, now: now);

    await expectLater(
      shopRepository.purchaseItem(item: item, now: now),
      throwsStateError,
    );
    // Balance untouched by the rejected second purchase.
    expect(await shopRepository.currentBalance(), item.costXp);
  });

  test('watchUnlockedItems emits reactively after a purchase', () async {
    await xpRepository.awardXp(
      moduleId: 'water',
      eventType: 'action',
      amount: item.costXp,
      now: now,
    );
    final values = <Set<String>>[];
    final subscription = shopRepository.watchUnlockedItems().listen(
      values.add,
    );
    await Future<void>.delayed(Duration.zero);
    await shopRepository.purchaseItem(item: item, now: now);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(values.last, {item.id});
  });
}

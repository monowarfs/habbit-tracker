import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/shop/shop_catalog.dart';

void main() {
  test('every item has a non-empty id', () {
    for (final item in shopCatalog) {
      expect(item.id, isNotEmpty);
    }
  });

  test('every item has a positive cost', () {
    for (final item in shopCatalog) {
      expect(item.costXp, greaterThan(0));
    }
  });

  test('item ids are unique', () {
    final ids = shopCatalog.map((item) => item.id).toSet();
    expect(ids, hasLength(shopCatalog.length));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/shortcuts/quick_action_handler.dart';

import '../../support/test_database.dart';

void main() {
  test(
    'handleQuickAction(type: water) logs a quick water entry',
    () async {
      final db = testDatabase();
      addTearDown(db.close);

      await handleQuickAction(type: 'water', db: db);

      final rows = await db.select(db.waterLogsTable).get();
      expect(rows, hasLength(1));
      expect(rows.single.amountMl, 250);
    },
  );

  test('handleQuickAction ignores an unknown type', () async {
    final db = testDatabase();
    addTearDown(db.close);

    await handleQuickAction(type: 'not_a_module', db: db);

    final rows = await db.select(db.waterLogsTable).get();
    expect(rows, isEmpty);
  });
}

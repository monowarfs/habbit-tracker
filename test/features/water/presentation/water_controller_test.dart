import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_providers.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';

void main() {
  test('logQuickAdd triggers achievement evaluation for water', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    await container.read(waterControllerProvider.notifier).logQuickAdd(250);

    final row = await container
        .read(achievementRepositoryProvider)
        .byKey('water_first_log', profileId: 'system');
    expect(row, isNotNull);
    expect(row!.progressCurrent, 1);
    expect(row.unlockedAt, isNotNull);
  });
}

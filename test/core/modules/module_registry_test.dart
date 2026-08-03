import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id);
  @override
  final String id;

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(DateRange range) async =>
      {};
}

void main() {
  test('non-premium users never see premium-gated module ids', () async {
    final container = ProviderContainer(
      overrides: [
        habitModulesProvider.overrideWith(
          (ref) => [_FakeModule('water'), _FakeModule('sleep')],
        ),
        isPremiumUserProvider.overrideWith((ref) => false),
      ],
    );
    addTearDown(container.dispose);

    final visible = container.read(visibleHabitModulesProvider);
    expect(visible.map((m) => m.id), ['water']);
  });

  test('premium users see every registered module', () async {
    final container = ProviderContainer(
      overrides: [
        habitModulesProvider.overrideWith(
          (ref) => [_FakeModule('water'), _FakeModule('sleep')],
        ),
        isPremiumUserProvider.overrideWith((ref) => true),
      ],
    );
    addTearDown(container.dispose);

    final visible = container.read(visibleHabitModulesProvider);
    expect(visible.map((m) => m.id), ['water', 'sleep']);
  });

  test('premiumGatedModuleIds contains sleep', () {
    expect(premiumGatedModuleIds, contains('sleep'));
  });
}

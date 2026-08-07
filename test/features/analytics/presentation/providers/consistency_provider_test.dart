import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/analytics/presentation/providers/consistency_provider.dart';

class _FakeModule extends Fake implements HabitModule {
  _FakeModule(this.id, this.todayKind);
  @override
  final String id;
  final ModuleDayStatusKind todayKind;

  @override
  Future<Map<LocalDate, ModuleDayStatus>> dayStatus(
    DateRange range, {
    String? profileId,
  }) async => {
    range.start: ModuleDayStatus(kind: todayKind, value: 0),
  };
}

void main() {
  test(
    "composes the score from every visible module's today status",
    () async {
      final container = ProviderContainer(
        overrides: [
          habitModulesProvider.overrideWith(
            (ref) => [
              _FakeModule('water', ModuleDayStatusKind.complete),
              _FakeModule('medicine', ModuleDayStatusKind.complete),
            ],
          ),
          isPremiumUserProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      final score = await container.read(consistencyScoreProvider.future);
      expect(score, 100);
    },
  );

  test("excludes premium-gated modules the user can't see", () async {
    final container = ProviderContainer(
      overrides: [
        habitModulesProvider.overrideWith(
          (ref) => [
            _FakeModule('water', ModuleDayStatusKind.complete),
            _FakeModule('sleep', ModuleDayStatusKind.missed),
          ],
        ),
        isPremiumUserProvider.overrideWith((ref) => false),
      ],
    );
    addTearDown(container.dispose);

    // Only water (complete) is visible, so the missed sleep entry can't
    // drag the score down.
    final score = await container.read(consistencyScoreProvider.future);
    expect(score, 100);
  });

  test('no visible modules yields a score of 0', () async {
    final container = ProviderContainer(
      overrides: [
        habitModulesProvider.overrideWith((ref) => []),
        isPremiumUserProvider.overrideWith((ref) => true),
      ],
    );
    addTearDown(container.dispose);

    final score = await container.read(consistencyScoreProvider.future);
    expect(score, 0);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/notification_effectiveness_use_case.dart';
import 'package:habit_tracker/core/database/app_database.dart';

NotificationLedgerRow _row({
  String id = 'id',
  DateTime? firedAt,
  String? action,
  DateTime? actionAt,
}) {
  return NotificationLedgerRow(
    id: id,
    moduleId: 'water',
    sourceType: 'water_reminder',
    sourceId: 'source',
    title: 't',
    body: 'b',
    scheduledFor: DateTime.utc(2026, 6, 1).millisecondsSinceEpoch,
    firedAt: firedAt?.millisecondsSinceEpoch,
    action: action,
    actionAt: actionAt?.millisecondsSinceEpoch,
    snoozeCount: 0,
    deepLinkRoute: '/water',
    createdAt: DateTime.utc(2026, 6, 1).millisecondsSinceEpoch,
    updatedAt: DateTime.utc(2026, 6, 1).millisecondsSinceEpoch,
  );
}

void main() {
  const useCase = NotificationEffectivenessUseCase();
  final fired = DateTime.utc(2026, 6, 1, 8);

  test('counts done-within-window entries as acted', () {
    final result = useCase.calculate(
      entries: [
        _row(
          id: '1',
          firedAt: fired,
          action: 'done',
          actionAt: fired.add(const Duration(minutes: 30)),
        ),
        _row(id: '2', firedAt: fired, action: 'skip', actionAt: fired),
        _row(id: '3', firedAt: fired),
      ],
    );
    expect(result.total, 3);
    expect(result.acted, 1);
    expect(result.rate, closeTo(1 / 3, 1e-9));
  });

  test('excludes never-fired entries from the denominator', () {
    final result = useCase.calculate(
      entries: [
        _row(id: '1'),
        _row(
          id: '2',
          firedAt: fired,
          action: 'done',
          actionAt: fired.add(const Duration(minutes: 1)),
        ),
      ],
    );
    expect(result.total, 1);
    expect(result.acted, 1);
    expect(result.rate, 1);
  });

  test('done action exactly at the attribution window boundary counts', () {
    final result = useCase.calculate(
      entries: [
        _row(
          id: '1',
          firedAt: fired,
          action: 'done',
          actionAt: fired.add(const Duration(hours: 4)),
        ),
      ],
      attributionWindow: const Duration(hours: 4),
    );
    expect(result.acted, 1);
  });

  test('done action past the attribution window does not count', () {
    final result = useCase.calculate(
      entries: [
        _row(
          id: '1',
          firedAt: fired,
          action: 'done',
          actionAt: fired.add(const Duration(hours: 4, minutes: 1)),
        ),
      ],
      attributionWindow: const Duration(hours: 4),
    );
    expect(result.acted, 0);
    expect(result.total, 1);
    expect(result.rate, 0);
  });

  test('empty entries yield rate 0 with no division error', () {
    final result = useCase.calculate(entries: const []);
    expect(result.total, 0);
    expect(result.acted, 0);
    expect(result.rate, 0);
  });
}

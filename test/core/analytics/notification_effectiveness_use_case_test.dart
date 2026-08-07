import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/notification_effectiveness_use_case.dart';
import 'package:habit_tracker/core/database/app_database.dart';

NotificationLedgerRow _row({
  required DateTime scheduledFor,
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
    scheduledFor: scheduledFor.millisecondsSinceEpoch,
    firedAt: firedAt?.millisecondsSinceEpoch,
    action: action,
    actionAt: actionAt?.millisecondsSinceEpoch,
    snoozeCount: 0,
    deepLinkRoute: '/water',
    createdAt: scheduledFor.millisecondsSinceEpoch,
    updatedAt: scheduledFor.millisecondsSinceEpoch,
    profileId: 'system',
  );
}

void main() {
  const useCase = NotificationEffectivenessUseCase();
  final fired = DateTime.utc(2026, 6, 1, 8);

  test('counts done-within-window entries as acted; every passed-in entry '
      'counts toward the total', () {
    final result = useCase.calculate(
      entries: [
        _row(
          id: '1',
          scheduledFor: fired,
          firedAt: fired,
          action: 'done',
          actionAt: fired.add(const Duration(minutes: 30)),
        ),
        _row(
          id: '2',
          scheduledFor: fired,
          firedAt: fired,
          action: 'skip',
          actionAt: fired,
        ),
        _row(id: '3', scheduledFor: fired, firedAt: fired),
      ],
    );
    expect(result.total, 3);
    expect(result.acted, 1);
    expect(result.rate, closeTo(1 / 3, 1e-9));
  });

  test('falls back to scheduledFor as the fire instant when firedAt is '
      'unset', () {
    final result = useCase.calculate(
      entries: [
        _row(
          id: '1',
          scheduledFor: fired,
          action: 'done',
          actionAt: fired.add(const Duration(minutes: 1)),
        ),
      ],
    );
    expect(result.total, 1);
    expect(result.acted, 1);
    expect(result.rate, 1);
  });

  test('prefers firedAt over scheduledFor as the fire instant when both are '
      'set and differ', () {
    // scheduledFor is 5 hours before firedAt (e.g. an OEM-delayed OS
    // delivery); actionAt is only 5 minutes after the real firedAt, but
    // more than 4 hours (the default attributionWindow) after
    // scheduledFor. Only counts as acted if firedAt, not scheduledFor,
    // is used as the reference instant.
    final result = useCase.calculate(
      entries: [
        _row(
          id: '1',
          scheduledFor: fired,
          firedAt: fired.add(const Duration(hours: 5)),
          action: 'done',
          actionAt: fired.add(const Duration(hours: 5, minutes: 5)),
        ),
      ],
    );
    expect(result.acted, 1);
  });

  test('done action exactly at the attribution window boundary counts', () {
    final result = useCase.calculate(
      entries: [
        _row(
          id: '1',
          scheduledFor: fired,
          firedAt: fired,
          action: 'done',
          actionAt: fired.add(const Duration(hours: 4)),
        ),
      ],
    );
    expect(result.acted, 1);
  });

  test('done action past the attribution window does not count', () {
    final result = useCase.calculate(
      entries: [
        _row(
          id: '1',
          scheduledFor: fired,
          firedAt: fired,
          action: 'done',
          actionAt: fired.add(const Duration(hours: 4, minutes: 1)),
        ),
      ],
    );
    expect(result.acted, 0);
    expect(result.total, 1);
    expect(result.rate, 0);
  });

  test('a done action recorded before the fire instant does not count '
      '(clock skew / stale data)', () {
    final result = useCase.calculate(
      entries: [
        _row(
          id: '1',
          scheduledFor: fired,
          firedAt: fired,
          action: 'done',
          actionAt: fired.subtract(const Duration(minutes: 1)),
        ),
      ],
    );
    expect(result.acted, 0);
    expect(result.total, 1);
  });

  test('empty entries yield rate 0 with no division error', () {
    final result = useCase.calculate(entries: const []);
    expect(result.total, 0);
    expect(result.acted, 0);
    expect(result.rate, 0);
  });
}

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late NotificationLedgerRepository repo;

  setUp(() {
    db = testDatabase();
    repo = NotificationLedgerRepository(db);
  });

  tearDown(() => db.close());

  test('insertScheduled then pendingRows returns it until actioned', () async {
    final scheduledFor = DateTime.utc(2026, 6, 1, 8);
    await repo.insertScheduled(
      id: 'r1',
      moduleId: 'water',
      sourceType: 'water_reminder',
      sourceId: 'r1',
      title: 'Time to drink water',
      body: 'body',
      scheduledFor: scheduledFor,
      deepLinkRoute: '/water',
    );

    final pending = await repo.pendingRows();
    expect(pending, hasLength(1));
    expect(pending.single.id, 'r1');
    expect(pending.single.title, 'Time to drink water');

    await withClock(
      Clock.fixed(DateTime.utc(2026, 6, 1, 8, 1)),
      () => repo.markActioned(
        'r1',
        action: 'done',
        actionAt: clock.now(),
      ),
    );

    expect(await repo.pendingRows(), isEmpty);
    final row = await repo.rowById('r1');
    expect(row!.action, 'done');
  });

  test(
    'recordSnooze increments snoozeCount and moves scheduledFor, without '
    'actioning',
    () async {
      final scheduledFor = DateTime.utc(2026, 6, 1, 8);
      await repo.insertScheduled(
        id: 'r1',
        moduleId: 'water',
        sourceType: 'water_reminder',
        sourceId: 'r1',
        title: 'title',
        body: 'body',
        scheduledFor: scheduledFor,
        deepLinkRoute: '/water',
      );

      final rescheduled = scheduledFor.add(const Duration(minutes: 10));
      await repo.recordSnooze('r1', rescheduledFor: rescheduled);
      await repo.recordSnooze('r1', rescheduledFor: rescheduled);

      final row = await repo.rowById('r1');
      expect(row!.snoozeCount, 2);
      expect(row.action, isNull);
      expect(
        DateTime.fromMillisecondsSinceEpoch(row.scheduledFor, isUtc: true),
        rescheduled,
      );
      // still pending — snooze is not terminal.
      expect(await repo.pendingRows(), hasLength(1));
    },
  );

  test('cancel soft-deletes the row so it drops out of pendingRows', () async {
    await repo.insertScheduled(
      id: 'r1',
      moduleId: 'water',
      sourceType: 'water_reminder',
      sourceId: 'r1',
      title: 'title',
      body: 'body',
      scheduledFor: DateTime.utc(2026, 6, 1, 8),
      deepLinkRoute: '/water',
    );

    await repo.cancel('r1');

    expect(await repo.pendingRows(), isEmpty);
    expect(await repo.rowById('r1'), isNull);
  });
}

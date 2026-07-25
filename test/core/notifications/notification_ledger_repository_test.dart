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

  test(
    'actionedDoneRows returns only done/non-deleted rows within the window',
    () async {
      final now = DateTime.utc(2026, 6, 30);

      // In-window, done — should be included.
      await repo.insertScheduled(
        id: 'done-in-window',
        moduleId: 'water',
        sourceType: 'water_reminder',
        sourceId: 'done-in-window',
        title: 'title',
        body: 'body',
        scheduledFor: DateTime.utc(2026, 6, 20, 8),
        deepLinkRoute: '/water',
      );
      await repo.markActioned(
        'done-in-window',
        action: 'done',
        actionAt: DateTime.utc(2026, 6, 20, 8, 5),
      );

      // In-window, still pending — excluded (not actioned).
      await repo.insertScheduled(
        id: 'pending',
        moduleId: 'water',
        sourceType: 'water_reminder',
        sourceId: 'pending',
        title: 'title',
        body: 'body',
        scheduledFor: DateTime.utc(2026, 6, 21, 8),
        deepLinkRoute: '/water',
      );

      // In-window, done then cancelled — excluded (soft-deleted).
      await repo.insertScheduled(
        id: 'done-deleted',
        moduleId: 'water',
        sourceType: 'water_reminder',
        sourceId: 'done-deleted',
        title: 'title',
        body: 'body',
        scheduledFor: DateTime.utc(2026, 6, 22, 8),
        deepLinkRoute: '/water',
      );
      await repo.markActioned(
        'done-deleted',
        action: 'done',
        actionAt: DateTime.utc(2026, 6, 22, 8, 5),
      );
      await repo.cancel('done-deleted');

      // Outside the 30-day window — excluded.
      await repo.insertScheduled(
        id: 'done-out-of-window',
        moduleId: 'water',
        sourceType: 'water_reminder',
        sourceId: 'done-out-of-window',
        title: 'title',
        body: 'body',
        scheduledFor: DateTime.utc(2026, 5, 1, 8),
        deepLinkRoute: '/water',
      );
      await repo.markActioned(
        'done-out-of-window',
        action: 'done',
        actionAt: DateTime.utc(2026, 5, 1, 8, 5),
      );

      final result = await repo.actionedDoneRows(windowDays: 30, now: now);

      expect(result.map((r) => r.id), ['done-in-window']);
    },
  );

  test(
    'firedRows returns only non-deleted rows already past scheduledFor, '
    'within the window',
    () async {
      final now = DateTime.utc(2026, 6, 30);

      // In-window, already past scheduledFor — should be included.
      await repo.insertScheduled(
        id: 'past-in-window',
        moduleId: 'water',
        sourceType: 'water_reminder',
        sourceId: 'past-in-window',
        title: 'title',
        body: 'body',
        scheduledFor: DateTime.utc(2026, 6, 20, 8),
        deepLinkRoute: '/water',
      );

      // In-window but scheduled in the future relative to now — excluded
      // (hasn't fired yet).
      await repo.insertScheduled(
        id: 'future',
        moduleId: 'water',
        sourceType: 'water_reminder',
        sourceId: 'future',
        title: 'title',
        body: 'body',
        scheduledFor: DateTime.utc(2026, 7, 1, 8),
        deepLinkRoute: '/water',
      );

      // Past scheduledFor but cancelled — excluded (soft-deleted).
      await repo.insertScheduled(
        id: 'past-deleted',
        moduleId: 'water',
        sourceType: 'water_reminder',
        sourceId: 'past-deleted',
        title: 'title',
        body: 'body',
        scheduledFor: DateTime.utc(2026, 6, 22, 8),
        deepLinkRoute: '/water',
      );
      await repo.cancel('past-deleted');

      // Outside the 30-day window — excluded.
      await repo.insertScheduled(
        id: 'past-out-of-window',
        moduleId: 'water',
        sourceType: 'water_reminder',
        sourceId: 'past-out-of-window',
        title: 'title',
        body: 'body',
        scheduledFor: DateTime.utc(2026, 5, 1, 8),
        deepLinkRoute: '/water',
      );

      final result = await repo.firedRows(windowDays: 30, now: now);

      expect(result.map((r) => r.id), ['past-in-window']);
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

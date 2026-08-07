import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/notifications/notification_planner.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

PendingNotification _pending(String id, DateTime scheduledAt) =>
    PendingNotification(
      id: id,
      scheduledAt: scheduledAt,
      title: 'title',
      body: 'body',
      sourceType: 'water_reminder',
      deepLinkRoute: '/water',
      quietHoursSuppressible: true,
    );

NotificationLedgerRow _ledgerRow(String id, DateTime scheduledFor) =>
    NotificationLedgerRow(
      id: id,
      moduleId: 'water',
      sourceType: 'water_reminder',
      sourceId: id,
      title: 'title',
      body: 'body',
      scheduledFor: scheduledFor.millisecondsSinceEpoch,
      snoozeCount: 0,
      deepLinkRoute: '/water',
      createdAt: scheduledFor.millisecondsSinceEpoch,
      updatedAt: scheduledFor.millisecondsSinceEpoch,
      profileId: 'system',
    );

void main() {
  final now = DateTime.utc(2026, 6, 1, 12);

  test(
    'schedules everything within the window that is not already pending',
    () {
      final plan = planNotifications(
        pendingByModule: {
          'water': [
            _pending('a', now.add(const Duration(hours: 1))),
            _pending('b', now.add(const Duration(days: 2))),
          ],
        },
        existingPending: const [],
        now: now,
      );

      expect(plan.toSchedule.map((e) => e.pending.id), ['a', 'b']);
      expect(plan.toCancel, isEmpty);
    },
  );

  test(
    'excludes notifications outside the window (past or beyond windowDays)',
    () {
      final plan = planNotifications(
        pendingByModule: {
          'water': [
            _pending('past', now.subtract(const Duration(minutes: 1))),
            _pending('too_far', now.add(const Duration(days: 4))),
            _pending('in_window', now.add(const Duration(days: 1))),
          ],
        },
        existingPending: const [],
        now: now,
      );

      expect(plan.toSchedule.map((e) => e.pending.id), ['in_window']);
    },
  );

  test('does not re-schedule a notification that is already registered', () {
    final plan = planNotifications(
      pendingByModule: {
        'water': [_pending('a', now.add(const Duration(hours: 1)))],
      },
      existingPending: [_ledgerRow('a', now.add(const Duration(hours: 1)))],
      now: now,
    );

    expect(plan.toSchedule, isEmpty);
    expect(plan.toCancel, isEmpty);
  });

  test(
    'cancels a registered row that fell out of the window (e.g. settings '
    'changed)',
    () {
      final plan = planNotifications(
        pendingByModule: {'water': const []},
        existingPending: [
          _ledgerRow('stale', now.add(const Duration(hours: 1))),
        ],
        now: now,
      );

      expect(plan.toCancel, ['stale']);
    },
  );

  test('caps total scheduled across all modules combined at iosPendingCap', () {
    final pending = List.generate(
      5,
      (i) => _pending('n$i', now.add(Duration(minutes: i + 1))),
    );

    final plan = planNotifications(
      pendingByModule: {'water': pending},
      existingPending: const [],
      now: now,
      iosPendingCap: 3,
    );

    expect(plan.toSchedule.map((e) => e.pending.id), ['n0', 'n1', 'n2']);
  });

  test(
    'cap drops the soonest-registered rows first when the window shrinks',
    () {
      // 4 already scheduled, cap is 3 -> the latest-scheduled one is cancelled.
      final existing = [
        _ledgerRow('n0', now.add(const Duration(minutes: 1))),
        _ledgerRow('n1', now.add(const Duration(minutes: 2))),
        _ledgerRow('n2', now.add(const Duration(minutes: 3))),
        _ledgerRow('n3', now.add(const Duration(minutes: 4))),
      ];
      final pending = [
        _pending('n0', now.add(const Duration(minutes: 1))),
        _pending('n1', now.add(const Duration(minutes: 2))),
        _pending('n2', now.add(const Duration(minutes: 3))),
        _pending('n3', now.add(const Duration(minutes: 4))),
      ];

      final plan = planNotifications(
        pendingByModule: {'water': pending},
        existingPending: existing,
        now: now,
        iosPendingCap: 3,
      );

      expect(plan.toCancel, ['n3']);
      expect(plan.toSchedule, isEmpty);
    },
  );

  test(
    'sourceOffsetsMinutes shifts scheduledAt for the matching '
    '(moduleId, sourceType)',
    () {
      final plan = planNotifications(
        pendingByModule: {
          'water': [_pending('a', now.add(const Duration(hours: 1)))],
        },
        existingPending: const [],
        now: now,
        sourceOffsetsMinutes: {('water', 'water_reminder'): 30},
      );

      expect(plan.toSchedule, hasLength(1));
      expect(
        plan.toSchedule.single.pending.scheduledAt,
        now.add(const Duration(hours: 1, minutes: 30)),
      );
      expect(
        plan.toSchedule.single.originalScheduledAt,
        now.add(const Duration(hours: 1)),
      );
    },
  );

  test('an offset of 0 is identity', () {
    final scheduledAt = now.add(const Duration(hours: 1));
    final plan = planNotifications(
      pendingByModule: {
        'water': [_pending('a', scheduledAt)],
      },
      existingPending: const [],
      now: now,
      sourceOffsetsMinutes: {('water', 'water_reminder'): 0},
    );

    expect(plan.toSchedule.single.pending.scheduledAt, scheduledAt);
  });

  test('absent (moduleId, sourceType) key is a no-op', () {
    final scheduledAt = now.add(const Duration(hours: 1));
    final plan = planNotifications(
      pendingByModule: {
        'water': [_pending('a', scheduledAt)],
      },
      existingPending: const [],
      now: now,
      sourceOffsetsMinutes: {('medicine', 'medicine_dose'): 45},
    );

    expect(plan.toSchedule.single.pending.scheduledAt, scheduledAt);
  });

  test('a different sourceType under the same module is unaffected', () {
    final scheduledAt = now.add(const Duration(hours: 1));
    final plan = planNotifications(
      pendingByModule: {
        'water': [_pending('a', scheduledAt)],
      },
      existingPending: const [],
      now: now,
      sourceOffsetsMinutes: {('water', 'low_stock'): 45},
    );

    expect(plan.toSchedule.single.pending.scheduledAt, scheduledAt);
  });

  test('null/empty sourceOffsetsMinutes behaves identically to before', () {
    final scheduledAt = now.add(const Duration(hours: 1));
    final withNull = planNotifications(
      pendingByModule: {
        'water': [_pending('a', scheduledAt)],
      },
      existingPending: const [],
      now: now,
    );
    final withEmpty = planNotifications(
      pendingByModule: {
        'water': [_pending('a', scheduledAt)],
      },
      existingPending: const [],
      now: now,
      sourceOffsetsMinutes: const {},
    );

    expect(withNull.toSchedule.single.pending.scheduledAt, scheduledAt);
    expect(withEmpty.toSchedule.single.pending.scheduledAt, scheduledAt);
  });

  test('offset shift can push a notification out of the window', () {
    // Scheduled just before windowEnd (3 days out); a positive offset
    // shifts it past the boundary, so it should be excluded and (since it
    // was previously registered) cancelled.
    final scheduledAt = now.add(const Duration(days: 3, minutes: -10));
    final plan = planNotifications(
      pendingByModule: {
        'water': [_pending('a', scheduledAt)],
      },
      existingPending: [_ledgerRow('a', scheduledAt)],
      now: now,
      sourceOffsetsMinutes: {('water', 'water_reminder'): 30},
    );

    expect(plan.toSchedule, isEmpty);
    expect(plan.toCancel, ['a']);
  });

  test('offset interacts correctly with quiet hours suppression', () {
    // Without the offset, 21:50 is outside a 22:00-07:00 quiet window.
    // A +30-minute offset shifts it to 22:20, inside the window, so it
    // should be suppressed.
    final base = DateTime.utc(2026, 6, 1, 21, 50);
    final plan = planNotifications(
      pendingByModule: {
        'water': [_pending('a', base)],
      },
      existingPending: const [],
      now: DateTime.utc(2026, 6, 1, 12),
      quietHours: const QuietHours(
        start: LocalTime(22, 0),
        end: LocalTime(7, 0),
      ),
      sourceOffsetsMinutes: {('water', 'water_reminder'): 30},
    );

    expect(plan.toSchedule, isEmpty);
  });

  test(
    'a negative offset that would push scheduledAt before now is clamped '
    'to just after now instead of dropping the occurrence',
    () {
      final scheduledAt = now.add(const Duration(minutes: 15));
      final plan = planNotifications(
        pendingByModule: {
          'water': [_pending('a', scheduledAt)],
        },
        existingPending: const [],
        now: now,
        sourceOffsetsMinutes: {('water', 'water_reminder'): -25},
      );

      expect(plan.toSchedule, hasLength(1));
      expect(plan.toSchedule.single.pending.scheduledAt.isAfter(now), isTrue);
    },
  );

  test(
    'an already-registered notification is rescheduled when a newly '
    'computed offset moves its actual fire time',
    () {
      final rawScheduledAt = now.add(const Duration(hours: 1));
      final plan = planNotifications(
        pendingByModule: {
          'water': [_pending('a', rawScheduledAt)],
        },
        // Previously registered at the un-shifted time (no offset was
        // active on the prior planning cycle).
        existingPending: [_ledgerRow('a', rawScheduledAt)],
        now: now,
        sourceOffsetsMinutes: {('water', 'water_reminder'): 30},
      );

      expect(plan.toSchedule, hasLength(1));
      expect(
        plan.toSchedule.single.pending.scheduledAt,
        rawScheduledAt.add(const Duration(minutes: 30)),
      );
    },
  );
}

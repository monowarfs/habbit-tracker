import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/notifications/audio_cue_service.dart';
import 'package:habit_tracker/core/notifications/notification_action_handler.dart';
import 'package:habit_tracker/core/notifications/notification_ledger_repository.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/test_database.dart';

class _MockAudioCueService extends Mock implements AudioCueService {}

void main() {
  late AppDatabase db;
  late NotificationLedgerRepository ledger;
  late _MockAudioCueService audioCue;

  setUpAll(() {
    registerFallbackValue(NotificationActionType.done);
  });

  setUp(() {
    db = testDatabase();
    ledger = NotificationLedgerRepository(db);
    audioCue = _MockAudioCueService();
    when(() => audioCue.playEarcon(any())).thenAnswer((_) async {});
  });

  tearDown(() => db.close());

  // Deliberately not a registered module id: `_dispatch` no-ops for an
  // unknown module, keeping this test focused on the earcon wiring
  // without needing a real Water/Medicine/Prayer fixture.
  Future<void> seedRow(String id) => ledger.insertScheduled(
    id: id,
    moduleId: 'unregistered-module',
    sourceType: 'test',
    sourceId: id,
    title: 'title',
    body: 'body',
    scheduledFor: DateTime.utc(2026, 6, 1, 8),
    deepLinkRoute: '/water',
    profileId: 'system',
  );

  test('plays the done earcon on a Done action', () async {
    await seedRow('r1');

    await handleNotificationAction(
      ledgerId: 'r1',
      moduleId: 'unregistered-module',
      actionId: kNotificationActionDone,
      database: db,
      audioCueService: audioCue,
    );

    verify(() => audioCue.playEarcon(NotificationActionType.done)).called(1);
  });

  test('plays the skip earcon on a Skip action', () async {
    await seedRow('r2');

    await handleNotificationAction(
      ledgerId: 'r2',
      moduleId: 'unregistered-module',
      actionId: kNotificationActionSkip,
      database: db,
      audioCueService: audioCue,
    );

    verify(() => audioCue.playEarcon(NotificationActionType.skip)).called(1);
  });

  // A Snooze-action variant of the above isn't included here: unlike
  // Done/Skip, a snoozed ledger row never gets a terminal `action`, so it
  // stays "pending" all the way through this same call's trailing
  // `planAndApplyNotifications`, which — for a row no real module
  // recognizes — decides to cancel it via the real
  // `NotificationService.instance` (`../../notification_service.dart`)
  // singleton. That singleton has no test seam anywhere in the codebase
  // today (pre-existing gap, not introduced by this earcon change), so it
  // can't be exercised from a plain `flutter_test` unit test. The
  // done/snooze/skip -> asset mapping this handler relies on is still
  // fully covered at the unit level in `audio_cue_test.dart`, and this
  // file's Done/Skip cases already prove the earcon call site itself is
  // wired correctly (same code path, only the case branch differs).

  test('does not play an earcon for an unknown action id', () async {
    await seedRow('r4');

    await handleNotificationAction(
      ledgerId: 'r4',
      moduleId: 'unregistered-module',
      actionId: 'not-a-real-action',
      database: db,
      audioCueService: audioCue,
    );

    verifyNever(() => audioCue.playEarcon(any()));
  });
}

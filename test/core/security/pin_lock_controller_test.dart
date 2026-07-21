import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/security/pin_lock_controller.dart';
import 'package:habit_tracker/core/security/pin_lock_service.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';

import '../../support/test_secure_storage.dart';

void main() {
  group('computeIsLocked', () {
    test(
      'never backgrounded (in-session, right after setPin) is not locked',
      () {
        expect(
          computeIsLocked(
            lastBackgroundedAt: null,
            lastUnlockedAt: null,
            timeoutSeconds: 60,
            now: DateTime.utc(2026, 6),
          ),
          isFalse,
        );
      },
    );

    test('unlocked while inside the timeout window', () {
      expect(
        computeIsLocked(
          lastBackgroundedAt: DateTime.utc(2026, 6, 1, 12),
          lastUnlockedAt: null,
          timeoutSeconds: 60,
          now: DateTime.utc(2026, 6, 1, 12, 0, 30),
        ),
        isFalse,
      );
    });

    test('locked once the timeout has elapsed', () {
      expect(
        computeIsLocked(
          lastBackgroundedAt: DateTime.utc(2026, 6, 1, 12),
          lastUnlockedAt: null,
          timeoutSeconds: 60,
          now: DateTime.utc(2026, 6, 1, 12, 1),
        ),
        isTrue,
      );
    });

    test(
      'a timeout of 0 does not re-lock on every check once already '
      'unlocked since the last backgrounding',
      () {
        final backgroundedAt = DateTime.utc(2026, 6, 1, 12);
        final unlockedAt = backgroundedAt.add(const Duration(seconds: 1));
        expect(
          computeIsLocked(
            lastBackgroundedAt: backgroundedAt,
            lastUnlockedAt: unlockedAt,
            timeoutSeconds: 0,
            now: unlockedAt.add(const Duration(minutes: 5)),
          ),
          isFalse,
        );
      },
    );

    test(
      'a stale unlock from before the latest backgrounding does not '
      'suppress the lock',
      () {
        final unlockedAt = DateTime.utc(2026, 6, 1, 10);
        final backgroundedAt = DateTime.utc(2026, 6, 1, 12);
        expect(
          computeIsLocked(
            lastBackgroundedAt: backgroundedAt,
            lastUnlockedAt: unlockedAt,
            timeoutSeconds: 0,
            now: backgroundedAt.add(const Duration(seconds: 1)),
          ),
          isTrue,
        );
      },
    );
  });

  group('PinLockController', () {
    late AppDatabase db;
    late SettingsRepositoryImpl settingsRepository;
    late PinLockService service;
    late PinLockController controller;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      settingsRepository = SettingsRepositoryImpl(db);
      service = PinLockService(storage: InMemorySecureStorage());
      controller = PinLockController(service, settingsRepository);
    });

    tearDown(() => db.close());

    test('isCurrentlyLocked is false when PIN is disabled', () async {
      expect(await controller.isCurrentlyLocked(), isFalse);
    });

    test(
      'setPin enables PIN, then a correct verify unlocks and a wrong one fails',
      () async {
        await withClock(Clock.fixed(DateTime.utc(2026, 6)), () async {
          await controller.setPin('1234');
          expect(await controller.isCurrentlyLocked(), isFalse);
        });

        await withClock(
          Clock.fixed(DateTime.utc(2026, 6, 1, 0, 2)),
          () async {
            expect(await controller.verify('0000'), isFalse);
            expect(await controller.verify('1234'), isTrue);
          },
        );
      },
    );

    test(
      'an immediate (0s) timeout does not re-lock on the next check right '
      'after a successful unlock',
      () async {
        final unlockedAt = DateTime.utc(2026, 6);
        final backgroundedAgainAt = unlockedAt.add(const Duration(minutes: 1));
        final checkAt = backgroundedAgainAt.add(const Duration(seconds: 1));

        await withClock(Clock.fixed(unlockedAt), () async {
          await controller.setPin('1234');
        });
        await settingsRepository.updatePinLockTimeoutSeconds(0);
        await withClock(Clock.fixed(backgroundedAgainAt), () async {
          await controller.recordBackgrounded();
        });
        await withClock(
          Clock.fixed(checkAt),
          () async => expect(await controller.isCurrentlyLocked(), isTrue),
        );
        await withClock(Clock.fixed(checkAt), () async {
          await controller.verify('1234');
          expect(await controller.isCurrentlyLocked(), isFalse);
        });
      },
    );

    test(
      '3 wrong attempts still allow immediate retry (no backoff yet)',
      () async {
        await controller.setPin('1234');
        await controller.verify('0000');
        await controller.verify('0000');
        await controller.verify('0000');
        expect(await controller.currentBackoff(), Duration.zero);
      },
    );

    test('4th wrong attempt introduces a 5s backoff', () async {
      await controller.setPin('1234');
      for (var i = 0; i < 4; i++) {
        await controller.verify('0000');
      }
      expect(await controller.currentBackoff(), greaterThan(Duration.zero));
    });

    test('disablePin requires the correct PIN and clears state', () async {
      await controller.setPin('1234');
      expect(await controller.disablePin('0000'), isFalse);
      expect(await controller.disablePin('1234'), isTrue);
      final settings = await settingsRepository.watchSettings().first;
      expect(settings.pinEnabled, isFalse);
    });

    test('resetAllData wipes app data and clears secure storage', () async {
      final modules = buildHabitModules(db);
      await controller.setPin('1234');
      await controller.resetAllData(modules, db);
      expect(await controller.isCurrentlyLocked(), isFalse);
      final creds = await service.readCredentials();
      expect(creds, isNull);
    });
  });
}

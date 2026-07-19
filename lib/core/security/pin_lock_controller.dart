import 'package:clock/clock.dart';
import 'package:habit_tracker/core/backup/wipe_all_data.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/security/backoff.dart';
import 'package:habit_tracker/core/security/pin_hash.dart';
import 'package:habit_tracker/core/security/pin_lock_service.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pin_lock_controller.g.dart';

/// Whether the app should be considered locked. [lastBackgroundedAt] is
/// written only on an actual `AppLifecycleState.paused` event (never on
/// unlock) and [lastUnlockedAt] only on a successful verify/setPin — kept
/// as two separate signals rather than one shared "reference point" so a
/// `0`-second ("immediately") timeout doesn't re-lock on every in-app
/// navigation between unlock and the next real backgrounding (an
/// implementation refinement found while writing this controller's
/// tests: reusing one timestamp for both meanings made `elapsed >= 0`
/// true on essentially every check once the timeout was `0`).
///
/// No backgrounding recorded yet at all -> not locked (this only happens
/// in-session, right after `setPin`, before the app has ever been
/// backgrounded — nothing to lock against yet). Otherwise: locked if
/// there's been no unlock since that backgrounding, and the elapsed time
/// since it meets or exceeds the timeout.
bool computeIsLocked({
  required DateTime? lastBackgroundedAt,
  required DateTime? lastUnlockedAt,
  required int timeoutSeconds,
  required DateTime now,
}) {
  if (lastBackgroundedAt == null) return false;
  final unlockedSinceBackgrounding =
      lastUnlockedAt != null && !lastUnlockedAt.isBefore(lastBackgroundedAt);
  if (unlockedSinceBackgrounding) return false;
  return now.difference(lastBackgroundedAt) >=
      Duration(seconds: timeoutSeconds);
}

/// The PIN lock state machine (`strategies/security.md`). Deliberately
/// not a reactive Riverpod notifier — "is locked" is naturally polled
/// (at every router navigation, at every app-resume), not something a
/// wall-clock timeout can usefully push updates for, so this is a plain
/// class with async query/mutate methods instead.
class PinLockController {
  /// Creates a controller backed by [_service] and [_settingsRepository].
  PinLockController(this._service, this._settingsRepository);

  final PinLockService _service;
  final SettingsRepository _settingsRepository;

  /// Whether the app is currently locked — the router's `redirect` gate.
  Future<bool> isCurrentlyLocked() async {
    final settings = await _settingsRepository.watchSettings().first;
    if (!settings.pinEnabled) return false;
    final lastBackgroundedAt = await _service.readLastBackgroundedAt();
    final lastUnlockedAt = await _service.readLastUnlockedAt();
    return computeIsLocked(
      lastBackgroundedAt: lastBackgroundedAt,
      lastUnlockedAt: lastUnlockedAt,
      timeoutSeconds: settings.pinLockTimeoutSeconds,
      now: clock.now(),
    );
  }

  /// Records "now" as the backgrounding reference point — called only
  /// from `main.dart`'s `AppLifecycleState.paused` hook.
  Future<void> recordBackgrounded() =>
      _service.writeLastBackgroundedAt(clock.now());

  /// Records "now" as the unlock reference point — called on every
  /// successful [verify]/[setPin], so [isCurrentlyLocked] doesn't
  /// immediately re-lock before the next real backgrounding.
  Future<void> _recordUnlocked() => _service.writeLastUnlockedAt(clock.now());

  /// How much longer the lockout backoff (`backoff.dart`) has left,
  /// or [Duration.zero] if a verify attempt is allowed right now.
  Future<Duration> currentBackoff() async {
    final lastFailedAt = await _service.readLastFailedAttemptAt();
    if (lastFailedAt == null) return Duration.zero;
    final count = await _service.readFailedAttemptCount();
    final required = calculateBackoffDelay(count);
    final elapsed = clock.now().difference(lastFailedAt);
    final remaining = required - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Checks [pin] against the stored hash. A correct PIN resets the
  /// failed-attempt count and the resume-timeout clock; a wrong one
  /// bumps the failed count. Returns `false` outright (no attempt
  /// consumed) while a backoff is still active.
  Future<bool> verify(String pin) async {
    final creds = await _service.readCredentials();
    if (creds == null) return false;
    if (await currentBackoff() > Duration.zero) return false;
    final ok = verifyPin(pin, salt: creds.salt, hash: creds.hash);
    if (ok) {
      await _service.writeFailedAttemptCount(0);
      await _recordUnlocked();
    } else {
      final count = await _service.readFailedAttemptCount();
      await _service.writeFailedAttemptCount(count + 1);
      await _service.writeLastFailedAttemptAt(clock.now());
    }
    return ok;
  }

  /// First-time PIN setup — hashes and stores [pin], enables PIN lock.
  Future<void> setPin(String pin) async {
    final creds = hashPin(pin);
    await _service.saveCredentials(salt: creds.salt, hash: creds.hash);
    await _settingsRepository.updatePinEnabled(enabled: true);
    await _recordUnlocked();
  }

  /// Changes the PIN, requiring the current one first.
  Future<bool> changePin(String oldPin, String newPin) async {
    if (!await verify(oldPin)) return false;
    final creds = hashPin(newPin);
    await _service.saveCredentials(salt: creds.salt, hash: creds.hash);
    return true;
  }

  /// Disables PIN lock, requiring the current PIN first.
  Future<bool> disablePin(String pin) async {
    if (!await verify(pin)) return false;
    await _service.clearAll();
    await _settingsRepository.updatePinEnabled(enabled: false);
    return true;
  }

  /// "Forgot PIN" — a full local data reset (FR-C-04), not a soft
  /// recovery (`strategies/security.md`): wipes every module/common
  /// table via the same helper import uses to replace data, then clears
  /// PIN state.
  Future<void> resetAllData(List<HabitModule> modules, AppDatabase db) async {
    await wipeAllAppData(modules, db);
    await _service.clearAll();
  }
}

/// The shared [PinLockController] instance.
@Riverpod(keepAlive: true)
PinLockController pinLockController(Ref ref) {
  return PinLockController(
    PinLockService(),
    ref.watch(settingsRepositoryProvider),
  );
}

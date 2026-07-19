import 'package:habit_tracker/core/security/pin_lock_service.dart';

/// A trivial in-memory [PinLockService] fake for tests — avoids the
/// `flutter_secure_storage` platform channel entirely.
class FakePinLockService implements PinLockService {
  @override
  Future<void> saveCredentials({required String salt, required String hash}) =>
      Future.value();

  @override
  Future<({String salt, String hash})?> readCredentials() async => null;

  @override
  Future<int> readFailedAttemptCount() async => 0;

  @override
  Future<void> writeFailedAttemptCount(int count) => Future.value();

  @override
  Future<DateTime?> readLastFailedAttemptAt() async => null;

  @override
  Future<void> writeLastFailedAttemptAt(DateTime instant) => Future.value();

  @override
  Future<DateTime?> readLastBackgroundedAt() async => null;

  @override
  Future<void> writeLastBackgroundedAt(DateTime instant) => Future.value();

  @override
  Future<DateTime?> readLastUnlockedAt() async => null;

  @override
  Future<void> writeLastUnlockedAt(DateTime instant) => Future.value();

  @override
  Future<void> clearAll() => Future.value();
}

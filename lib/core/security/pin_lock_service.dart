import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The sole `flutter_secure_storage` (iOS Keychain / Android Keystore)
/// importer — PIN salt/hash and lockout bookkeeping live here, not in
/// the app's own (unencrypted-in-v1) SQLite database (D-15,
/// `strategies/security.md`).
class PinLockService {
  /// Creates a service backed by [storage] (a real
  /// [FlutterSecureStorage] by default, overridable for tests).
  PinLockService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _saltKey = 'pin_salt';
  static const _hashKey = 'pin_hash';
  static const _failedCountKey = 'pin_failed_count';
  static const _lastFailedAtKey = 'pin_last_failed_at';
  static const _lastBackgroundedAtKey = 'pin_last_backgrounded_at';
  static const _lastUnlockedAtKey = 'pin_last_unlocked_at';

  /// Stores a newly hashed PIN's salt and hash.
  Future<void> saveCredentials({
    required String salt,
    required String hash,
  }) async {
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: hash);
  }

  /// The stored salt/hash pair, or `null` if no PIN has been set.
  Future<({String salt, String hash})?> readCredentials() async {
    final salt = await _storage.read(key: _saltKey);
    final hash = await _storage.read(key: _hashKey);
    if (salt == null || hash == null) return null;
    return (salt: salt, hash: hash);
  }

  /// Consecutive failed PIN attempts since the last success (`backoff.dart`).
  Future<int> readFailedAttemptCount() async {
    final raw = await _storage.read(key: _failedCountKey);
    return raw == null ? 0 : int.parse(raw);
  }

  /// Persists the failed-attempt count.
  Future<void> writeFailedAttemptCount(int count) =>
      _storage.write(key: _failedCountKey, value: count.toString());

  /// When the most recent failed attempt happened, or `null`.
  Future<DateTime?> readLastFailedAttemptAt() async {
    final raw = await _storage.read(key: _lastFailedAtKey);
    return raw == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(int.parse(raw), isUtc: true);
  }

  /// Records when the most recent failed attempt happened.
  Future<void> writeLastFailedAttemptAt(DateTime instant) => _storage.write(
    key: _lastFailedAtKey,
    value: instant.toUtc().millisecondsSinceEpoch.toString(),
  );

  /// When the app was last sent to the background, or `null` before the
  /// first backgrounding this install has seen. Written only by
  /// `main.dart`'s `AppLifecycleState.paused` hook — never by a
  /// successful unlock, so a `0` ("immediately") timeout doesn't re-lock
  /// on every subsequent in-app navigation (`readLastUnlockedAt` is the
  /// separate signal that suppresses that).
  Future<DateTime?> readLastBackgroundedAt() async {
    final raw = await _storage.read(key: _lastBackgroundedAtKey);
    return raw == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(int.parse(raw), isUtc: true);
  }

  /// Records the backgrounded reference point.
  Future<void> writeLastBackgroundedAt(DateTime instant) => _storage.write(
    key: _lastBackgroundedAtKey,
    value: instant.toUtc().millisecondsSinceEpoch.toString(),
  );

  /// When the PIN was last successfully verified (or first set). Used
  /// alongside [readLastBackgroundedAt] to tell "backgrounded, then
  /// already unlocked since" apart from "backgrounded and still owed an
  /// unlock."
  Future<DateTime?> readLastUnlockedAt() async {
    final raw = await _storage.read(key: _lastUnlockedAtKey);
    return raw == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(int.parse(raw), isUtc: true);
  }

  /// Records the unlock reference point.
  Future<void> writeLastUnlockedAt(DateTime instant) => _storage.write(
    key: _lastUnlockedAtKey,
    value: instant.toUtc().millisecondsSinceEpoch.toString(),
  );

  /// Clears every key this service owns — the "forgot PIN" reset's
  /// secure-storage half (`core/backup/wipe_all_data.dart` handles the
  /// DB half).
  Future<void> clearAll() => _storage.deleteAll();
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:habit_tracker/core/security/pin_lock_controller.dart'
    show PinLockController;
import 'package:habit_tracker/core/security/pin_lock_service.dart'
    show PinLockService;

/// A trivial in-memory [FlutterSecureStorage] fake — avoids the real
/// platform channel entirely, shared by every test that needs a real
/// [PinLockService]/[PinLockController] (not the shallow
/// `FakePinLockService`, which stubs `PinLockService` itself out
/// entirely and can't exercise real hash/backoff logic).
class InMemorySecureStorage implements FlutterSecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

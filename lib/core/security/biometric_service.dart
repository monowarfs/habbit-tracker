import 'package:local_auth/local_auth.dart';

/// Thin wrap over `local_auth` — a successful check is treated exactly
/// like a correct PIN entry; a failed/unavailable check always falls
/// back to normal PIN entry, never to a degraded no-lock state
/// (`strategies/security.md`).
class BiometricService {
  /// Creates a service backed by [localAuth] (a real
  /// [LocalAuthentication] by default, overridable for tests).
  BiometricService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  /// Whether this device can offer biometric unlock at all.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return canCheck && supported;
    } on Object {
      return false;
    }
  }

  /// Prompts the OS biometric UI. Returns `false` on any failure
  /// (cancelled, unavailable, no biometrics enrolled) rather than
  /// throwing — callers always have a PIN-entry fallback to show.
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _localAuth.authenticate(localizedReason: localizedReason);
    } on Object {
      return false;
    }
  }
}

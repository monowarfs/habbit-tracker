import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// PBKDF2-HMAC-SHA256 iteration count (`strategies/security.md`'s floor:
/// >=100,000, tuned against the reference device classes in
/// `non-functional-requirements.md` so verification stays under ~100ms —
/// this value should be re-measured on the low-mid Android reference
/// device at implementation time and lowered only if that budget is
/// missed, never below the 100,000 floor).
const _iterations = 120000;
const _keyLengthBytes = 32;
const _saltLengthBytes = 16;

/// Hashes [pin] with a freshly generated random salt
/// (`strategies/security.md`). Both `salt` and `hash` in the returned
/// record are base64-encoded, ready for `flutter_secure_storage`
/// (`pin_lock_service.dart`).
({String salt, String hash}) hashPin(String pin) {
  final salt = _randomBytes(_saltLengthBytes);
  final hash = _derive(pin, salt);
  return (salt: base64Encode(salt), hash: base64Encode(hash));
}

/// Verifies [pin] against a previously stored [salt]/[hash] pair.
bool verifyPin(String pin, {required String salt, required String hash}) {
  final derived = _derive(pin, base64Decode(salt));
  return _constantTimeEquals(derived, base64Decode(hash));
}

Uint8List _derive(String pin, Uint8List salt) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, _iterations, _keyLengthBytes));
  return derivator.process(Uint8List.fromList(utf8.encode(pin)));
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List.generate(length, (_) => random.nextInt(256)),
  );
}

/// Constant-time comparison — a naive `==` on the derived bytes would leak
/// timing information about how many leading bytes matched.
bool _constantTimeEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

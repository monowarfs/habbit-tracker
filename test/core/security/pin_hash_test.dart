import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/security/pin_hash.dart';

void main() {
  test('verifyPin accepts the correct PIN and rejects a wrong one', () {
    final result = hashPin('1234');
    expect(verifyPin('1234', salt: result.salt, hash: result.hash), isTrue);
    expect(verifyPin('4321', salt: result.salt, hash: result.hash), isFalse);
  });

  test('hashPin never stores the plaintext PIN in salt or hash', () {
    final result = hashPin('1234');
    expect(result.hash, isNot(contains('1234')));
    expect(result.salt, isNot(contains('1234')));
  });

  test('two hashPin calls for the same PIN produce different salts', () {
    final a = hashPin('1234');
    final b = hashPin('1234');
    expect(a.salt, isNot(b.salt));
    expect(a.hash, isNot(b.hash));
  });
}

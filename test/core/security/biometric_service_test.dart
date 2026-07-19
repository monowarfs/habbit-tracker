import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/security/biometric_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalAuth extends Mock implements LocalAuthentication {}

void main() {
  late _MockLocalAuth localAuth;
  late BiometricService service;

  setUp(() {
    localAuth = _MockLocalAuth();
    service = BiometricService(localAuth: localAuth);
  });

  test(
    'isAvailable is true only when the device can check biometrics',
    () async {
      when(() => localAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(() => localAuth.isDeviceSupported()).thenAnswer((_) async => true);
      expect(await service.isAvailable(), isTrue);
    },
  );

  test(
    'authenticate delegates to LocalAuthentication.authenticate',
    () async {
      when(
        () => localAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
        ),
      ).thenAnswer((_) async => true);
      expect(await service.authenticate(localizedReason: 'Unlock'), isTrue);
    },
  );

  test('authenticate returns false if the plugin throws', () async {
    when(
      () => localAuth.authenticate(
        localizedReason: any(named: 'localizedReason'),
      ),
    ).thenThrow(Exception('no hardware'));
    expect(await service.authenticate(localizedReason: 'Unlock'), isFalse);
  });
}

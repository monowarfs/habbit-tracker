import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/security/pin_lock_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late PinLockService service;

  setUp(() {
    storage = _MockStorage();
    service = PinLockService(storage: storage);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
  });

  test('saveCredentials writes salt and hash under their own keys', () async {
    await service.saveCredentials(salt: 's', hash: 'h');
    verify(() => storage.write(key: 'pin_salt', value: 's')).called(1);
    verify(() => storage.write(key: 'pin_hash', value: 'h')).called(1);
  });

  test('readCredentials returns null when either key is missing', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    expect(await service.readCredentials(), isNull);
  });

  test('readCredentials returns the pair once both are set', () async {
    when(() => storage.read(key: 'pin_salt')).thenAnswer((_) async => 's');
    when(() => storage.read(key: 'pin_hash')).thenAnswer((_) async => 'h');
    final creds = await service.readCredentials();
    expect(creds, (salt: 's', hash: 'h'));
  });

  test('readFailedAttemptCount defaults to 0', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    expect(await service.readFailedAttemptCount(), 0);
  });

  test('readLastUnlockedAt round-trips via writeLastUnlockedAt', () async {
    final values = <String, String>{};
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      values[invocation.namedArguments[#key] as String] =
          invocation.namedArguments[#value] as String;
    });
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((invocation) async {
      return values[invocation.namedArguments[#key] as String];
    });

    final instant = DateTime.utc(2026, 6, 1, 12);
    await service.writeLastUnlockedAt(instant);
    expect(await service.readLastUnlockedAt(), instant);
  });

  test('clearAll delegates to deleteAll', () async {
    when(() => storage.deleteAll()).thenAnswer((_) async {});
    await service.clearAll();
    verify(() => storage.deleteAll()).called(1);
  });
}

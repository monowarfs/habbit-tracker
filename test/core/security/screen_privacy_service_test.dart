import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/security/screen_privacy_service.dart';

void main() {
  group('ScreenPrivacyService', () {
    test('enable calls preventScreenshotOn and protectDataLeakageOn', () async {
      final calls = <String>[];
      final service = ScreenPrivacyService(
        preventScreenshotOn: () async => calls.add('screenshotOn'),
        protectDataLeakageOn: () async => calls.add('leakageOn'),
      );

      await service.enable();

      expect(calls, ['screenshotOn', 'leakageOn']);
    });

    test(
      'disable calls preventScreenshotOff and protectDataLeakageOff',
      () async {
        final calls = <String>[];
        final service = ScreenPrivacyService(
          preventScreenshotOff: () async => calls.add('screenshotOff'),
          protectDataLeakageOff: () async => calls.add('leakageOff'),
        );

        await service.disable();

        expect(calls, ['screenshotOff', 'leakageOff']);
      },
    );

    test('enable and disable are independent', () async {
      final calls = <String>[];
      final service = ScreenPrivacyService(
        preventScreenshotOn: () async => calls.add('on'),
        protectDataLeakageOn: () async => calls.add('on'),
        preventScreenshotOff: () async => calls.add('off'),
        protectDataLeakageOff: () async => calls.add('off'),
      );

      await service.enable();
      await service.disable();

      expect(calls, ['on', 'on', 'off', 'off']);
    });
  });
}

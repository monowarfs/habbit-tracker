import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/certificate/certificate_share.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test(
    'shareCertificate hands the image file and text to the share sheet',
    () async {
      ShareParams? captured;
      final share = CertificateShare(
        share: (params) async => captured = params,
        saveImage: (_) async => fail('should not fall back to saveImage'),
      );

      await share.shareCertificate('/tmp/cert.png', text: 'Look at this!');

      expect(captured, isNotNull);
      expect(captured!.files!.single.path, '/tmp/cert.png');
      expect(captured!.text, 'Look at this!');
    },
  );

  test('shareCertificate falls back to saveToLibrary when the share sheet '
      'throws', () async {
    var saved = false;
    final share = CertificateShare(
      share: (_) async => throw Exception('share sheet unavailable'),
      saveImage: (path) async {
        saved = true;
        expect(path, '/tmp/cert.png');
      },
    );

    await share.shareCertificate('/tmp/cert.png');

    expect(saved, isTrue);
  });

  test('saveToLibrary saves the image directly', () async {
    String? savedPath;
    final share = CertificateShare(
      share: (_) async => fail('should not share'),
      saveImage: (path) async => savedPath = path,
    );

    await share.saveToLibrary('/tmp/cert.png');

    expect(savedPath, '/tmp/cert.png');
  });

  test('the default share/saveImage arguments exist and type-check against '
      'the real APIs', () {
    // Compile-time check only — never actually invoked (that would hit
    // the real share_plus/image_gallery_saver platform channels), same
    // precedent as `recap_share_usecase_test.dart`'s equivalent check.
    expect(const CertificateShare().shareCertificate, isA<Function>());
  });
}

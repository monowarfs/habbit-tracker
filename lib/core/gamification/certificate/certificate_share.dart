import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:share_plus/share_plus.dart';

/// Shares a generated certificate image via the platform's share sheet,
/// falling back to saving it straight to the photo library if the share
/// sheet itself fails (`docs/superpowers/specs/06-gamification/
/// 07-milestone-certificate-image-design.md`'s "Share sheet failure"
/// edge case).
///
/// [share]/[saveImage] are test-only seams — same precedent as
/// `recap_share_usecase.dart`'s `share` param — the real
/// `share_plus`/`image_gallery_saver` platform channels aren't
/// exercised under `flutter test`.
class CertificateShare {
  /// Creates a certificate share helper.
  const CertificateShare({
    this.share = _defaultShare,
    this.saveImage = _defaultSaveImage,
  });

  /// Hands a [ShareParams] to the OS share sheet.
  final Future<void> Function(ShareParams params) share;

  /// Saves image bytes to the device's photo library.
  final Future<void> Function(String imagePath) saveImage;

  /// Shares the certificate at [imagePath] via the platform's share
  /// sheet, with optional accompanying [text]. Falls back to
  /// [saveToLibrary] if the share sheet itself throws.
  Future<void> shareCertificate(String imagePath, {String? text}) async {
    try {
      await share(ShareParams(files: [XFile(imagePath)], text: text));
    } on Object {
      await saveToLibrary(imagePath);
    }
  }

  /// Saves the certificate at [imagePath] to the device's photo library.
  Future<void> saveToLibrary(String imagePath) async {
    await saveImage(imagePath);
  }
}

Future<void> _defaultShare(ShareParams params) async {
  await SharePlus.instance.share(params);
}

Future<void> _defaultSaveImage(String imagePath) async {
  await ImageGallerySaver.saveFile(imagePath);
}

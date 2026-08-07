import 'dart:io';

import 'package:clock/clock.dart';
import 'package:path/path.dart' as p;

/// Caches generated certificate PNGs on disk so re-sharing the same
/// milestone doesn't re-render it (`docs/superpowers/specs/
/// 06-gamification/07-milestone-certificate-image-design.md`). Cache
/// directory: `app_documents/certificates/`.
///
/// The constructor takes the already-resolved app documents directory —
/// resolving it is the caller's job (a single `await
/// getApplicationDocumentsDirectory()`, same as `CertificateGenerator`'s
/// caller) so [getCached]/[cache] can stay synchronous, matching the
/// plan's declared API.
class CertificateCache {
  /// Creates a cache rooted under [documentsDir]/certificates.
  CertificateCache(Directory documentsDir)
    : _cacheDir = Directory(p.join(documentsDir.path, 'certificates'));

  final Directory _cacheDir;

  /// Returns the cached certificate path for [cacheKey] if it exists.
  String? getCached(String cacheKey) {
    final file = File(p.join(_cacheDir.path, '$cacheKey.png'));
    return file.existsSync() ? file.path : null;
  }

  /// Stores the certificate at [imagePath] in the cache under [cacheKey].
  void cache(String cacheKey, String imagePath) {
    _cacheDir.createSync(recursive: true);
    final dest = p.join(_cacheDir.path, '$cacheKey.png');
    if (p.equals(imagePath, dest)) return;
    File(imagePath).copySync(dest);
  }

  /// Deletes cached certificates older than 30 days.
  Future<void> pruneOldEntries() async {
    if (!_cacheDir.existsSync()) return;
    final cutoff = clock.now().subtract(const Duration(days: 30));
    for (final entity in _cacheDir.listSync()) {
      if (entity is! File) continue;
      final modified = entity.lastModifiedSync();
      if (modified.isBefore(cutoff)) {
        await entity.delete();
      }
    }
  }
}

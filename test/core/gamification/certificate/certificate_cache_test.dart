import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/certificate/certificate_cache.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('certificate_cache_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('getCached returns null when nothing is cached (miss)', () {
    final cache = CertificateCache(tempDir);
    expect(cache.getCached('water_streak_30_20260807'), isNull);
  });

  test('cache then getCached returns the cached path (hit)', () {
    final cache = CertificateCache(tempDir);
    final source = File('${tempDir.path}/source.png')
      ..writeAsBytesSync([1, 2, 3]);

    cache.cache('water_streak_30_20260807', source.path);
    final cached = cache.getCached('water_streak_30_20260807');

    expect(cached, isNotNull);
    expect(File(cached!).readAsBytesSync(), [1, 2, 3]);
    // Stored under the app documents dir's own `certificates/` subfolder.
    expect(
      cached,
      contains(
        '${Platform.pathSeparator}certificates${Platform.pathSeparator}',
      ),
    );
  });

  test('pruneOldEntries deletes cached files older than 30 days', () async {
    final cache = CertificateCache(tempDir);
    final source = File('${tempDir.path}/source.png')
      ..writeAsBytesSync([1, 2, 3]);
    cache.cache('old_entry', source.path);
    cache.cache('fresh_entry', source.path);

    final cachedDir = Directory('${tempDir.path}/certificates');
    final oldFile = File('${cachedDir.path}/old_entry.png');
    // Backdate the "old" entry past the 30-day prune threshold; leave
    // the "fresh" one at its just-written mtime.
    oldFile.setLastModifiedSync(
      DateTime.now().subtract(const Duration(days: 45)),
    );

    await withClock(Clock.fixed(DateTime.now()), () async {
      await cache.pruneOldEntries();
    });

    expect(cache.getCached('old_entry'), isNull);
    expect(cache.getCached('fresh_entry'), isNotNull);
  });

  test(
    'pruneOldEntries is a no-op when the cache directory does not exist',
    () async {
      final cache = CertificateCache(tempDir);
      await cache.pruneOldEntries();
      // No exception — nothing to prune yet.
    },
  );
}

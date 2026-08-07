import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/certificate/certificate_cache.dart';
import 'package:habit_tracker/core/gamification/certificate/certificate_generator.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';

AchievementDefinition _definition({required String key, required int target}) {
  return AchievementDefinition(
    key: key,
    moduleId: 'water',
    titleKey: 'title',
    descriptionKey: 'description',
    target: target,
    currentProgress: () async => 0,
  );
}

void main() {
  group('qualifiesForCertificate', () {
    test('a 30-day streak milestone qualifies', () {
      expect(
        CertificateGenerator.qualifiesForCertificate(
          _definition(key: 'water_streak_30', target: 30),
        ),
        isTrue,
      );
    });

    test('a 100-day streak milestone qualifies', () {
      expect(
        CertificateGenerator.qualifiesForCertificate(
          _definition(key: 'medicine_adherence_streak_100', target: 100),
        ),
        isTrue,
      );
    });

    test('a 7-day streak milestone does not qualify (target < 30)', () {
      expect(
        CertificateGenerator.qualifiesForCertificate(
          _definition(key: 'water_streak_7', target: 7),
        ),
        isFalse,
      );
    });

    test('a non-streak achievement does not qualify, even at target 30', () {
      expect(
        CertificateGenerator.qualifiesForCertificate(
          _definition(key: 'water_first_log', target: 30),
        ),
        isFalse,
      );
    });
  });

  group('generate', () {
    testWidgets('returns the cached path without re-rendering on a cache '
        'hit', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'certificate_generator_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final cache = CertificateCache(tempDir);
      // Pre-populate the cache under the exact key `generate` computes
      // (`achievementKey_yyyyMMdd`), pointing at an existing file — this
      // proves the cache-hit path never touches `ImageRenderer` (which
      // needs a live `Overlay`/frame to render, not exercised here).
      final preRendered = File('${tempDir.path}/pre_rendered.png')
        ..writeAsBytesSync([1, 2, 3]);
      cache.cache('water_streak_30_20260807', preRendered.path);

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final generator = CertificateGenerator(cache: cache);
      final path = await generator.generate(
        context: context,
        achievementKey: 'water_streak_30',
        moduleName: 'Water',
        streakDays: 30,
        accentColor: Colors.blue,
        l10n: l10n,
        date: DateTime(2026, 8, 7),
      );

      expect(path, cache.getCached('water_streak_30_20260807'));
      expect(File(path).readAsBytesSync(), [1, 2, 3]);
    });
  });
}

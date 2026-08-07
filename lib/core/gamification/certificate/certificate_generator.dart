import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/achievements/achievement_kind.dart';
import 'package:habit_tracker/core/gamification/certificate/certificate_cache.dart';
import 'package:habit_tracker/core/gamification/certificate/certificate_widget.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/widgets/image_renderer.dart';
import 'package:intl/intl.dart';

/// Generates (and caches) a milestone certificate image
/// (`docs/superpowers/specs/06-gamification/
/// 07-milestone-certificate-image-design.md`). No DB tables — the image
/// itself is the only artifact, cached as a PNG file via
/// [CertificateCache].
class CertificateGenerator {
  /// Creates a generator backed by [cache].
  const CertificateGenerator({required this.cache});

  /// The on-disk cache checked before re-rendering.
  final CertificateCache cache;

  /// Determines if an achievement qualifies for a certificate: a streak
  /// milestone (`isStreakMilestoneKey`) of at least 30 days. Smaller
  /// milestones don't warrant a certificate. `static` — this is a pure
  /// predicate over [definition], no instance state (a `cache`) needed,
  /// so a caller can check it without constructing a generator.
  static bool qualifiesForCertificate(AchievementDefinition definition) =>
      isStreakMilestoneKey(definition.key) && definition.target >= 30;

  /// Generates a certificate image for the given milestone, returning
  /// the image file path. Reuses the cached file for [achievementKey] if
  /// one already exists for [date]'s day.
  ///
  /// [context] drives `ImageRenderer`'s off-screen capture (the plan's
  /// `ImageRenderer.captureWidget` needs a live `Overlay`, so this must
  /// too) and [achievementKey] keys the cache (the plan's "cache keyed
  /// by achievementKey + date") — neither was in the design doc's
  /// sketch signature, both are required to actually implement it.
  Future<String> generate({
    required BuildContext context,
    required String achievementKey,
    required String moduleName,
    required int streakDays,
    required Color accentColor,
    required AppLocalizations l10n,
    String? userName,
    DateTime? date,
  }) async {
    final achievedAt = date ?? clock.now();
    final cacheKey = _cacheKeyFor(achievementKey, achievedAt);

    final cached = cache.getCached(cacheKey);
    if (cached != null && File(cached).existsSync()) return cached;

    final widget = CertificateWidget(
      moduleName: moduleName,
      streakDays: streakDays,
      date: achievedAt,
      accentColor: accentColor,
      l10n: l10n,
      userName: userName,
    );
    final path = await ImageRenderer.renderToFile(
      context,
      widget,
      fileName: '$cacheKey.png',
      size: const Size(1080, 1080),
    );
    cache.cache(cacheKey, path);
    return path;
  }

  String _cacheKeyFor(String achievementKey, DateTime date) {
    return '${achievementKey}_${DateFormat('yyyyMMdd').format(date)}';
  }
}

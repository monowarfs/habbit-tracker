import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';

/// WCAG 2.1 relative luminance / contrast ratio — no CVD-simulation
/// package is a dev dependency (ponytail: none was already installed and
/// this is the only place that would use one), so this is the automated
/// regression guard the design doc allows as a fallback: a hue-distance +
/// contrast-ratio check standing in for a live deuteranopia/protanopia
/// simulation (see `docs/superpowers/specs/07-accessibility/
/// 03-palette-audit-results.md` for the manual simulation pass).
double _relativeLuminance(Color color) {
  double linearize(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * linearize(color.r) +
      0.7152 * linearize(color.g) +
      0.0722 * linearize(color.b);
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AppSemanticColors CVD-safety regression guard', () {
    final lightSurface = ColorScheme.fromSeed(
      seedColor: const Color(0xFF006874),
    ).surface;
    final darkSurface = ColorScheme.fromSeed(
      seedColor: const Color(0xFF006874),
      brightness: Brightness.dark,
    ).surface;

    test('light missed meets WCAG AA (4.5:1) against the app surface', () {
      expect(
        _contrastRatio(AppSemanticColors.light.missed, lightSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dark missed meets WCAG AA (4.5:1) against the app surface', () {
      expect(
        _contrastRatio(AppSemanticColors.dark.missed, darkSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test(
      'success (green) and missed (orange) sit far apart on the hue '
      'wheel in both themes — the red/green CVD failure mode requires a '
      'small hue separation, not just a value/contrast difference',
      () {
        final lightHueDelta =
            (HSLColor.fromColor(AppSemanticColors.light.success).hue -
                    HSLColor.fromColor(AppSemanticColors.light.missed).hue)
                .abs();
        final darkHueDelta =
            (HSLColor.fromColor(AppSemanticColors.dark.success).hue -
                    HSLColor.fromColor(AppSemanticColors.dark.missed).hue)
                .abs();
        expect(lightHueDelta, greaterThan(90));
        expect(darkHueDelta, greaterThan(90));
      },
    );

    test(
      'missed is not a hue rotation of the M3 error red — it is a '
      'distinct app-chosen color, not inherited from ColorScheme.error',
      () {
        final error = ColorScheme.fromSeed(
          seedColor: const Color(0xFF006874),
        ).error;
        expect(AppSemanticColors.light.missed, isNot(equals(error)));
      },
    );
  });
}

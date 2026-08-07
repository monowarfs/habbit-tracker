import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/widgets/heatmap_color_scheme.dart';

void main() {
  group('HeatmapColorScheme.colorForStatus', () {
    // Mirrors how `AppTheme.light`/`.dark` actually register
    // `AppSemanticColors` (`app_theme.dart` line ~176/190) — a bare
    // `ThemeData(brightness: ...)` doesn't reliably flow through to the
    // `semanticColors` brightness fallback in a test `ThemeData`.
    Future<Color> colorFor(
      WidgetTester tester,
      ModuleDayStatusKind kind, {
      AppSemanticColors semanticColors = AppSemanticColors.light,
    }) async {
      late Color result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [semanticColors]),
          home: Builder(
            builder: (context) {
              result = HeatmapColorScheme.colorForStatus(context, kind);
              return const SizedBox();
            },
          ),
        ),
      );
      // `MaterialApp` implicitly animates theme changes (`AnimatedTheme`)
      // — without settling, a second `pumpWidget` call in the same test
      // reads a mid-transition (still old-theme) value.
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('complete resolves to the shared success color', (
      tester,
    ) async {
      final color = await colorFor(tester, ModuleDayStatusKind.complete);
      expect(color, AppSemanticColors.light.success);
    });

    testWidgets('missed resolves to the shared missed color (never red)', (
      tester,
    ) async {
      final color = await colorFor(tester, ModuleDayStatusKind.missed);
      expect(color, AppSemanticColors.light.missed);
      expect(color, isNot(Colors.red));
    });

    testWidgets('every kind maps to a color, and complete/missed/partial '
        'are pairwise distinct', (tester) async {
      final complete = await colorFor(tester, ModuleDayStatusKind.complete);
      final partial = await colorFor(tester, ModuleDayStatusKind.partial);
      final missed = await colorFor(tester, ModuleDayStatusKind.missed);
      final paused = await colorFor(tester, ModuleDayStatusKind.paused);
      final none = await colorFor(tester, ModuleDayStatusKind.none);

      expect({complete, partial, missed}.length, 3);
      // paused and none intentionally share the neutral surface color —
      // both render their distinction via the icon overlay instead.
      expect(paused, none);
    });

    testWidgets('resolves to different colors in light vs dark theme', (
      tester,
    ) async {
      final light = await colorFor(tester, ModuleDayStatusKind.complete);
      final dark = await colorFor(
        tester,
        ModuleDayStatusKind.complete,
        semanticColors: AppSemanticColors.dark,
      );
      expect(light, isNot(equals(dark)));
    });
  });

  group('HeatmapColorScheme.iconForStatus', () {
    test('none has no icon; every other kind has a distinct icon', () {
      expect(HeatmapColorScheme.iconForStatus(ModuleDayStatusKind.none), null);
      final icons = {
        HeatmapColorScheme.iconForStatus(ModuleDayStatusKind.complete),
        HeatmapColorScheme.iconForStatus(ModuleDayStatusKind.partial),
        HeatmapColorScheme.iconForStatus(ModuleDayStatusKind.missed),
        HeatmapColorScheme.iconForStatus(ModuleDayStatusKind.paused),
      };
      expect(icons.length, 4);
      expect(icons, isNot(contains(null)));
    });
  });
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/illustrations/crescent_mat_painter.dart';
import 'package:habit_tracker/core/widgets/illustrations/pill_calendar_painter.dart';
import 'package:habit_tracker/core/widgets/illustrations/water_drop_painter.dart';

/// Paints [painter] onto a real (disposed-immediately) `dart:ui` canvas —
/// the cheapest way to assert "this paint() call doesn't throw" without a
/// full widget pump, since `flutter_test`'s tester embedder provides a
/// real `dart:ui` regardless of `test()` vs `testWidgets()`.
void _paintOnRealCanvas(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  recorder.endRecording().dispose();
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('WaterDropPainter', () {
    test('paints without throwing at the empty-state illustration size', () {
      expect(
        () => _paintOnRealCanvas(
          const WaterDropPainter(Colors.blue),
          const Size(96, 96),
        ),
        returnsNormally,
      );
    });

    test('stores the color it was constructed with', () {
      const painter = WaterDropPainter(Colors.blue);
      expect(painter.color, Colors.blue);
    });

    test('shouldRepaint is true only when the color actually changes', () {
      const a = WaterDropPainter(Colors.blue);
      const b = WaterDropPainter(Colors.blue);
      const c = WaterDropPainter(Colors.red);
      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
    });
  });

  group('PillCalendarPainter', () {
    test('paints without throwing at the empty-state illustration size', () {
      expect(
        () => _paintOnRealCanvas(
          const PillCalendarPainter(Colors.deepPurple),
          const Size(96, 96),
        ),
        returnsNormally,
      );
    });

    test('stores the color it was constructed with', () {
      const painter = PillCalendarPainter(Colors.deepPurple);
      expect(painter.color, Colors.deepPurple);
    });

    test('shouldRepaint is true only when the color actually changes', () {
      const a = PillCalendarPainter(Colors.deepPurple);
      const b = PillCalendarPainter(Colors.deepPurple);
      const c = PillCalendarPainter(Colors.teal);
      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
    });
  });

  group('CrescentMatPainter', () {
    test('paints without throwing at the empty-state illustration size', () {
      expect(
        () => _paintOnRealCanvas(
          const CrescentMatPainter(Colors.amber),
          const Size(96, 96),
        ),
        returnsNormally,
      );
    });

    test('stores the color it was constructed with', () {
      const painter = CrescentMatPainter(Colors.amber);
      expect(painter.color, Colors.amber);
    });

    test('shouldRepaint is true only when the color actually changes', () {
      const a = CrescentMatPainter(Colors.amber);
      const b = CrescentMatPainter(Colors.amber);
      const c = CrescentMatPainter(Colors.blue);
      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
    });
  });
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/reports/presentation/widgets/recap_card_capture.dart';

void main() {
  testWidgets(
    'capturePng renders the wrapped widget to real PNG bytes — this is a '
    'genuine RenderRepaintBoundary.toImage() call, the same mechanism '
    'matchesGoldenFile itself relies on, not a stub',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecapCardCapture(
            child: SizedBox(
              width: 100,
              height: 100,
              child: ColoredBox(color: Colors.red),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bytes =
          await tester.runAsync(
            () => RecapCardCapture.capturePng(pixelRatio: 1),
          ) ??
          Uint8List(0);

      expect(bytes, isNotEmpty);
      // The 8-byte PNG file signature — proves this is real,
      // correctly-encoded image data without depending on decoding the
      // pixels themselves.
      expect(bytes.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
    },
  );
}

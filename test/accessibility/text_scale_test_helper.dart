import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [widget] with an ancestor [MediaQuery] forcing [scale] as the
/// text scale factor, settles, then fails the test if any exception was
/// reported during layout/paint.
///
/// A `RenderFlex` overflow doesn't throw a catchable exception at the call
/// site — it's reported through [FlutterError.onError] and only surfaces
/// via [WidgetTester.takeException] after the pump, which is what this
/// helper checks.
Future<void> pumpAtTextScale(
  WidgetTester tester,
  Widget widget,
  double scale,
) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData().copyWith(
        textScaler: TextScaler.linear(scale),
      ),
      child: widget,
    ),
  );
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: 'Unexpected exception (likely overflow) at ${scale}x text scale',
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/illustrations/water_drop_painter.dart';
import 'package:habit_tracker/core/widgets/module_empty_state.dart';

void main() {
  testWidgets(
    'renders the message below a CustomPaint built from the given painter '
    'and accent color',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ModuleEmptyState(
              painter: WaterDropPainter.new,
              message: 'No entries yet today',
              accentColor: Colors.blue,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No entries yet today'), findsOneWidget);

      final customPaint = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .firstWhere((w) => w.painter is WaterDropPainter);
      final painter = customPaint.painter! as WaterDropPainter;
      expect(painter.color, Colors.blue);
    },
  );
}

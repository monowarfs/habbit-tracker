import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/dismissible_hint_card.dart';

void main() {
  testWidgets(
    'shows the message and calls onDismiss when the close button is tapped',
    (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DismissibleHintCard(
              message: 'Water helps regulate temperature.',
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('Water helps regulate temperature.'), findsOneWidget);
      expect(dismissed, isFalse);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(dismissed, isTrue);
    },
  );
}

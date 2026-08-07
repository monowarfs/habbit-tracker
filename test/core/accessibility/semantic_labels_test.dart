import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/accessibility/semantic_labels.dart';

void main() {
  testWidgets('wrap: attaches the given label to the Semantics node', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SemanticLabels.wrap(label: 'Test label', child: const Text('x')),
      ),
    );

    expect(
      tester.getSemantics(find.text('x')).label,
      contains('Test label'),
    );
  });

  testWidgets(
    'wrap: excludeSemantics true replaces the child subtree label instead '
    'of merging with it',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SemanticLabels.wrap(
            label: 'Replacement label',
            excludeSemantics: true,
            child: const Text('hidden child text'),
          ),
        ),
      );

      final node = tester.getSemantics(find.text('hidden child text'));
      expect(node.label, 'Replacement label');
      expect(node.label, isNot(contains('hidden child text')));
    },
  );
}

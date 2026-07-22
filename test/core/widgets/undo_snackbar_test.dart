import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/undo_snackbar.dart';

void main() {
  Future<void> pumpTrigger(
    WidgetTester tester, {
    required VoidCallback Function(BuildContext) buildTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: buildTap(context),
              child: const Text('trigger'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tapping Undo runs onUndo and never runs onCommit', (
    tester,
  ) async {
    var undoCalled = false;
    var commitCalled = false;
    await pumpTrigger(
      tester,
      buildTap: (context) => () {
        unawaited(
          showUndoSnackbar(
            context,
            message: 'Entry deleted',
            undoLabel: 'Undo',
            onCommit: () async => commitCalled = true,
            onUndo: () => undoCalled = true,
          ),
        );
      },
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();
    // Let the snackbar's enter animation finish (well under the 4s
    // default duration) before tapping its action.
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undoCalled, isTrue);
    expect(commitCalled, isFalse);
  });

  testWidgets(
    'letting the snackbar time out runs onCommit and never runs onUndo',
    (tester) async {
      var undoCalled = false;
      var commitCalled = false;
      await pumpTrigger(
        tester,
        buildTap: (context) => () {
          unawaited(
            showUndoSnackbar(
              context,
              message: 'Entry deleted',
              undoLabel: 'Undo',
              duration: const Duration(milliseconds: 600),
              onCommit: () async => commitCalled = true,
              onUndo: () => undoCalled = true,
            ),
          );
        },
      );

      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Undo'), findsOneWidget);

      // Mirrors flutter/test/material/snack_bar_test.dart's own
      // "SnackBarClosedReason" timeout case: the auto-dismiss Timer is
      // only registered on a `build()` triggered once the enter
      // animation completes, so it takes a few discrete pumps (not one
      // big jump) before `pumpAndSettle` can carry it the rest of the way.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(commitCalled, isTrue);
      expect(undoCalled, isFalse);
    },
  );

  testWidgets('onCommit runs even with no onUndo callback given', (
    tester,
  ) async {
    var commitCalled = false;
    await pumpTrigger(
      tester,
      buildTap: (context) => () {
        unawaited(
          showUndoSnackbar(
            context,
            message: 'Dose updated',
            undoLabel: 'Undo',
            duration: const Duration(milliseconds: 600),
            onCommit: () async => commitCalled = true,
          ),
        );
      },
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(commitCalled, isTrue);
  });
}

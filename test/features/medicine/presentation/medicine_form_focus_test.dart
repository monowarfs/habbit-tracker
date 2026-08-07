import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_form_screen.dart';

/// Spec: docs/superpowers/specs/07-accessibility/
/// 10-FOCUS-ORDER-KEYBOARD-NAVIGATION-PASS-IMPLEMENTATION-PLAN.md
/// (Task 2) — tab order across the Medicine add-medicine form's steps
/// must follow the visual top-to-bottom layout.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pumpForm(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
        GoRoute(path: '/form', builder: (_, _) => const MedicineFormScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push('/form'));
    await tester.pumpAndSettle();
  }

  FocusNode textFieldNode(WidgetTester tester, Finder textField) => tester
      .state<EditableTextState>(
        find.descendant(of: textField, matching: find.byType(EditableText)),
      )
      .widget
      .focusNode;

  FocusNode textOwnerNode(WidgetTester tester, Finder container) => Focus.of(
    tester.element(
      find.descendant(of: container, matching: find.byType(Text)).first,
    ),
  );

  testWidgets(
    'details step: tab order is name -> dosage -> Next',
    (tester) async {
      await pumpForm(tester);
      // Step 0 (presets) -> step 1 (details).
      await tester.tap(find.text('Custom schedule'));
      await tester.pumpAndSettle();

      final nameNode = textFieldNode(tester, find.byType(TextField).at(0));
      final dosageNode = textFieldNode(tester, find.byType(TextField).at(1));
      final nextNode = textOwnerNode(tester, find.byType(FilledButton));

      nameNode.requestFocus();
      await tester.pump();
      expect(nameNode.hasFocus, isTrue);

      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      expect(dosageNode.hasFocus, isTrue);

      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      expect(nextNode.hasFocus, isTrue);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'stock step: tab order is track-stock switch -> count -> threshold',
    (tester) async {
      await pumpForm(tester);
      await tester.tap(find.text('Custom schedule'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Ibuprofen');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      final switchTileNode = textOwnerNode(tester, find.byType(SwitchListTile))
        ..requestFocus();
      await tester.pump();
      expect(switchTileNode.hasFocus, isTrue);

      // Turning stock tracking on reveals the count/threshold fields.
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      final countNode = textFieldNode(tester, find.byType(TextField).at(0));
      final thresholdNode = textFieldNode(
        tester,
        find.byType(TextField).at(1),
      );

      // Re-fetch the switch tile's node: toggling rebuilt it.
      textOwnerNode(
        tester,
        find.byType(SwitchListTile),
      ).requestFocus();
      await tester.pump();
      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      expect(countNode.hasFocus, isTrue);

      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      expect(thresholdNode.hasFocus, isTrue);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'tapping Next with an empty name shows an error and moves focus to it',
    (tester) async {
      await pumpForm(tester);
      await tester.tap(find.text('Custom schedule'));
      await tester.pumpAndSettle();

      // Move focus elsewhere first so we can tell requestFocus() actually
      // moved it.
      final dosageNode = textFieldNode(tester, find.byType(TextField).at(1))
        ..requestFocus();
      await tester.pump();
      expect(dosageNode.hasFocus, isTrue);

      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Enter a name.'), findsOneWidget);
      final nameNode = textFieldNode(tester, find.byType(TextField).at(0));
      expect(nameNode.hasFocus, isTrue);

      await disposeTree(tester);
    },
  );
}

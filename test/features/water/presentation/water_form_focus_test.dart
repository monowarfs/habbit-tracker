import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_add_entry_screen.dart';

/// Spec: docs/superpowers/specs/07-accessibility/
/// 10-FOCUS-ORDER-KEYBOARD-NAVIGATION-PASS-IMPLEMENTATION-PLAN.md
/// (Tasks 1 and 5) — tab order across the custom-log form must follow
/// the visual top-to-bottom layout, and a validation failure must move
/// keyboard focus to the field carrying the error.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WaterAddEntryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // `TextField` exposes its `FocusNode` directly off `EditableTextState`.
  FocusNode textFieldNode(WidgetTester tester, Finder textField) => tester
      .state<EditableTextState>(
        find.descendant(of: textField, matching: find.byType(EditableText)),
      )
      .widget
      .focusNode;

  // `ListTile`/`FilledButton` build their own `Focus` as a *descendant*
  // of themselves (around the ink response) — `Focus.of()` walks up, so
  // look up from their (unambiguous) `Icon`/`Text` child instead of the
  // container itself.
  FocusNode iconOwnerNode(WidgetTester tester, Finder container) => Focus.of(
    tester.element(
      find.descendant(of: container, matching: find.byType(Icon)),
    ),
  );

  FocusNode textOwnerNode(WidgetTester tester, Finder container) => Focus.of(
    tester.element(
      find.descendant(of: container, matching: find.byType(Text)).first,
    ),
  );

  testWidgets(
    'tab order follows visual order: amount -> notes -> date/time -> save',
    (tester) async {
      await pumpForm(tester);

      final amountNode = textFieldNode(tester, find.byType(TextField).at(0));
      final notesNode = textFieldNode(tester, find.byType(TextField).at(1));
      final dateTimeNode = iconOwnerNode(tester, find.byType(ListTile));
      final saveNode = textOwnerNode(tester, find.byType(FilledButton));

      amountNode.requestFocus();
      await tester.pump();
      expect(amountNode.hasFocus, isTrue);

      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      expect(notesNode.hasFocus, isTrue);

      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      expect(dateTimeNode.hasFocus, isTrue);

      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      expect(saveNode.hasFocus, isTrue);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'saving with an invalid amount moves focus back to the amount field',
    (tester) async {
      await pumpForm(tester);

      // Move focus elsewhere first so we can tell requestFocus() actually
      // moved it, rather than it never having left.
      final notesNode = textFieldNode(tester, find.byType(TextField).at(1))
        ..requestFocus();
      await tester.pump();
      expect(notesNode.hasFocus, isTrue);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('Amount must be greater than 0'), findsOneWidget);
      final amountNode = textFieldNode(tester, find.byType(TextField).at(0));
      expect(amountNode.hasFocus, isTrue);

      await disposeTree(tester);
    },
  );
}

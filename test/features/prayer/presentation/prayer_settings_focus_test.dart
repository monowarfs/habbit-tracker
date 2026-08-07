import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_settings_screen.dart';

/// Spec: docs/superpowers/specs/07-accessibility/
/// 10-FOCUS-ORDER-KEYBOARD-NAVIGATION-PASS-IMPLEMENTATION-PLAN.md
/// (Task 4) — tab order across the Prayer settings form's dropdowns and
/// switches must follow the visual top-to-bottom layout.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PrayerSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // `SwitchListTile` builds its own `Focus` as a descendant of itself —
  // look up from an unambiguous descendant `Text` rather than the
  // control's own element.
  FocusNode textOwnerNode(WidgetTester tester, Finder container) => Focus.of(
    tester.element(
      find.descendant(of: container, matching: find.byType(Text)).first,
    ),
  );

  // `DropdownButton` also pre-builds its (invisible) menu items inside
  // its own subtree, each wrapped in its own nested `Focus`/`ExcludeFocus`
  // — walking up from a descendant `Text` can land on one of those
  // instead of the button's own traversal-relevant node. The button's
  // own `Focus` is the outermost one in its subtree, so take it directly.
  FocusNode dropdownNode(WidgetTester tester, Finder container) => tester
      .widget<Focus>(
        find.descendant(of: container, matching: find.byType(Focus)).first,
      )
      .focusNode!;

  testWidgets(
    'default (auto-location) order: method -> asr -> jumuah -> location '
    'mode -> notifications -> pre-reminder',
    (tester) async {
      await pumpSettings(tester);

      final dropdowns = find.byWidgetPredicate((w) => w is DropdownButton);
      expect(dropdowns, findsNWidgets(3)); // method, asr, location mode

      final methodNode = dropdownNode(tester, dropdowns.at(0));
      final asrNode = dropdownNode(tester, dropdowns.at(1));
      final jumuahNode = textOwnerNode(
        tester,
        find.widgetWithText(SwitchListTile, "Observe Jumu'ah"),
      );
      final locationModeNode = dropdownNode(tester, dropdowns.at(2));
      final switchTiles = find.byType(SwitchListTile);
      // Jumu'ah is the first SwitchListTile; notifications and
      // pre-reminder are the next two, in that order.
      final notificationsNode = textOwnerNode(tester, switchTiles.at(1));
      final preReminderNode = textOwnerNode(tester, switchTiles.at(2));

      methodNode.requestFocus();
      await tester.pump();
      expect(methodNode.hasFocus, isTrue);

      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      expect(asrNode.hasFocus, isTrue);

      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      expect(jumuahNode.hasFocus, isTrue);

      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      expect(locationModeNode.hasFocus, isTrue);

      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      expect(notificationsNode.hasFocus, isTrue);

      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      expect(preReminderNode.hasFocus, isTrue);

      await disposeTree(tester);
    },
  );
}

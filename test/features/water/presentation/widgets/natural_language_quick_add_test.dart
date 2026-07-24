import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/water/presentation/widgets/natural_language_quick_add.dart';

Future<void> _pump(
  WidgetTester tester, {
  required ValueChanged<String> onLog,
  required VoidCallback onEdit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: NaturalLanguageQuickAdd(
          unit: WaterUnit.ml,
          onLog: onLog,
          onEdit: onEdit,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('empty field shows no preview', (tester) async {
    await _pump(tester, onLog: (_) {}, onEdit: () {});

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('typing text triggers a preview after the debounce', (
    tester,
  ) async {
    await _pump(tester, onLog: (_) {}, onEdit: () {});

    await tester.enterText(find.byType(TextField), '2 glasses just now');
    // Before the debounce elapses, no preview yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Card), findsNothing);

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('a high-confidence parse shows no warning text', (
    tester,
  ) async {
    await _pump(tester, onLog: (_) {}, onEdit: () {});

    await tester.enterText(find.byType(TextField), '2 glasses just now');
    await tester.pump(const Duration(milliseconds: 350));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.waterQuickAddConfidenceWarning), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('a medium-confidence parse shows the warning text', (
    tester,
  ) async {
    await _pump(tester, onLog: (_) {}, onEdit: () {});

    await tester.enterText(find.byType(TextField), '2L');
    await tester.pump(const Duration(milliseconds: 350));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.waterQuickAddConfidenceWarning), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets('unparsable text shows the "couldn\'t understand" message', (
    tester,
  ) async {
    await _pump(tester, onLog: (_) {}, onEdit: () {});

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 350));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.waterQuickAddUnparsedMessage), findsOneWidget);
  });

  testWidgets('tapping Log calls onLog with the raw text', (tester) async {
    String? logged;
    await _pump(tester, onLog: (text) => logged = text, onEdit: () {});

    await tester.enterText(find.byType(TextField), '2 glasses just now');
    await tester.pump(const Duration(milliseconds: 350));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.waterQuickAddConfirmButton));
    await tester.pump();

    expect(logged, '2 glasses just now');
  });

  testWidgets('tapping Edit calls onEdit', (tester) async {
    var editTapped = false;
    await _pump(tester, onLog: (_) {}, onEdit: () => editTapped = true);

    await tester.enterText(find.byType(TextField), '2 glasses just now');
    await tester.pump(const Duration(milliseconds: 350));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.waterQuickAddEditButton));
    await tester.pump();

    expect(editTapped, isTrue);
  });

  testWidgets('the Log button is disabled when nothing could be parsed', (
    tester,
  ) async {
    await _pump(tester, onLog: (_) {}, onEdit: () {});

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 350));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final logButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.waterQuickAddConfirmButton),
    );
    expect(logButton.onPressed, isNull);
  });

  testWidgets('clearing the field back to empty removes the preview', (
    tester,
  ) async {
    await _pump(tester, onLog: (_) {}, onEdit: () {});

    await tester.enterText(find.byType(TextField), '2 glasses just now');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(Card), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.byType(Card), findsNothing);
  });
}

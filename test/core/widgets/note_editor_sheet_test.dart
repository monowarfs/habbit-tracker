import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/widgets/note_editor_sheet.dart';

void main() {
  group('canonicalizeNote', () {
    test('trims surrounding whitespace', () {
      expect(canonicalizeNote('  felt dizzy  '), 'felt dizzy');
    });

    test('empty string canonicalizes to null', () {
      expect(canonicalizeNote(''), isNull);
    });

    test('whitespace-only string canonicalizes to null', () {
      expect(canonicalizeNote('   '), isNull);
    });
  });

  group('showNoteEditorSheet', () {
    testWidgets('typing a note and saving returns the trimmed text', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showNoteEditorSheet(
                    context,
                    initialNotes: null,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '  felt dizzy  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, 'felt dizzy');
    });

    testWidgets('clearing an existing note and saving returns null', (
      tester,
    ) async {
      String? result = 'not yet set';
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showNoteEditorSheet(
                    context,
                    initialNotes: 'old note',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('old note'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}

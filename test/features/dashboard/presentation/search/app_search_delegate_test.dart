import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/features/dashboard/presentation/search/app_search_delegate.dart';

class _SearchableModule extends Fake implements HabitModule {
  @override
  String get id => 'medicine';
  @override
  Future<List<SearchResult>> search(String query) async => query == 'para'
      ? [
          const SearchResult(
            title: 'Paracetamol',
            subtitle: '500mg',
            deepLinkRoute: '/medicine/m1',
          ),
        ]
      : [];
}

void main() {
  testWidgets('typing a query shows matching results from every module', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: AppSearchDelegate([_SearchableModule()]),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'para');
    await tester.pumpAndSettle();
    expect(find.text('Paracetamol'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/presentation/screens/data_settings_screen.dart';

void main() {
  testWidgets('renders the three list tiles with correct labels',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DataSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ListTile, l10n.dataSettingsExport),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ListTile, l10n.dataSettingsImport),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ListTile, l10n.dataSettingsShareLogs),
      findsOneWidget,
    );
  });
}

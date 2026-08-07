import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/gamification/certificate/certificate_widget.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

void main() {
  // The certificate is a fixed 1080x1080 layout — resize the test surface
  // so it lays out without overflowing the default ~800x600 test
  // viewport, same precedent as `monthly_recap_card_test.dart`.
  void resizeToCertificate(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('renders the streak length, module name and footer (en)', (
    tester,
  ) async {
    resizeToCertificate(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(
          child: CertificateWidget(
            moduleName: 'Water',
            streakDays: 30,
            date: DateTime(2026, 8, 7),
            accentColor: Colors.blue,
            l10n: l10n,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.certificateDayStreak(30)), findsOneWidget);
    expect(find.text(l10n.certificateModuleName('Water')), findsOneWidget);
    expect(find.text(l10n.certificateFooter), findsOneWidget);
    // No user name supplied — nothing extra rendered for it.
    expect(find.text(l10n.certificateTitle), findsOneWidget);
  });

  testWidgets('renders locale-aware text (bn)', (tester) async {
    resizeToCertificate(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('bn'));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(
          child: CertificateWidget(
            moduleName: 'পানি',
            streakDays: 100,
            date: DateTime(2026, 8, 7),
            accentColor: Colors.teal,
            l10n: l10n,
            userName: 'Rafi',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.certificateDayStreak(100)), findsOneWidget);
    expect(find.text(l10n.certificateModuleName('পানি')), findsOneWidget);
    expect(find.text('Rafi'), findsOneWidget);
  });
}

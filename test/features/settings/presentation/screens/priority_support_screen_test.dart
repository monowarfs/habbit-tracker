import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/features/settings/presentation/screens/priority_support_screen.dart';
import 'package:habit_tracker/features/settings/priority_support_links.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool isPremium,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [isPremiumUserProvider.overrideWithValue(isPremium)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PrioritySupportScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('premium user sees the support channel details', (
    tester,
  ) async {
    await _pump(tester, isPremium: true);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.prioritySupportThankYou), findsOneWidget);
    expect(find.text(PrioritySupportLinks.priorityEmail), findsOneWidget);
    expect(find.text(l10n.prioritySupportJoinGroup), findsOneWidget);
    expect(find.text(l10n.prioritySupportPremiumRequired), findsNothing);
  });

  testWidgets('non-premium user sees the unlock CTA instead', (tester) async {
    await _pump(tester, isPremium: false);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.prioritySupportPremiumRequired), findsOneWidget);
    expect(find.text(l10n.prioritySupportUnlockPremium), findsOneWidget);
    expect(find.text(PrioritySupportLinks.priorityEmail), findsNothing);
  });

  testWidgets('Copy Email copies the address and shows a confirmation', (
    tester,
  ) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pump(tester, isPremium: true);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.prioritySupportCopyEmail));
    await tester.pumpAndSettle();

    expect(copied, PrioritySupportLinks.priorityEmail);
    expect(find.text(l10n.prioritySupportEmailCopied), findsOneWidget);
  });
}

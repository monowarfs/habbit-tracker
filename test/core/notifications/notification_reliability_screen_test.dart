import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/analytics/effectiveness_provider.dart';
import 'package:habit_tracker/core/analytics/notification_effectiveness_use_case.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/notifications/notification_reliability_screen.dart';

class _WaterModule extends Fake implements HabitModule {
  @override
  String get id => 'water';
  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Water',
    icon: Icons.water_drop,
    accentColor: Colors.blue,
  );
}

Widget _app({
  required List<HabitModule> modules,
  required Map<String, EffectivenessResult> effectiveness,
}) {
  return ProviderScope(
    overrides: [
      habitModulesProvider.overrideWith((ref) => modules),
      notificationEffectivenessProvider.overrideWith(
        (ref) async => effectiveness,
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NotificationReliabilityScreen(),
    ),
  );
}

void main() {
  testWidgets("shows a module's effectiveness rate and description", (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        modules: [_WaterModule()],
        effectiveness: {
          'water': const EffectivenessResult(total: 10, acted: 5, rate: 0.5),
        },
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.notificationEffectivenessTitle), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text(l10n.notificationEffectivenessRate(50)), findsOneWidget);
    expect(
      find.text(l10n.notificationEffectivenessDescription(5, 10)),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows the empty state for a module with no fired reminders', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(modules: [_WaterModule()], effectiveness: const {}),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.notificationEffectivenessEmpty), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'shows the error, not the empty-state copy, when the provider errors',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitModulesProvider.overrideWith((ref) => [_WaterModule()]),
            notificationEffectivenessProvider.overrideWith(
              (ref) => Future<Map<String, EffectivenessResult>>.error(
                StateError('ledger query failed'),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationReliabilityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(
        find.text(l10n.notificationEffectivenessEmpty),
        findsNothing,
      );
      expect(find.textContaining('ledger query failed'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}

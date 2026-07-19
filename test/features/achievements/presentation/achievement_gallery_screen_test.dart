import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/features/achievements/presentation/screens/achievement_gallery_screen.dart';

class _OneAchievementModule extends Fake implements HabitModule {
  @override
  String get id => 'water';
  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Water',
    icon: Icons.water_drop,
    accentColor: Colors.blue,
  );
  @override
  List<AchievementDefinition> get achievementDefinitions => [
    AchievementDefinition(
      key: 'water_first_log',
      moduleId: 'water',
      titleKey: 'achievementWaterFirstLogTitle',
      descriptionKey: 'achievementWaterFirstLogDescription',
      target: 1,
      currentProgress: () async => 0,
    ),
  ];
}

void main() {
  testWidgets('shows one locked badge for the one achievement definition', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          habitModulesProvider.overrideWith(
            (ref) => [_OneAchievementModule()],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AchievementGalleryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.emoji_events), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await db.close();
  });
}

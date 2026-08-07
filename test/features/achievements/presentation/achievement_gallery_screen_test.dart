import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
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

/// A module contributing both a qualifying (`target >= 30` streak) and a
/// non-qualifying (`target < 30`) achievement, so the certificate
/// share/save icons' visibility can be asserted precisely
/// (`docs/superpowers/specs/06-gamification/
/// 07-milestone-certificate-image-design.md` Task 6).
class _TwoAchievementModule extends Fake implements HabitModule {
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
      key: 'water_streak_30',
      moduleId: 'water',
      titleKey: 'achievementWaterStreak30Title',
      descriptionKey: 'achievementWaterStreak30Description',
      target: 30,
      currentProgress: () async => 30,
    ),
    AchievementDefinition(
      key: 'water_streak_7',
      moduleId: 'water',
      titleKey: 'achievementWaterStreak7Title',
      descriptionKey: 'achievementWaterStreak7Description',
      target: 7,
      currentProgress: () async => 7,
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

  testWidgets(
    'offers Share/Save Certificate actions only on the unlocked 30-day '
    'streak badge, not the unlocked 7-day one',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repository = AchievementRepository(db);
      final now = DateTime(2026, 8, 7);
      await repository.upsertProgress(
        moduleId: 'water',
        key: 'water_streak_30',
        current: 30,
        target: 30,
        now: now,
      );
      await repository.upsertProgress(
        moduleId: 'water',
        key: 'water_streak_7',
        current: 7,
        target: 7,
        now: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            habitModulesProvider.overrideWith(
              (ref) => [_TwoAchievementModule()],
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

      // Both badges are unlocked (no progress bars left), but only the
      // qualifying 30-day streak gets the certificate actions.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);

      await db.close();
    },
  );
}

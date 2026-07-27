import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/theme/palette_provider.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Explicitly seed to avoid watchSingle timeout in some environments
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.into(db.appSettingsTable).insert(
      AppSettingsRow(
        id: 'singleton',
        locale: 'en',
        themeMode: 'system',
        waterUnit: 'ml',
        pinEnabled: false,
        pinLockTimeoutSeconds: 0,
        biometricEnabled: true,
        screenPrivacyEnabled: false,
        soundEnabled: false,
        ramadanAutoDetectEnabled: true,
        adaptiveReminderEnabled: false,
        quietHoursEnabled: false,
        quietHoursStart: '22:00',
        quietHoursEnd: '07:00',
        seasonalAccentsEnabled: true,
        recapEnabled: true,
        reengagementNudgeEnabled: true,
        recalibrationPromptsEnabled: true,
        driveBackupReminderEnabled: false,
        createdAt: now,
        updatedAt: now,
        activePaletteId: 'teal',
        activeIconPackId: 'default',
        lastRecapYear: 0,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('ActivePalette provider returns default teal initially', () async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );

    final palette = container.read(activePaletteProvider);
    expect(palette.id, 'teal');
  });

  test('setPalette updates the active palette', () async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );

    await container.read(activePaletteProvider.notifier).setPalette('ocean');
    
    // Read again - it should eventually update.
    // Since we are not using a StreamProvider but a regular Provider that 
    // watches a StreamProvider, it might take a tick.
    
    final palette = container.read(activePaletteProvider);
    expect(palette.id, 'ocean');
  });
}

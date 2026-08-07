import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Real app boot always seeds app_settings (via SettingsRepositoryImpl)
    // before any profile-switching UI is reachable; reproduce that here.
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.appSettingsTable)
        .insert(
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
            audioCuesEnabled: true,
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
            activePaletteId: 'teal',
            activeIconPackId: 'default',
            lastRecapYear: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  test('activeProfile defaults to the system profile', () async {
    final profile = await container.read(activeProfileProvider.future);
    expect(profile.id, 'system');
    expect(profile.displayName, 'Me');
  });

  test('invalidating activeProfile picks up a switched profile', () async {
    await container.read(activeProfileProvider.future);

    final repo = container.read(profileRepositoryProvider);
    final kid = await repo.createProfile('Kid', 'blue');
    await repo.setActiveProfile(kid.id);
    container.invalidate(activeProfileProvider);

    final profile = await container.read(activeProfileProvider.future);
    expect(profile.id, kid.id);
  });

  test('profileList reflects created profiles', () async {
    final repo = container.read(profileRepositoryProvider);
    await repo.createProfile('Kid', 'blue');
    container.invalidate(profileListProvider);

    final profiles = await container.read(profileListProvider.future);
    expect(profiles, hasLength(2));
  });
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'habit_tracker_settings_test',
    );
    dbFile = File('${tempDir.path}/test.sqlite');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('seeds defaults, persists an update, and survives reopening a fresh '
      'AppDatabase against the same file (simulated app restart)', () async {
    final db1 = AppDatabase(NativeDatabase(dbFile));
    final repo1 = SettingsRepositoryImpl(
      db1,
      defaultLocale: () => AppLocale.bn,
    );

    final firstRead = await repo1.watchSettings().first;
    expect(firstRead.locale, AppLocale.bn);
    expect(firstRead.themeMode, AppThemeMode.system);
    expect(firstRead.biometricEnabled, isTrue);
    expect(firstRead.screenPrivacyEnabled, isFalse);
    expect(firstRead.displayName, isNull);

    final updateResult = await repo1.updateThemeMode(AppThemeMode.dark);
    expect(updateResult, isA<Success<void>>());
    final biometricResult = await repo1.updateBiometricEnabled(
      enabled: false,
    );
    expect(biometricResult, isA<Success<void>>());
    final privacyResult = await repo1.updateScreenPrivacyEnabled(
      enabled: true,
    );
    expect(privacyResult, isA<Success<void>>());
    final displayNameResult = await repo1.updateDisplayName('Nadia');
    expect(displayNameResult, isA<Success<void>>());
    await db1.close();

    final db2 = AppDatabase(NativeDatabase(dbFile));
    final repo2 = SettingsRepositoryImpl(db2);
    final afterRestart = await repo2.watchSettings().first;

    expect(afterRestart.locale, AppLocale.bn);
    expect(afterRestart.themeMode, AppThemeMode.dark);
    expect(afterRestart.biometricEnabled, isFalse);
    expect(afterRestart.screenPrivacyEnabled, isTrue);
    expect(afterRestart.displayName, 'Nadia');

    await db2.close();
  });
}

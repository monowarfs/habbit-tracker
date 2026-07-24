import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/date_range.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/calculate_prayer_times.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/settings/domain/repositories/settings_repository.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/entities/water_goal.dart';
import 'package:habit_tracker/features/water/domain/entities/water_settings.dart';
import 'package:habit_tracker/features/water/domain/repositories/water_repository.dart';
import 'package:habit_tracker/features/water/water_module.dart';

class _FakeWaterRepository extends Fake implements WaterRepository {
  _FakeWaterRepository(
    this._settings, {
    List<WaterEntry>? entries,
    List<WaterGoal>? goals,
  }) : _entries = entries ?? const [],
       _goals = goals ?? const [];

  final WaterSettings _settings;
  final List<WaterEntry> _entries;
  final List<WaterGoal> _goals;
  int? capturedAmountMl;
  WaterEntrySource? capturedSource;
  bool wipeAllCalled = false;
  List<int>? capturedQuickAddAmounts;
  bool? capturedReminderEnabled;

  @override
  Stream<WaterSettings> watchSettings() => Stream.value(_settings);

  @override
  Stream<List<WaterEntry>> watchEntriesInRange(
    LocalDate start,
    LocalDate end,
  ) => Stream.value(
    _entries.where((e) {
      final day = localDayKey(e.loggedAt);
      return day.compareTo(start) >= 0 && day.compareTo(end) <= 0;
    }).toList(),
  );

  @override
  Future<List<WaterGoal>> allGoals() async => _goals;

  @override
  Future<List<WaterEntry>> allEntries() async => _entries;

  @override
  Future<Result<WaterEntry>> addEntry({
    required int amountMl,
    required DateTime loggedAt,
    required WaterEntrySource source,
    String? notes,
  }) async {
    capturedAmountMl = amountMl;
    capturedSource = source;
    return Result.success(
      WaterEntry(
        id: 'x',
        amountMl: amountMl,
        loggedAt: loggedAt,
        source: source,
      ),
    );
  }

  @override
  Future<void> wipeAll() async => wipeAllCalled = true;

  @override
  Future<Result<void>> updateQuickAddAmounts(List<int> amountsMl) async {
    capturedQuickAddAmounts = amountsMl;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateReminderSettings({
    required bool enabled,
    required int intervalMinutes,
    required LocalTime windowStart,
    required LocalTime windowEnd,
    required Map<int, ({LocalTime start, LocalTime end})> windowOverrides,
  }) async {
    capturedReminderEnabled = enabled;
    return const Result.success(null);
  }
}

class _FakePrayerRepository extends Fake implements PrayerRepository {
  _FakePrayerRepository(this._settings);
  final PrayerSettings _settings;

  @override
  Future<PrayerSettings> getSettings() async => _settings;
}

class _FakeSettingsRepository extends Fake implements SettingsRepository {
  _FakeSettingsRepository(this._settings);
  final AppSettings _settings;

  @override
  Stream<AppSettings> watchSettings() => Stream.value(_settings);
}

WaterSettings _settings({
  required bool reminderEnabled,
  List<int> quickAddAmountsMl = const [250, 500, 750],
  bool weatherNudgeEnabled = false,
  double? lastWeatherTemperatureCelsius,
  DateTime? lastWeatherFetchedAt,
}) => WaterSettings(
  quickAddAmountsMl: quickAddAmountsMl,
  reminderEnabled: reminderEnabled,
  reminderIntervalMinutes: 120,
  reminderWindowStart: const LocalTime(8, 0),
  reminderWindowEnd: const LocalTime(10, 0),
  weatherNudgeEnabled: weatherNudgeEnabled,
  lastWeatherTemperatureCelsius: lastWeatherTemperatureCelsius,
  lastWeatherFetchedAt: lastWeatherFetchedAt,
);

AppSettings _appSettings({
  bool? ramadanModeManualOverride,
  bool ramadanAutoDetectEnabled = true,
}) => AppSettings(
  locale: AppLocale.en,
  themeMode: AppThemeMode.system,
  waterUnit: WaterUnit.ml,
  pinEnabled: false,
  pinLockTimeoutSeconds: 0,
  biometricEnabled: true,
  screenPrivacyEnabled: false,
  quietHoursEnabled: false,
  quietHoursStart: const LocalTime(22, 0),
  quietHoursEnd: const LocalTime(7, 0),
  ramadanModeManualOverride: ramadanModeManualOverride,
  ramadanAutoDetectEnabled: ramadanAutoDetectEnabled,
);

const _dhakaPrayerSettings = PrayerSettings(
  id: 'singleton',
  calculationMethod: CalculationMethod.karachi,
  asrMethod: AsrMethod.hanafi,
  locationMode: LocationMode.manual,
  manualLatitude: 23.8103,
  manualLongitude: 90.4125,
  manualTimezone: 'Asia/Dhaka',
);

void main() {
  test('pendingNotifications is empty when reminders are disabled', () async {
    final module = WaterModule(
      _FakeWaterRepository(_settings(reminderEnabled: false)),
    );
    expect(await module.pendingNotifications(), isEmpty);
  });

  test(
    'pendingNotifications projects slots across multiple upcoming days, all '
    'strictly after now, none more than 3 days out',
    () async {
      final module = WaterModule(
        _FakeWaterRepository(_settings(reminderEnabled: true)),
      );
      final now = DateTime(2026, 6, 1, 9);
      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(notifications, isNotEmpty);
        final days = notifications
            .map((n) => localDayKey(n.scheduledAt))
            .toSet();
        // At least today's remaining slots plus at least one future day.
        expect(days.length, greaterThanOrEqualTo(2));
        for (final n in notifications) {
          expect(n.sourceType, 'water_reminder');
          expect(n.deepLinkRoute, '/water');
          expect(n.scheduledAt.isAfter(now), isTrue);
          expect(
            n.scheduledAt.isBefore(now.add(const Duration(days: 4))),
            isTrue,
          );
        }
      });
    },
  );

  test(
    'pendingNotifications appends the weather clause when enabled and the '
    'cached reading is fresh',
    () async {
      final now = DateTime(2026, 6, 1, 9);
      final module = WaterModule(
        _FakeWaterRepository(
          _settings(
            reminderEnabled: true,
            weatherNudgeEnabled: true,
            lastWeatherTemperatureCelsius: 34,
            lastWeatherFetchedAt: now.subtract(const Duration(hours: 1)),
          ),
        ),
      );
      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(
          notifications.first.body,
          "Keep your water goal on track. It's 34°C today.",
        );
      });
    },
  );

  test(
    'pendingNotifications omits the weather clause when the cached '
    'reading is older than the 6-hour staleness ceiling',
    () async {
      final now = DateTime(2026, 6, 1, 9);
      final module = WaterModule(
        _FakeWaterRepository(
          _settings(
            reminderEnabled: true,
            weatherNudgeEnabled: true,
            lastWeatherTemperatureCelsius: 34,
            lastWeatherFetchedAt: now.subtract(const Duration(hours: 7)),
          ),
        ),
      );
      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(notifications.first.body, 'Keep your water goal on track.');
      });
    },
  );

  test(
    'pendingNotifications omits the weather clause when weatherNudgeEnabled '
    'is false, even with a fresh cached reading',
    () async {
      final now = DateTime(2026, 6, 1, 9);
      final module = WaterModule(
        _FakeWaterRepository(
          _settings(
            reminderEnabled: true,
            lastWeatherTemperatureCelsius: 34,
            lastWeatherFetchedAt: now,
          ),
        ),
      );
      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(notifications.first.body, 'Keep your water goal on track.');
      });
    },
  );

  test(
    'onNotificationAction(done) logs a quick entry of the first quick-add '
    'amount',
    () async {
      final repo = _FakeWaterRepository(_settings(reminderEnabled: true));
      final module = WaterModule(repo);

      await module.onNotificationAction('any_id', NotificationActionType.done);

      expect(repo.capturedAmountMl, 250);
      expect(repo.capturedSource, WaterEntrySource.quick);
    },
  );

  test('onNotificationAction(snooze/skip) never logs an entry', () async {
    final repo = _FakeWaterRepository(_settings(reminderEnabled: true));
    final module = WaterModule(repo);

    await module.onNotificationAction('any_id', NotificationActionType.snooze);
    await module.onNotificationAction('any_id', NotificationActionType.skip);

    expect(repo.capturedAmountMl, isNull);
  });

  test(
    'onQuickAction logs a quick entry of the first quick-add amount',
    () async {
      final repo = _FakeWaterRepository(_settings(reminderEnabled: true));
      final module = WaterModule(repo);

      await module.onQuickAction();

      expect(repo.capturedAmountMl, 250);
      expect(repo.capturedSource, WaterEntrySource.quick);
    },
  );

  test(
    'pendingNotifications only produces slots outside that day\'s Fajr-to-'
    'Maghrib fasting window when Ramadan mode is manually forced on',
    () async {
      ensureTimeZonesInitialized();
      final waterSettings = _settings(reminderEnabled: true).copyWith(
        reminderWindowStart: const LocalTime(0, 0),
        reminderWindowEnd: const LocalTime(23, 59),
      );
      final module = WaterModule(
        _FakeWaterRepository(waterSettings),
        settingsRepository: _FakeSettingsRepository(
          _appSettings(ramadanModeManualOverride: true),
        ),
        prayerRepository: _FakePrayerRepository(_dhakaPrayerSettings),
      );

      final now = DateTime.utc(2026, 3, 15, 3);
      await withClock(Clock.fixed(now), () async {
        final notifications = await module.pendingNotifications();
        expect(notifications, isNotEmpty);

        for (final n in notifications) {
          final day = localDayKey(n.scheduledAt);
          final times = calculatePrayerTimes(
            date: day,
            latitude: _dhakaPrayerSettings.manualLatitude!,
            longitude: _dhakaPrayerSettings.manualLongitude!,
            ianaTimezone: _dhakaPrayerSettings.manualTimezone!,
            method: _dhakaPrayerSettings.calculationMethod,
            asrMethod: _dhakaPrayerSettings.asrMethod,
          );
          final fajrLocal = times.fajr.toLocal();
          final maghribLocal = times.maghrib.toLocal();
          final fajrOnDay = DateTime(
            day.year,
            day.month,
            day.day,
            fajrLocal.hour,
            fajrLocal.minute,
          );
          final maghribOnDay = DateTime(
            day.year,
            day.month,
            day.day,
            maghribLocal.hour,
            maghribLocal.minute,
          );
          final beforeFajr = n.scheduledAt.isBefore(fajrOnDay);
          final afterMaghrib = !n.scheduledAt.isBefore(maghribOnDay);
          expect(
            beforeFajr || afterMaghrib,
            isTrue,
            reason: 'slot at ${n.scheduledAt} falls inside the fast on $day '
                '(Fajr $fajrOnDay, Maghrib $maghribOnDay)',
          );
        }
      });
    },
  );

  test(
    'pendingNotifications is unchanged when the optional deps are supplied '
    'but Ramadan mode resolves to off',
    () async {
      final waterSettings = _settings(reminderEnabled: true);
      final now = DateTime(2026, 6, 1, 9);

      final baseline = WaterModule(_FakeWaterRepository(waterSettings));
      final withDeps = WaterModule(
        _FakeWaterRepository(waterSettings),
        settingsRepository: _FakeSettingsRepository(
          _appSettings(
            ramadanModeManualOverride: null,
            ramadanAutoDetectEnabled: false,
          ),
        ),
        prayerRepository: _FakePrayerRepository(_dhakaPrayerSettings),
      );

      await withClock(Clock.fixed(now), () async {
        final a = await baseline.pendingNotifications();
        final b = await withDeps.pendingNotifications();
        expect(
          b.map((n) => n.scheduledAt),
          a.map((n) => n.scheduledAt),
        );
      });
    },
  );

  test(
    'pendingNotifications falls back to the plain window when Ramadan is '
    'active but location resolution fails',
    () async {
      final waterSettings = _settings(reminderEnabled: true);
      final now = DateTime(2026, 3, 15, 9);
      const autoPrayerSettings = PrayerSettings(
        id: 'singleton',
        calculationMethod: CalculationMethod.karachi,
        asrMethod: AsrMethod.hanafi,
        locationMode: LocationMode.auto,
      );

      final baseline = WaterModule(_FakeWaterRepository(waterSettings));
      final withDeps = WaterModule(
        _FakeWaterRepository(waterSettings),
        settingsRepository: _FakeSettingsRepository(
          _appSettings(ramadanModeManualOverride: true),
        ),
        prayerRepository: _FakePrayerRepository(autoPrayerSettings),
      );

      await withClock(Clock.fixed(now), () async {
        final a = await baseline.pendingNotifications();
        final b = await withDeps.pendingNotifications();
        expect(b.map((n) => n.scheduledAt), a.map((n) => n.scheduledAt));
      });
    },
  );

  test(
    'dayStatus classifies days as complete/partial/none against the goal',
    () async {
      final goal = WaterGoal(
        id: 'g1',
        goalMl: 2000,
        effectiveFrom: DateTime.utc(2026, 6),
      );
      final module = WaterModule(
        _FakeWaterRepository(
          _settings(reminderEnabled: false),
          goals: [goal],
          entries: [
            WaterEntry(
              id: 'e1',
              amountMl: 2000,
              loggedAt: DateTime.utc(2026, 6, 1, 9),
              source: WaterEntrySource.quick,
            ),
            WaterEntry(
              id: 'e2',
              amountMl: 500,
              loggedAt: DateTime.utc(2026, 6, 2, 9),
              source: WaterEntrySource.quick,
            ),
          ],
        ),
      );
      final status = await module.dayStatus(
        const DateRange(
          start: LocalDate(2026, 6, 1),
          end: LocalDate(2026, 6, 3),
        ),
      );
      expect(
        status[const LocalDate(2026, 6, 1)]!.kind,
        ModuleDayStatusKind.complete,
      );
      expect(
        status[const LocalDate(2026, 6, 2)]!.kind,
        ModuleDayStatusKind.partial,
      );
      expect(
        status[const LocalDate(2026, 6, 3)]!.kind,
        ModuleDayStatusKind.none,
      );
      expect(status[const LocalDate(2026, 6, 1)]!.value, 2000);
    },
  );

  test('search always returns empty (Water has no named entities)', () async {
    final module = WaterModule(
      _FakeWaterRepository(_settings(reminderEnabled: false)),
    );
    expect(await module.search('anything'), isEmpty);
  });

  test(
    'achievementDefinitions: water_first_log progress is 0 with no entries, '
    '1 with one',
    () async {
      final empty = WaterModule(
        _FakeWaterRepository(_settings(reminderEnabled: false)),
      );
      final firstLogEmpty = empty.achievementDefinitions.firstWhere(
        (d) => d.key == 'water_first_log',
      );
      expect(await firstLogEmpty.currentProgress(), 0);

      final withEntry = WaterModule(
        _FakeWaterRepository(
          _settings(reminderEnabled: false),
          entries: [
            WaterEntry(
              id: 'e1',
              amountMl: 100,
              loggedAt: DateTime.utc(2026, 6),
              source: WaterEntrySource.quick,
            ),
          ],
        ),
      );
      final firstLog = withEntry.achievementDefinitions.firstWhere(
        (d) => d.key == 'water_first_log',
      );
      expect(await firstLog.currentProgress(), 1);
    },
  );

  test('exportData includes the settings block', () async {
    final repo = _FakeWaterRepository(
      _settings(reminderEnabled: true, quickAddAmountsMl: const [111]),
    );
    final module = WaterModule(repo);
    final export = await module.exportData();
    final settings = export.payload['settings']! as Map<String, Object?>;
    expect(settings['quickAddAmountsMl'], [111]);
    expect(settings['reminderEnabled'], true);
  });

  test('importData restores the settings block', () async {
    final repo = _FakeWaterRepository(_settings(reminderEnabled: false));
    final module = WaterModule(repo);
    await module.importData(
      const ModuleExport({
        'goals': <Object?>[],
        'logs': <Object?>[],
        'settings': {
          'quickAddAmountsMl': [300, 600],
          'reminderEnabled': true,
          'reminderIntervalMinutes': 90,
          'reminderWindowStart': '07:00',
          'reminderWindowEnd': '21:00',
        },
      }),
    );
    expect(repo.capturedQuickAddAmounts, [300, 600]);
    expect(repo.capturedReminderEnabled, true);
  });

  test('wipeData delegates to the repository', () async {
    final repo = _FakeWaterRepository(_settings(reminderEnabled: false));
    await WaterModule(repo).wipeData();
    expect(repo.wipeAllCalled, isTrue);
  });
}

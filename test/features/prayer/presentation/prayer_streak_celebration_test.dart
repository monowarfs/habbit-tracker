import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_home_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets(
    'marking the last prayer of a 7-day streak prayed shows the streak '
    'celebration before the achievement snackbar',
    (tester) async {
      final repo = PrayerRepositoryImpl(db);

      // `prayer_first_log`/`prayer_perfect_week` would otherwise unlock
      // in the very same diff as `prayer_streak_7` — pre-seed both as
      // already-unlocked so the test's own diff isolates the streak
      // achievement.
      final achievementRepo = AchievementRepository(db);
      await achievementRepo.upsertProgress(
        moduleId: 'prayer',
        key: 'prayer_first_log',
        current: 1,
        target: 1,
        now: DateTime.utc(2026, 5, 26),
        profileId: 'system',
      );
      await achievementRepo.upsertProgress(
        moduleId: 'prayer',
        key: 'prayer_perfect_week',
        current: 1,
        target: 1,
        now: DateTime.utc(2026, 5, 26),
        profileId: 'system',
      );

      const today = LocalDate(2026, 6, 7);
      // 6 prior fully-prayed days.
      for (var i = 1; i <= 6; i++) {
        final day = today.addDays(-i);
        for (final name in PrayerName.values) {
          await repo.restoreRecord(
            PrayerRecord(
              id: '',
              prayerDate: day,
              prayerName: name,
              scheduledFor: DateTime.utc(day.year, day.month, day.day, 6),
              storedStatus: PrayerStatus.prayed,
              statusChangedAt: DateTime.utc(
                day.year,
                day.month,
                day.day,
                6,
                5,
              ),
            ),
            profileId: 'system',
          );
        }
      }

      // Today: Fajr/Asr/Maghrib/Isha already prayed, Dhuhr still
      // upcoming.
      await repo.restoreRecord(
        PrayerRecord(
          id: '',
          prayerDate: today,
          prayerName: PrayerName.fajr,
          scheduledFor: DateTime.utc(2026, 6, 7, 5),
          storedStatus: PrayerStatus.prayed,
          statusChangedAt: DateTime.utc(2026, 6, 7, 5, 5),
        ),
        profileId: 'system',
      );
      await repo.restoreRecord(
        PrayerRecord(
          id: '',
          prayerDate: today,
          prayerName: PrayerName.dhuhr,
          scheduledFor: DateTime.utc(2026, 6, 7, 12),
          storedStatus: PrayerStatus.upcoming,
        ),
        profileId: 'system',
      );
      await repo.restoreRecord(
        PrayerRecord(
          id: '',
          prayerDate: today,
          prayerName: PrayerName.asr,
          scheduledFor: DateTime.utc(2026, 6, 7, 15, 30),
          storedStatus: PrayerStatus.prayed,
          statusChangedAt: DateTime.utc(2026, 6, 7, 15, 35),
        ),
        profileId: 'system',
      );
      await repo.restoreRecord(
        PrayerRecord(
          id: '',
          prayerDate: today,
          prayerName: PrayerName.maghrib,
          scheduledFor: DateTime.utc(2026, 6, 7, 18),
          storedStatus: PrayerStatus.prayed,
          statusChangedAt: DateTime.utc(2026, 6, 7, 18, 5),
        ),
        profileId: 'system',
      );
      await repo.restoreRecord(
        PrayerRecord(
          id: '',
          prayerDate: today,
          prayerName: PrayerName.isha,
          scheduledFor: DateTime.utc(2026, 6, 7, 19, 30),
          storedStatus: PrayerStatus.prayed,
          statusChangedAt: DateTime.utc(2026, 6, 7, 19, 35),
        ),
        profileId: 'system',
      );

      await withClock(Clock.fixed(DateTime.utc(2026, 6, 7, 13)), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PrayerHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Dhuhr is the only not-yet-prayed record — its
        // `radio_button_unchecked` icon is unique in the tree.
        await tester.tap(find.byIcon(Icons.radio_button_unchecked));
        await tester.pump();

        // The celebration overlay appears first.
        expect(find.text('Consistent Worship'), findsOneWidget);
        expect(
          find.text('Achievement unlocked: Consistent Worship'),
          findsNothing,
        );

        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pumpAndSettle();

        expect(
          find.text('Achievement unlocked: Consistent Worship'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      });
    },
  );
}

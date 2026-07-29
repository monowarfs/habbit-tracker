import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_stats_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrayerRepository extends Mock implements PrayerRepository {}

void main() {
  late _MockPrayerRepository repo;

  setUpAll(() {
    ensureTimeZonesInitialized();
    registerFallbackValue(const LocalDate(2026, 1, 1));
  });

  setUp(() {
    repo = _MockPrayerRepository();
  });

  Widget buildApp() => ProviderScope(
    overrides: [prayerRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        extensions: const [
          AppSemanticColors.light,
          ModuleThemeAccents.defaults,
        ],
      ),
      home: const PrayerStatsScreen(),
    ),
  );

  PrayerRecord record({
    required PrayerName name,
    required PrayerStatus status,
    DateTime? statusChangedAt,
  }) => PrayerRecord(
    id: '${name.name}_${status.name}_${statusChangedAt ?? ''}',
    prayerDate: const LocalDate(2026, 6, 1),
    prayerName: name,
    scheduledFor: DateTime.utc(2026, 6, 1, 8),
    storedStatus: status,
    statusChangedAt: statusChangedAt,
  );

  testWidgets(
    'shows the on-time/late/missed split computed from the fetched records',
    (tester) async {
      when(
        () => repo.watchQadhaCounters(),
      ).thenAnswer((_) => Stream.value(const []));
      when(() => repo.recordsInRange(any(), any())).thenAnswer(
        (_) async => [
          record(
            name: PrayerName.fajr,
            status: PrayerStatus.prayed,
            statusChangedAt: DateTime.utc(2026, 6, 1, 8, 5),
          ),
          record(
            name: PrayerName.dhuhr,
            status: PrayerStatus.prayed,
            statusChangedAt: DateTime.utc(2026, 6, 1, 9),
          ),
          record(name: PrayerName.asr, status: PrayerStatus.missed),
          record(name: PrayerName.maghrib, status: PrayerStatus.missed),
        ],
      );

      // Tall surface so every ListView row (there are many, past the
      // default test viewport) is within the sliver's build/cache extent.
      tester.view.physicalSize = const Size(400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 12)), () async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();
      });

      expect(find.text('Completion breakdown, last 30 days'), findsOneWidget);
      expect(find.text('On Time: 1 (25%)'), findsOneWidget);
      expect(find.text('Late but Completed: 1 (25%)'), findsOneWidget);
      expect(find.text('Missed: 2 (50%)'), findsOneWidget);
      expect(find.text('On-time rate: 25%'), findsOneWidget);
    },
  );
}

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_home_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrayerRepository extends Mock implements PrayerRepository {}

void main() {
  late _MockPrayerRepository repo;

  setUpAll(() {
    ensureTimeZonesInitialized();
    registerFallbackValue(const LocalDate(2026, 1, 1));
  });

  const settings = PrayerSettings(
    id: 'singleton',
    calculationMethod: CalculationMethod.karachi,
    asrMethod: AsrMethod.hanafi,
    locationMode: LocationMode.manual,
    manualLatitude: 23.8103,
    manualLongitude: 90.4125,
    manualTimezone: 'Asia/Dhaka',
  );

  setUp(() {
    repo = _MockPrayerRepository();
  });

  Widget buildApp() => ProviderScope(
    overrides: [prayerRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: ThemeData(
        extensions: const [AppSemanticColors.light],
      ),
      home: const PrayerHomeScreen(),
    ),
  );

  testWidgets('shows the empty state when there are no records today', (
    tester,
  ) async {
    when(
      () => repo.watchRecordsForDay(any()),
    ).thenAnswer((_) => Stream.value(const []));
    when(() => repo.watchSettings()).thenAnswer((_) => Stream.value(settings));

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 6)), () async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
    });

    expect(find.text('No prayers scheduled for today'), findsOneWidget);
  });

  testWidgets('shows a tile per record, labeled by prayer name', (
    tester,
  ) async {
    final records = [
      PrayerRecord(
        id: 'r1',
        prayerDate: const LocalDate(2026, 6, 1),
        prayerName: PrayerName.fajr,
        scheduledFor: DateTime.utc(2026, 6, 1, 0),
        storedStatus: PrayerStatus.upcoming,
      ),
    ];
    when(
      () => repo.watchRecordsForDay(any()),
    ).thenAnswer((_) => Stream.value(records));
    when(() => repo.watchSettings()).thenAnswer((_) => Stream.value(settings));

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 1)), () async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
    });

    expect(find.text('Fajr'), findsOneWidget);
  });
}

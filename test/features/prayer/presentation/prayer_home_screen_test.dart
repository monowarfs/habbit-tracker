import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/widgets/illustrations/crescent_mat_painter.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';
import 'package:habit_tracker/features/prayer/presentation/screens/prayer_home_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrayerRepository extends Mock implements PrayerRepository {}

void main() {
  late _MockPrayerRepository repo;
  late AppDatabase db;

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
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget buildApp() => ProviderScope(
    overrides: [
      prayerRepositoryProvider.overrideWithValue(repo),
      databaseProvider.overrideWithValue(db),
    ],
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
      home: const PrayerHomeScreen(),
    ),
  );

  testWidgets('shows the empty state when there are no records today', (
    tester,
  ) async {
    when(
      () => repo.watchRecordsForDay(any(), profileId: any(named: 'profileId')),
    ).thenAnswer((_) => Stream.value(const []));
    when(
      () => repo.watchSettings(profileId: any(named: 'profileId')),
    ).thenAnswer((_) => Stream.value(settings));

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 6)), () async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
    });

    expect(find.text('No prayers scheduled for today'), findsOneWidget);
  });

  testWidgets(
    "empty state's illustration is painted in Prayer's own accent color",
    (tester) async {
      when(
        () => repo.watchRecordsForDay(
          any(),
          profileId: any(named: 'profileId'),
        ),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => repo.watchSettings(profileId: any(named: 'profileId')),
      ).thenAnswer((_) => Stream.value(settings));

      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 6)), () async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();
      });

      final customPaint = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .firstWhere((w) => w.painter is CrescentMatPainter);
      final painter = customPaint.painter! as CrescentMatPainter;
      expect(painter.color, ModuleThemeAccents.defaults.prayer);
    },
  );

  testWidgets('shows a tile per record, labeled by prayer name', (
    tester,
  ) async {
    final records = [
      PrayerRecord(
        id: 'r1',
        prayerDate: const LocalDate(2026, 6, 1),
        prayerName: PrayerName.fajr,
        scheduledFor: DateTime.utc(2026, 6),
        storedStatus: PrayerStatus.upcoming,
      ),
    ];
    when(
      () => repo.watchRecordsForDay(any(), profileId: any(named: 'profileId')),
    ).thenAnswer((_) => Stream.value(records));
    when(
      () => repo.watchSettings(profileId: any(named: 'profileId')),
    ).thenAnswer((_) => Stream.value(settings));

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 1)), () async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
    });

    expect(find.text('Fajr'), findsOneWidget);
  });

  testWidgets(
    'a11y: the mark-prayed toggle icon button has a screen-reader label '
    '(TalkBack/VoiceOver audit — this button was previously unlabeled)',
    (tester) async {
      final records = [
        PrayerRecord(
          id: 'r1',
          prayerDate: const LocalDate(2026, 6, 1),
          prayerName: PrayerName.fajr,
          scheduledFor: DateTime.utc(2026, 6),
          storedStatus: PrayerStatus.upcoming,
        ),
      ];
      when(
        () => repo.watchRecordsForDay(
          any(),
          profileId: any(named: 'profileId'),
        ),
      ).thenAnswer((_) => Stream.value(records));
      when(
        () => repo.watchSettings(profileId: any(named: 'profileId')),
      ).thenAnswer((_) => Stream.value(settings));

      await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 1)), () async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();
      });

      final toggle = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.radio_button_unchecked),
          matching: find.byType(IconButton),
        ),
      );
      expect(toggle.tooltip, isNotNull);
      expect(toggle.tooltip, isNotEmpty);
    },
  );
}

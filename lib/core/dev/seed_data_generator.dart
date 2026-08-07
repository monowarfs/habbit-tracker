import 'dart:math';

import 'package:clock/clock.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/expand_repeat_rule.dart';
import 'package:habit_tracker/features/prayer/data/location_resolver.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_record.dart';
import 'package:habit_tracker/features/prayer/domain/entities/resolved_location.dart';
import 'package:habit_tracker/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:habit_tracker/features/prayer/domain/usecases/plan_prayer_materialization.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/domain/repositories/water_repository.dart';

/// Splits [totalDays] into alternating good/bad streaks (~80% good, runs
/// of 4-14 days; bad runs of 1-4 days) instead of an independent per-day
/// coin flip, so seeded history reads as real clumped usage (good
/// weeks/bad weeks) rather than uniform noise.
List<bool> generateAdherencePattern(int totalDays, Random random) {
  if (totalDays <= 0) return [];
  final pattern = <bool>[];
  while (pattern.length < totalDays) {
    final isGood = random.nextDouble() < 0.8;
    final runLength = isGood ? 4 + random.nextInt(11) : 1 + random.nextInt(4);
    pattern.addAll(List.filled(runLength, isGood));
  }
  return pattern.sublist(0, totalDays);
}

int _daysBetween(LocalDate a, LocalDate b) =>
    b.toDateTimeUtc().difference(a.toDateTimeUtc()).inDays;

/// Wipes Water/Medicine/Prayer data and backfills 1 month-2 years of
/// randomized, streak-clumped history so Reports/stats/achievements
/// screens have real-looking data to render. Debug-mode dev tool only —
/// callers gate the UI entry point behind `kDebugMode`.
Future<void> generateSeedData({
  required WaterRepository waterRepository,
  required MedicineRepository medicineRepository,
  required PrayerRepository prayerRepository,
}) async {
  final random = Random();
  final now = clock.now();
  final today = LocalDate.fromDateTime(now);
  final totalDays = 30 + random.nextInt(701);
  final startDate = today.addDays(-totalDays);
  final pattern = generateAdherencePattern(totalDays + 1, random);

  await waterRepository.wipeAll(profileId: 'system');
  await medicineRepository.wipeAll(profileId: 'system');
  await prayerRepository.wipeAll(profileId: 'system');

  await _seedWater(waterRepository, startDate, totalDays, now, pattern, random);
  await _seedMedicine(
    medicineRepository,
    startDate,
    today,
    now,
    pattern,
    random,
  );
  await _seedPrayer(prayerRepository, startDate, today, now, pattern, random);
}

Future<void> _seedWater(
  WaterRepository repository,
  LocalDate startDate,
  int totalDays,
  DateTime now,
  List<bool> pattern,
  Random random,
) async {
  final goalMl = 2000 + random.nextInt(1001);
  await repository.setGoal(
    goalMl,
    effectiveFrom: startDate.toDateTimeUtc(),
    profileId: 'system',
  );

  for (var i = 0; i <= totalDays; i++) {
    final day = startDate.addDays(i);
    final isGood = pattern[i];
    final entryCount = isGood ? 3 + random.nextInt(4) : random.nextInt(3);
    for (var j = 0; j < entryCount; j++) {
      final loggedAt = DateTime(
        day.year,
        day.month,
        day.day,
        6 + random.nextInt(16),
        random.nextInt(60),
      );
      if (loggedAt.isAfter(now)) continue;
      final amountMl = isGood
          ? 200 + random.nextInt(300)
          : 100 + random.nextInt(150);
      await repository.addEntry(
        amountMl: amountMl,
        loggedAt: loggedAt,
        source: WaterEntrySource.quick,
        profileId: 'system',
      );
    }
  }
}

const _medicineNames = [
  'Vitamin D',
  'Multivitamin',
  'Blood Pressure Med',
  'Omega-3',
];

Future<void> _seedMedicine(
  MedicineRepository repository,
  LocalDate startDate,
  LocalDate today,
  DateTime now,
  List<bool> pattern,
  Random random,
) async {
  final medicineCount = 1 + random.nextInt(2);
  final names = (List.of(_medicineNames)..shuffle(random)).take(medicineCount);
  for (final name in names) {
    final medicineResult = await repository.createMedicine(
      name: name,
      stockEnabled: true,
      stockCount: 60 + random.nextInt(90),
      stockThreshold: 10,
      profileId: 'system',
    );
    if (medicineResult is! Success<Medicine>) continue;
    final medicine = medicineResult.value;

    final timesOfDay = random.nextBool()
        ? [const LocalTime(8, 0)]
        : [const LocalTime(8, 0), const LocalTime(20, 0)];
    final scheduleResult = await repository.createSchedule(
      medicineId: medicine.id,
      rule: RepeatRule.fixedDaily(timesOfDay: timesOfDay),
      startDate: startDate,
      profileId: 'system',
    );
    if (scheduleResult is! Success<MedicineSchedule>) continue;
    final schedule = scheduleResult.value;

    final instants = expandRepeatRule(
      rule: schedule.rule,
      anchor: startDate,
      rangeStart: startDate,
      rangeEnd: today,
    );
    for (final instant in instants) {
      if (!instant.isBefore(now)) continue;
      final dayIndex = _daysBetween(startDate, LocalDate.fromDateTime(instant));
      final isGood = pattern[dayIndex];
      final roll = random.nextDouble();
      final MedicineDoseStatus status;
      DateTime? statusChangedAt;
      if (roll < (isGood ? 0.85 : 0.30)) {
        status = MedicineDoseStatus.done;
        statusChangedAt = instant.add(Duration(minutes: random.nextInt(45)));
      } else if (roll < (isGood ? 0.93 : 0.40)) {
        status = MedicineDoseStatus.skipped;
        statusChangedAt = instant.add(Duration(minutes: random.nextInt(120)));
      } else {
        status = MedicineDoseStatus.upcoming;
      }
      await repository.restoreDose(
        MedicineDose(
          id: '',
          medicineId: medicine.id,
          scheduleId: schedule.id,
          scheduledFor: instant,
          storedStatus: status,
          graceWindowMinutes: schedule.graceWindowMinutes,
          statusChangedAt: statusChangedAt,
        ),
        profileId: 'system',
      );
    }
  }
}

Future<void> _seedPrayer(
  PrayerRepository repository,
  LocalDate startDate,
  LocalDate today,
  DateTime now,
  List<bool> pattern,
  Random random,
) async {
  final settings = await repository.getSettings(profileId: 'system');
  final locationResult = await resolveLocation(settings);
  if (locationResult is! Success<ResolvedLocation>) return;
  final location = locationResult.value;

  final planned = planPrayerMaterialization(
    settings: settings,
    location: location,
    existingRecords: const [],
    windowStart: startDate,
    windowEnd: today,
  );

  final missedCounts = {for (final name in PrayerName.values) name: 0};
  for (final slot in planned) {
    if (!slot.scheduledFor.isBefore(now)) continue;
    final dayIndex = _daysBetween(startDate, slot.prayerDate);
    final isGood = pattern[dayIndex];
    final roll = random.nextDouble();
    final PrayerStatus status;
    DateTime? statusChangedAt;
    if (roll < (isGood ? 0.80 : 0.25)) {
      status = PrayerStatus.prayed;
      statusChangedAt = slot.scheduledFor.add(
        Duration(minutes: 1 + random.nextInt(14)),
      );
    } else if (roll < (isGood ? 0.93 : 0.35)) {
      status = PrayerStatus.prayed;
      statusChangedAt = slot.scheduledFor.add(
        Duration(minutes: 20 + random.nextInt(150)),
      );
    } else {
      status = PrayerStatus.missed;
      missedCounts[slot.prayerName] = missedCounts[slot.prayerName]! + 1;
    }
    await repository.restoreRecord(
      PrayerRecord(
        id: '',
        prayerDate: slot.prayerDate,
        prayerName: slot.prayerName,
        scheduledFor: slot.scheduledFor,
        storedStatus: status,
        statusChangedAt: statusChangedAt,
      ),
      profileId: 'system',
    );
  }

  for (final entry in missedCounts.entries) {
    await repository.setQadhaBalance(
      entry.key,
      entry.value,
      profileId: 'system',
    );
  }
}

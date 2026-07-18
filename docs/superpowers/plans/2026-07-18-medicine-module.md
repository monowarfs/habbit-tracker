# Medicine Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the complete Medicine module — domain, data, presentation, and
notifications — matching FR-M-01..10, D-02/03/04/05/13/14, and the
`medicines`/`medicine_schedules`/`medicine_doses`/`medicine_stock_events`
schema, registered as a full `HabitModule`.

**Architecture:** Clean Architecture slice mirroring `lib/features/water/`
exactly (see `docs/superpowers/specs/2026-07-18-medicine-module-design.md`).
Pure domain functions for the two riskiest pieces of logic (repeat-rule
expansion, dose-status derivation) with zero DB/Flutter dependency; a single
no-DAO repository; dose rows materialized into a 30-day rolling window by
the same two triggers `core/notifications` already uses (app-resume,
WorkManager top-up) via `MedicineModule.pendingNotifications()` itself —
no new call sites in `main.dart`/`notification_workmanager.dart`.

**Tech Stack:** Flutter, Riverpod (codegen), Drift, Freezed, `clock`,
`fl_chart` (existing `PeriodBarChart`), `mocktail` (existing dev dep) — no
new dependencies.

## Global Constraints

- Repeat types are exactly `fixed_daily`, `every_n_days`, `weekday_set`,
  `prn` — no monthly/specific-dates patterns (resolved scope decision, see
  design spec).
- Every domain unit reasoning about "now"/"today" takes time as an
  injected parameter or reads `clock.now()` — never `DateTime.now()`
  directly (`docs/strategies/testing.md`'s mandatory rule).
- Every repository mutation returns `Result<T>` (`core/error/result.dart`)
  and wraps its body in `try`/`on Object catch (e) => Result.failure(
  AppException.storage(...))`, matching `WaterRepositoryImpl` exactly.
- Soft-delete: every table has `deleted_at`; every read filters
  `deletedAt.isNull()`.
- All ids via `generateId()` (`core/utils/uuid.dart`, UUID v7). All stored
  instants are UTC epoch millis; recurring wall-clock times/dates are
  local strings (`"HH:mm"`/`"YYYY-MM-DD"`) per D-14.
- Lint: `public_member_api_docs` is enforced — every public class/member
  needs a `///` doc comment (see any existing Water file for the style).
- Run `dart run build_runner build --delete-conflicting-outputs` after
  creating/editing any `@freezed` or `@riverpod` file, before running
  tests that import its generated `.g.dart`/`.freezed.dart`.
- Commands: `flutter test <file>`, `flutter analyze`,
  `dart format --output=none --set-exit-if-changed .`.

## Two implementation-level refinements over the design spec (both stay inside its intent)

1. **Grace window is denormalized onto `MedicineDose`** (captured from the
   winning schedule at materialization time) rather than looked up via
   `scheduleId` on every read. Avoids a join on the hottest read path
   (today's dose list, adherence calc) — same denormalization reasoning
   `database-design.md` already documents for `medicine_doses.medicine_id`.
2. **Dose materialization is a pure gap-filler**: it only ever inserts
   rows for slots with no existing dose row; it never rewrites an
   already-materialized row. Editing a schedule's future doses (FR-M-09)
   is handled explicitly by `updateSchedule` (Task 9), which deletes that
   schedule's still-`upcoming` doses at/after "now" so the next
   materialization pass regenerates them from the new rule — materialized
   `done`/`skipped`/past rows are never touched by either path.

---

### Task 1: Domain entities

**Files:**
- Create: `lib/features/medicine/domain/entities/repeat_rule.dart`
- Create: `lib/features/medicine/domain/entities/medicine.dart`
- Create: `lib/features/medicine/domain/entities/medicine_schedule.dart`
- Create: `lib/features/medicine/domain/entities/medicine_dose.dart`
- Create: `lib/features/medicine/domain/entities/medicine_stock_event.dart`

**Interfaces:**
- Produces: `RepeatRule` (sealed: `RepeatRule.fixedDaily`,
  `.everyNDays`, `.weekdaySet`, `.prn`), `Medicine`, `MedicineSchedule`,
  `MedicineDose`, `MedicineDoseStatus`, `MedicineStockEvent`,
  `MedicineStockEventReason` — used by every later task.

- [ ] **Step 1: Write `repeat_rule.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

part 'repeat_rule.freezed.dart';

/// A medicine schedule's recurrence pattern (FR-M-03, D-03). Exactly the
/// four patterns the committed schema's `frequency_type` enum supports —
/// monthly/specific-dates patterns are out of scope this run (no schema
/// storage, no decision doc covering their edge cases).
@freezed
sealed class RepeatRule with _$RepeatRule {
  /// Fixed times every day.
  const factory RepeatRule.fixedDaily({required List<LocalTime> timesOfDay}) =
      FixedDailyRule;

  /// Every [intervalDays] days, anchored to the schedule's `startDate`
  /// (D-03) — `intervalDays: 2` is "every other day."
  const factory RepeatRule.everyNDays({
    required int intervalDays,
    required List<LocalTime> timesOfDay,
  }) = EveryNDaysRule;

  /// Specific weekdays, e.g. Mon/Wed/Fri.
  const factory RepeatRule.weekdaySet({
    required int weekdaysMask,
    required List<LocalTime> timesOfDay,
  }) = WeekdaySetRule;

  /// As-needed — no scheduled instances (FR-M-03).
  const factory RepeatRule.prn() = PrnRule;
}
```

- [ ] **Step 2: Write `medicine.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'medicine.freezed.dart';

/// A medicine record (FR-M-01/04/05/10).
@freezed
sealed class Medicine with _$Medicine {
  /// Creates a medicine.
  const factory Medicine({
    required String id,
    required String name,
    String? dosageNote,
    required bool stockEnabled,
    int? stockCount,
    int? stockThreshold,
    @Default(false) bool stopWhenStockDepleted,
    @Default(1) int consumptionPerDose,

    /// Set the moment stock crosses at/below [stockThreshold] from above
    /// it; cleared once a refill brings it back above threshold — makes
    /// the low-stock notification fire exactly once per crossing
    /// (FR-M-04).
    DateTime? lowStockNotifiedAt,
    DateTime? archivedAt,
  }) = _Medicine;
}
```

- [ ] **Step 3: Write `medicine_schedule.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';

part 'medicine_schedule.freezed.dart';

/// One of a medicine's (possibly several, D-02) active schedules.
@freezed
sealed class MedicineSchedule with _$MedicineSchedule {
  /// Creates a schedule.
  const factory MedicineSchedule({
    required String id,
    required String medicineId,
    required RepeatRule rule,
    required LocalDate startDate,
    LocalDate? endDate,
    @Default(30) int graceWindowMinutes,

    /// Breaks same-slot collisions between two schedules of the same
    /// medicine (D-02: most-recently-created wins).
    required DateTime createdAt,
  }) = _MedicineSchedule;
}
```

- [ ] **Step 4: Write `medicine_dose.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'medicine_dose.freezed.dart';

/// A materialized dose instance (D-13). [storedStatus] is only ever
/// `upcoming`, `done`, or `skipped` — `due`/`missed` are never persisted,
/// they're derived at read time by `effective_dose_status.dart` (FR-M-06,
/// "evaluated lazily, no background job").
enum MedicineDoseStatus {
  /// Not yet due, and not yet acted on.
  upcoming,

  /// Past `scheduledFor`, within the grace window — derived only.
  due,

  /// Marked taken.
  done,

  /// Past the grace window, never acted on — derived only.
  missed,

  /// Explicitly dismissed.
  skipped,
}

/// A single concrete dose instance (`technical/database-design.md`).
@freezed
sealed class MedicineDose with _$MedicineDose {
  /// Creates a dose.
  const factory MedicineDose({
    required String id,
    required String medicineId,
    required String scheduleId,
    required DateTime scheduledFor,
    required MedicineDoseStatus storedStatus,
    DateTime? statusChangedAt,
    @Default(0) int stockDeltaApplied,

    /// Denormalized from the generating schedule at materialization time
    /// (implementation refinement over the design spec — avoids a join
    /// on the hottest read path).
    required int graceWindowMinutes,
  }) = _MedicineDose;
}
```

- [ ] **Step 5: Write `medicine_stock_event.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'medicine_stock_event.freezed.dart';

/// Why a [MedicineStockEvent] happened.
enum MedicineStockEventReason {
  /// A dose was marked done and stock was decremented.
  doseTaken,

  /// User manually added stock.
  manualRefill,

  /// User manually corrected the count.
  manualAdjustment,

  /// A previously-done dose was un-marked, reversing its decrement.
  doseUndone,
}

/// One append-only stock ledger row (`technical/database-design.md`).
@freezed
sealed class MedicineStockEvent with _$MedicineStockEvent {
  /// Creates a stock event.
  const factory MedicineStockEvent({
    required String id,
    required String medicineId,
    String? doseId,
    required int delta,
    required MedicineStockEventReason reason,
    required DateTime occurredAt,
  }) = _MedicineStockEvent;
}
```

- [ ] **Step 6: Generate freezed code and verify it compiles**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 5 new `*.freezed.dart` files generated, no errors.

Run: `flutter analyze lib/features/medicine/domain/entities/`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/medicine/domain/entities/
git commit -m "feat(medicine): add domain entities"
```

---

### Task 2: `expandRepeatRule` — fixedDaily/weekdaySet/prn

**Files:**
- Create: `lib/features/medicine/domain/usecases/expand_repeat_rule.dart`
- Test: `test/features/medicine/domain/expand_repeat_rule_test.dart`

**Interfaces:**
- Consumes: `RepeatRule`, `FixedDailyRule`, `EveryNDaysRule`,
  `WeekdaySetRule`, `PrnRule` (Task 1), `LocalDate`/`LocalTime`
  (`core/utils/local_date.dart`).
- Produces: `List<DateTime> expandRepeatRule({required RepeatRule rule,
  required LocalDate anchor, required LocalDate rangeStart, required
  LocalDate rangeEnd})` — pure, UTC instants, used by Task 3 (every-N-days
  tests), Task 6 (materialization planner), and the detail screen's 7-day
  preview (Task 17).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/expand_repeat_rule.dart';

void main() {
  group('fixedDaily', () {
    test('generates both times every day in range', () {
      final result = expandRepeatRule(
        rule: const RepeatRule.fixedDaily(
          timesOfDay: [LocalTime(8, 0), LocalTime(20, 0)],
        ),
        anchor: const LocalDate(2026, 6, 1),
        rangeStart: const LocalDate(2026, 6, 1),
        rangeEnd: const LocalDate(2026, 6, 3),
      );
      expect(result, hasLength(6)); // 3 days x 2 times
      expect(
        result.first,
        DateTime(2026, 6, 1, 8, 0).toUtc(),
      );
      expect(
        result.last,
        DateTime(2026, 6, 3, 20, 0).toUtc(),
      );
    });

    test('never generates before the anchor', () {
      final result = expandRepeatRule(
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        anchor: const LocalDate(2026, 6, 5),
        rangeStart: const LocalDate(2026, 6, 1),
        rangeEnd: const LocalDate(2026, 6, 5),
      );
      expect(result, hasLength(1));
      expect(result.single, DateTime(2026, 6, 5, 8, 0).toUtc());
    });
  });

  group('weekdaySet', () {
    test('only generates on masked weekdays', () {
      // Mon=1, Wed=4 -> mask 1|4=5. 2026-06-01 is a Monday.
      final result = expandRepeatRule(
        rule: const RepeatRule.weekdaySet(
          weekdaysMask: 5,
          timesOfDay: [LocalTime(9, 0)],
        ),
        anchor: const LocalDate(2026, 6, 1),
        rangeStart: const LocalDate(2026, 6, 1),
        rangeEnd: const LocalDate(2026, 6, 7),
      );
      // Mon 6/1 and Wed 6/3 only.
      expect(result, hasLength(2));
      expect(result[0], DateTime(2026, 6, 1, 9, 0).toUtc());
      expect(result[1], DateTime(2026, 6, 3, 9, 0).toUtc());
    });
  });

  group('prn', () {
    test('never generates any instance', () {
      final result = expandRepeatRule(
        rule: const RepeatRule.prn(),
        anchor: const LocalDate(2026, 6, 1),
        rangeStart: const LocalDate(2026, 6, 1),
        rangeEnd: const LocalDate(2026, 6, 30),
      );
      expect(result, isEmpty);
    });
  });

  test('rangeEnd before rangeStart returns empty, not an error', () {
    final result = expandRepeatRule(
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      anchor: const LocalDate(2026, 6, 1),
      rangeStart: const LocalDate(2026, 6, 10),
      rangeEnd: const LocalDate(2026, 6, 5),
    );
    expect(result, isEmpty);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/medicine/domain/expand_repeat_rule_test.dart`
Expected: FAIL — `expand_repeat_rule.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';

/// Expands [rule] into concrete UTC dose instants across
/// `[rangeStart, rangeEnd]` (inclusive local calendar days). Pure — takes
/// [anchor] (the schedule's `startDate`) and the range as plain data, no
/// `clock.now()` — every caller (materialization, the 7-day schedule
/// preview) supplies its own range.
///
/// Times-of-day are resolved against the device's current ambient
/// timezone (D-14) — same approach as
/// `core/utils/local_day.dart`'s `localDayRangeUtc`.
List<DateTime> expandRepeatRule({
  required RepeatRule rule,
  required LocalDate anchor,
  required LocalDate rangeStart,
  required LocalDate rangeEnd,
}) {
  if (rangeEnd.compareTo(rangeStart) < 0) return [];
  final instants = <DateTime>[];
  var day = rangeStart;
  while (day.compareTo(rangeEnd) <= 0) {
    if (_ruleAppliesOnDay(rule, anchor: anchor, day: day)) {
      for (final time in _timesOfDay(rule)) {
        instants.add(_resolveLocalInstant(day, time));
      }
    }
    day = day.addDays(1);
  }
  return instants;
}

List<LocalTime> _timesOfDay(RepeatRule rule) => switch (rule) {
  FixedDailyRule(:final timesOfDay) => timesOfDay,
  EveryNDaysRule(:final timesOfDay) => timesOfDay,
  WeekdaySetRule(:final timesOfDay) => timesOfDay,
  PrnRule() => const [],
};

bool _ruleAppliesOnDay(
  RepeatRule rule, {
  required LocalDate anchor,
  required LocalDate day,
}) {
  if (day.compareTo(anchor) < 0) return false;
  return switch (rule) {
    FixedDailyRule() => true,
    EveryNDaysRule(:final intervalDays) =>
      _daysBetween(anchor, day) % intervalDays == 0,
    WeekdaySetRule(:final weekdaysMask) => _matchesWeekday(day, weekdaysMask),
    PrnRule() => false,
  };
}

/// Pure calendar-day count between two [LocalDate]s — computed via each
/// date's own UTC-midnight representation, which carries no wall-clock/
/// timezone information (D-14), so this is DST-immune by construction:
/// there is no ambient timezone conversion anywhere in this calculation.
int _daysBetween(LocalDate from, LocalDate to) =>
    to.toDateTimeUtc().difference(from.toDateTimeUtc()).inDays;

bool _matchesWeekday(LocalDate day, int mask) {
  final weekday = day.toDateTimeUtc().weekday; // Monday=1..Sunday=7
  return (mask & (1 << (weekday - 1))) != 0;
}

DateTime _resolveLocalInstant(LocalDate day, LocalTime time) {
  final local = DateTime(day.year, day.month, day.day, time.hour, time.minute);
  return local.toUtc();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/medicine/domain/expand_repeat_rule_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medicine/domain/usecases/expand_repeat_rule.dart test/features/medicine/domain/expand_repeat_rule_test.dart
git commit -m "feat(medicine): repeat-rule expansion for fixedDaily/weekdaySet/prn"
```

---

### Task 3: `expandRepeatRule` — every-N-days across a DST boundary (testing.md suite 3)

**Files:**
- Test: `test/features/medicine/domain/repeat_rule_every_n_days_test.dart`

**Interfaces:**
- Consumes: `expandRepeatRule` (Task 2), unchanged.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/expand_repeat_rule.dart';

void main() {
  test(
    'every-other-day anchoring never drifts across a 14-day window that '
    'includes a DST transition date (US spring-forward, 2026-03-08)',
    () {
      // Anchor Monday 2026-03-02: dose days are day 0, 2, 4, ... i.e.
      // 3/2, 3/4, 3/6, 3/8, 3/10, 3/12, 3/14 (7 doses across 14 days).
      const anchor = LocalDate(2026, 3, 2);
      final result = expandRepeatRule(
        rule: const RepeatRule.everyNDays(
          intervalDays: 2,
          timesOfDay: [LocalTime(8, 0)],
        ),
        anchor: anchor,
        rangeStart: anchor,
        rangeEnd: const LocalDate(2026, 3, 15),
      );

      final doseDays = result.map(LocalDate.fromDateTime).toSet();
      expect(doseDays, {
        const LocalDate(2026, 3, 2),
        const LocalDate(2026, 3, 4),
        const LocalDate(2026, 3, 6),
        const LocalDate(2026, 3, 8), // the DST date itself — still a dose day
        const LocalDate(2026, 3, 10),
        const LocalDate(2026, 3, 12),
        const LocalDate(2026, 3, 14),
      });
      // The DST date is a dose day, not skipped/duplicated by the transition.
      expect(result.where((d) => LocalDate.fromDateTime(d) == const LocalDate(2026, 3, 8)), hasLength(1));
    },
  );

  test('intervalDays: 3 lands on every third day, unaffected by DST', () {
    const anchor = LocalDate(2026, 3, 1);
    final result = expandRepeatRule(
      rule: const RepeatRule.everyNDays(
        intervalDays: 3,
        timesOfDay: [LocalTime(7, 30)],
      ),
      anchor: anchor,
      rangeStart: anchor,
      rangeEnd: const LocalDate(2026, 3, 10),
    );
    final doseDays = result.map(LocalDate.fromDateTime).toList();
    expect(doseDays, [
      const LocalDate(2026, 3, 1),
      const LocalDate(2026, 3, 4),
      const LocalDate(2026, 3, 7),
      const LocalDate(2026, 3, 10),
    ]);
  });

  test('editing the anchor (startDate) re-anchors the whole pattern', () {
    final originalAnchor = const LocalDate(2026, 3, 2);
    final newAnchor = const LocalDate(2026, 3, 3); // shifted by 1 day
    final result = expandRepeatRule(
      rule: const RepeatRule.everyNDays(
        intervalDays: 2,
        timesOfDay: [LocalTime(8, 0)],
      ),
      anchor: newAnchor,
      rangeStart: newAnchor,
      rangeEnd: const LocalDate(2026, 3, 9),
    );
    final doseDays = result.map(LocalDate.fromDateTime).toSet();
    // Dose days now fall on the *odd* offset from the original pattern.
    expect(doseDays, {
      const LocalDate(2026, 3, 3),
      const LocalDate(2026, 3, 5),
      const LocalDate(2026, 3, 7),
      const LocalDate(2026, 3, 9),
    });
    expect(doseDays.contains(originalAnchor), isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails or passes for the right reason**

Run: `flutter test test/features/medicine/domain/repeat_rule_every_n_days_test.dart`
Expected: PASS — Task 2's implementation already handles `everyNDays`
generically. This task exists to lock in dedicated, exhaustive coverage
of the single riskiest piece of logic in the module (testing.md), not to
add new production code. If it fails, the bug is in Task 2's
`_daysBetween`/`_ruleAppliesOnDay` — fix there, not here.

- [ ] **Step 3: Commit**

```bash
git add test/features/medicine/domain/repeat_rule_every_n_days_test.dart
git commit -m "test(medicine): dedicated DST-boundary coverage for every-N-days anchoring"
```

---

### Task 4: Dose status derivation + schedule activity (testing.md suite 4)

**Files:**
- Create: `lib/features/medicine/domain/usecases/dose_status.dart`
- Create: `lib/features/medicine/domain/usecases/schedule_activity.dart`
- Test: `test/features/medicine/domain/mark_dose_done_test.dart`

**Interfaces:**
- Consumes: `MedicineDoseStatus`, `Medicine`, `MedicineSchedule`,
  `LocalDate` (Task 1).
- Produces: `MedicineDoseStatus effectiveDoseStatus({required
  MedicineDoseStatus storedStatus, required DateTime scheduledFor,
  required DateTime now, required int graceWindowMinutes})` and `bool
  isScheduleActive({required Medicine medicine, required
  MedicineSchedule schedule, required LocalDate asOf})` — used by Task 6
  (materialization), Task 7 (adherence), Task 10 (repository dose
  queries), Task 14 (dose timeline UI).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/dose_status.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/schedule_activity.dart';

void main() {
  group('effectiveDoseStatus (D-05 grace-window state machine)', () {
    final scheduledFor = DateTime.utc(2026, 6, 1, 8, 0);

    test('before scheduled time: upcoming', () {
      expect(
        effectiveDoseStatus(
          storedStatus: MedicineDoseStatus.upcoming,
          scheduledFor: scheduledFor,
          now: scheduledFor.subtract(const Duration(minutes: 1)),
          graceWindowMinutes: 30,
        ),
        MedicineDoseStatus.upcoming,
      );
    });

    test('exactly at scheduled time: due', () {
      expect(
        effectiveDoseStatus(
          storedStatus: MedicineDoseStatus.upcoming,
          scheduledFor: scheduledFor,
          now: scheduledFor,
          graceWindowMinutes: 30,
        ),
        MedicineDoseStatus.due,
      );
    });

    test('exactly at the grace window boundary: still due (inclusive)', () {
      expect(
        effectiveDoseStatus(
          storedStatus: MedicineDoseStatus.upcoming,
          scheduledFor: scheduledFor,
          now: scheduledFor.add(const Duration(minutes: 30)),
          graceWindowMinutes: 30,
        ),
        MedicineDoseStatus.due,
      );
    });

    test('one minute past the grace window: missed', () {
      expect(
        effectiveDoseStatus(
          storedStatus: MedicineDoseStatus.upcoming,
          scheduledFor: scheduledFor,
          now: scheduledFor.add(const Duration(minutes: 31)),
          graceWindowMinutes: 30,
        ),
        MedicineDoseStatus.missed,
      );
    });

    test('a done dose stays done regardless of elapsed time', () {
      expect(
        effectiveDoseStatus(
          storedStatus: MedicineDoseStatus.done,
          scheduledFor: scheduledFor,
          now: scheduledFor.add(const Duration(days: 1)),
          graceWindowMinutes: 30,
        ),
        MedicineDoseStatus.done,
      );
    });

    test('a skipped dose stays skipped', () {
      expect(
        effectiveDoseStatus(
          storedStatus: MedicineDoseStatus.skipped,
          scheduledFor: scheduledFor,
          now: scheduledFor.add(const Duration(minutes: 1)),
          graceWindowMinutes: 30,
        ),
        MedicineDoseStatus.skipped,
      );
    });
  });

  group('isScheduleActive (D-04 stock-exhaustion behavior)', () {
    final medicine = Medicine(
      id: 'm1',
      name: 'Amoxicillin',
      stockEnabled: true,
      stockCount: 0,
      stockThreshold: 5,
    );
    final schedule = MedicineSchedule(
      id: 's1',
      medicineId: 'm1',
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 1, 1),
      createdAt: DateTime.utc(2026),
    );

    test(
      'zero stock does NOT stop the schedule when stopWhenStockDepleted '
      'is false (D-04 default)',
      () {
        expect(
          isScheduleActive(
            medicine: medicine,
            schedule: schedule,
            asOf: const LocalDate(2026, 6, 1),
          ),
          isTrue,
        );
      },
    );

    test(
      'zero stock DOES stop the schedule when stopWhenStockDepleted is true',
      () {
        expect(
          isScheduleActive(
            medicine: medicine.copyWith(stopWhenStockDepleted: true),
            schedule: schedule,
            asOf: const LocalDate(2026, 6, 1),
          ),
          isFalse,
        );
      },
    );

    test('an archived medicine is never active', () {
      expect(
        isScheduleActive(
          medicine: medicine.copyWith(archivedAt: DateTime.utc(2026, 5)),
          schedule: schedule,
          asOf: const LocalDate(2026, 6, 1),
        ),
        isFalse,
      );
    });

    test('past the schedule end date is never active', () {
      expect(
        isScheduleActive(
          medicine: medicine.copyWith(stockCount: 100),
          schedule: schedule.copyWith(endDate: const LocalDate(2026, 5, 1)),
          asOf: const LocalDate(2026, 6, 1),
        ),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/medicine/domain/mark_dose_done_test.dart`
Expected: FAIL — `dose_status.dart`/`schedule_activity.dart` don't exist.

- [ ] **Step 3: Write `dose_status.dart`**

```dart
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';

/// Derives a dose's live status (FR-M-06, D-05). [storedStatus] is only
/// ever `upcoming`/`done`/`skipped` in the database — `due`/`missed` are
/// computed here, at read time, so nothing needs a background job to
/// scan and flip rows as time passes.
MedicineDoseStatus effectiveDoseStatus({
  required MedicineDoseStatus storedStatus,
  required DateTime scheduledFor,
  required DateTime now,
  required int graceWindowMinutes,
}) {
  if (storedStatus != MedicineDoseStatus.upcoming) return storedStatus;
  if (now.isBefore(scheduledFor)) return MedicineDoseStatus.upcoming;
  final graceEnd = scheduledFor.add(Duration(minutes: graceWindowMinutes));
  if (!now.isAfter(graceEnd)) return MedicineDoseStatus.due;
  return MedicineDoseStatus.missed;
}
```

- [ ] **Step 4: Write `schedule_activity.dart`**

```dart
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';

/// Whether [schedule] should still generate/notify doses as of [asOf]
/// (FR-M-05/FR-M-10, D-04). Zero stock alone never deactivates a
/// schedule — only an explicit end date, archiving, or the opt-in
/// `stopWhenStockDepleted` toggle does.
bool isScheduleActive({
  required Medicine medicine,
  required MedicineSchedule schedule,
  required LocalDate asOf,
}) {
  if (medicine.archivedAt != null) return false;
  if (schedule.endDate != null && asOf.compareTo(schedule.endDate!) > 0) {
    return false;
  }
  if (medicine.stopWhenStockDepleted &&
      medicine.stockEnabled &&
      (medicine.stockCount ?? 0) <= 0) {
    return false;
  }
  return true;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/medicine/domain/mark_dose_done_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/medicine/domain/usecases/dose_status.dart lib/features/medicine/domain/usecases/schedule_activity.dart test/features/medicine/domain/mark_dose_done_test.dart
git commit -m "feat(medicine): dose status derivation and schedule-activity state machine"
```

---

### Task 5: Stock adjustment calculators (testing.md suite 5)

**Files:**
- Create: `lib/features/medicine/domain/usecases/stock_adjustment.dart`
- Test: `test/features/medicine/domain/medicine_stock_events_test.dart`

**Interfaces:**
- Consumes: `Medicine` (Task 1).
- Produces: `typedef StockAdjustment = ({int newStockCount, int
  stockDelta, bool writesEvent})`, `StockAdjustment
  calculateDoseTakenAdjustment({required Medicine medicine, required bool
  fromOtherSource})`; `typedef UndoAdjustment = ({int newStockCount, int
  stockDelta})`, `UndoAdjustment calculateDoseUndoneAdjustment({required
  Medicine medicine, required int stockDeltaApplied})` — used by Task 11
  (repository `markDoseDone`/`undoDose`).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/stock_adjustment.dart';

void main() {
  group('calculateDoseTakenAdjustment', () {
    test('normal path: decrements by consumptionPerDose, writes an event', () {
      final medicine = Medicine(
        id: 'm1',
        name: 'Ibuprofen',
        stockEnabled: true,
        stockCount: 10,
        consumptionPerDose: 2,
      );
      final result = calculateDoseTakenAdjustment(
        medicine: medicine,
        fromOtherSource: false,
      );
      expect(result.newStockCount, 8);
      expect(result.stockDelta, -2);
      expect(result.writesEvent, isTrue);
    });

    test('never goes below zero', () {
      final medicine = Medicine(
        id: 'm1',
        name: 'Ibuprofen',
        stockEnabled: true,
        stockCount: 1,
        consumptionPerDose: 5,
      );
      final result = calculateDoseTakenAdjustment(
        medicine: medicine,
        fromOtherSource: false,
      );
      expect(result.newStockCount, 0);
    });

    test('"taken from other source": no decrement, no event (FR-M-05)', () {
      final medicine = Medicine(
        id: 'm1',
        name: 'Ibuprofen',
        stockEnabled: true,
        stockCount: 0,
      );
      final result = calculateDoseTakenAdjustment(
        medicine: medicine,
        fromOtherSource: true,
      );
      expect(result.newStockCount, 0);
      expect(result.stockDelta, 0);
      expect(result.writesEvent, isFalse);
    });

    test('stock tracking disabled: no decrement, no event', () {
      final medicine = Medicine(id: 'm1', name: 'Ibuprofen', stockEnabled: false);
      final result = calculateDoseTakenAdjustment(
        medicine: medicine,
        fromOtherSource: false,
      );
      expect(result.stockDelta, 0);
      expect(result.writesEvent, isFalse);
    });
  });

  group('calculateDoseUndoneAdjustment', () {
    test('reverses a prior decrement exactly', () {
      final medicine = Medicine(
        id: 'm1',
        name: 'Ibuprofen',
        stockEnabled: true,
        stockCount: 8,
      );
      final result = calculateDoseUndoneAdjustment(
        medicine: medicine,
        stockDeltaApplied: -2,
      );
      expect(result.newStockCount, 10);
      expect(result.stockDelta, 2);
    });

    test('undoing a "taken from other source" dose (delta 0) is a no-op', () {
      final medicine = Medicine(
        id: 'm1',
        name: 'Ibuprofen',
        stockEnabled: true,
        stockCount: 5,
      );
      final result = calculateDoseUndoneAdjustment(
        medicine: medicine,
        stockDeltaApplied: 0,
      );
      expect(result.newStockCount, 5);
      expect(result.stockDelta, 0);
    });
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/medicine/domain/medicine_stock_events_test.dart`
Expected: FAIL — `stock_adjustment.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';

/// Result of marking a dose done: the medicine's new stock count, the
/// delta actually applied (0 if no event should be written), and whether
/// a [MedicineStockEvent] should be persisted (FR-M-04/05).
typedef StockAdjustment = ({
  int newStockCount,
  int stockDelta,
  bool writesEvent,
});

/// Computes the stock effect of marking a dose done. Pure — the caller
/// (the repository) persists [StockAdjustment.stockDelta] as a
/// `MedicineStockEvent(reason: doseTaken)` only when
/// [StockAdjustment.writesEvent] is true, and always writes
/// [StockAdjustment.stockDelta] onto the dose row's `stockDeltaApplied`
/// so [calculateDoseUndoneAdjustment] can reverse it exactly later.
///
/// [fromOtherSource] is FR-M-05's escape hatch for marking a dose done
/// without decrementing stock (e.g. the medicine ran out and the user
/// took it from elsewhere) — never decrements, never writes an event.
StockAdjustment calculateDoseTakenAdjustment({
  required Medicine medicine,
  required bool fromOtherSource,
}) {
  if (!medicine.stockEnabled || fromOtherSource) {
    return (
      newStockCount: medicine.stockCount ?? 0,
      stockDelta: 0,
      writesEvent: false,
    );
  }
  final delta = -medicine.consumptionPerDose;
  final newCount = (medicine.stockCount ?? 0) + delta;
  return (
    newStockCount: newCount < 0 ? 0 : newCount,
    stockDelta: delta,
    writesEvent: true,
  );
}

/// Result of undoing a done dose: the medicine's restored stock count and
/// the (positive) delta to record as a `MedicineStockEvent(reason:
/// doseUndone)`.
typedef UndoAdjustment = ({int newStockCount, int stockDelta});

/// Computes the stock effect of un-marking a done dose, exactly reversing
/// whatever [stockDeltaApplied] (from the dose row) was originally
/// applied — a no-op when that was 0 (a "taken from other source" dose).
UndoAdjustment calculateDoseUndoneAdjustment({
  required Medicine medicine,
  required int stockDeltaApplied,
}) {
  if (stockDeltaApplied == 0) {
    return (newStockCount: medicine.stockCount ?? 0, stockDelta: 0);
  }
  final restore = -stockDeltaApplied;
  return (newStockCount: (medicine.stockCount ?? 0) + restore, stockDelta: restore);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/medicine/domain/medicine_stock_events_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medicine/domain/usecases/stock_adjustment.dart test/features/medicine/domain/medicine_stock_events_test.dart
git commit -m "feat(medicine): pure stock adjustment calculators"
```

---

### Task 6: Dose materialization planner

**Files:**
- Create: `lib/features/medicine/domain/usecases/plan_dose_materialization.dart`
- Test: `test/features/medicine/domain/plan_dose_materialization_test.dart`

**Interfaces:**
- Consumes: `expandRepeatRule` (Task 2), `isScheduleActive` (Task 4),
  `Medicine`, `MedicineSchedule`, `MedicineDose` (Task 1).
- Produces: `typedef PlannedDose = ({String medicineId, String
  scheduleId, DateTime scheduledFor, int graceWindowMinutes})`,
  `List<PlannedDose> planDoseMaterialization({required List<Medicine>
  medicines, required List<MedicineSchedule> schedules, required
  List<MedicineDose> existingDoses, required LocalDate windowStart,
  required LocalDate windowEnd})` — used by Task 10
  (`MedicineRepositoryImpl.materializeDoses`).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/plan_dose_materialization.dart';

void main() {
  final medicine = Medicine(id: 'm1', name: 'Amoxicillin', stockEnabled: false);

  test('generates a PlannedDose per schedule instant within the window', () {
    final schedule = MedicineSchedule(
      id: 's1',
      medicineId: 'm1',
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
      createdAt: DateTime.utc(2026, 5),
    );
    final planned = planDoseMaterialization(
      medicines: [medicine],
      schedules: [schedule],
      existingDoses: const [],
      windowStart: const LocalDate(2026, 6, 1),
      windowEnd: const LocalDate(2026, 6, 2),
    );
    expect(planned, hasLength(2));
    expect(planned.every((p) => p.medicineId == 'm1' && p.scheduleId == 's1'), isTrue);
    expect(planned.every((p) => p.graceWindowMinutes == 30), isTrue);
  });

  test('never re-plans a slot that already has a dose row', () {
    final schedule = MedicineSchedule(
      id: 's1',
      medicineId: 'm1',
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
      createdAt: DateTime.utc(2026, 5),
    );
    final existing = MedicineDose(
      id: 'd1',
      medicineId: 'm1',
      scheduleId: 's1',
      scheduledFor: DateTime(2026, 6, 1, 8, 0).toUtc(),
      storedStatus: MedicineDoseStatus.done,
      graceWindowMinutes: 30,
    );
    final planned = planDoseMaterialization(
      medicines: [medicine],
      schedules: [schedule],
      existingDoses: [existing],
      windowStart: const LocalDate(2026, 6, 1),
      windowEnd: const LocalDate(2026, 6, 1),
    );
    expect(planned, isEmpty);
  });

  test(
    'D-02 collision: two schedules at the same medicine+time+day dedupe to '
    'the most-recently-created one',
    () {
      final older = MedicineSchedule(
        id: 'old',
        medicineId: 'm1',
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 6, 1),
        createdAt: DateTime.utc(2026, 1),
      );
      final newer = MedicineSchedule(
        id: 'new',
        medicineId: 'm1',
        rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
        startDate: const LocalDate(2026, 6, 1),
        createdAt: DateTime.utc(2026, 2),
        graceWindowMinutes: 45,
      );
      final planned = planDoseMaterialization(
        medicines: [medicine],
        schedules: [older, newer],
        existingDoses: const [],
        windowStart: const LocalDate(2026, 6, 1),
        windowEnd: const LocalDate(2026, 6, 1),
      );
      expect(planned, hasLength(1));
      expect(planned.single.scheduleId, 'new');
      expect(planned.single.graceWindowMinutes, 45);
    },
  );

  test('an inactive schedule (archived medicine) plans nothing', () {
    final schedule = MedicineSchedule(
      id: 's1',
      medicineId: 'm1',
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
      createdAt: DateTime.utc(2026, 5),
    );
    final planned = planDoseMaterialization(
      medicines: [medicine.copyWith(archivedAt: DateTime.utc(2026, 5))],
      schedules: [schedule],
      existingDoses: const [],
      windowStart: const LocalDate(2026, 6, 1),
      windowEnd: const LocalDate(2026, 6, 1),
    );
    expect(planned, isEmpty);
  });

  test('a schedule ending mid-window is clipped to its endDate', () {
    final schedule = MedicineSchedule(
      id: 's1',
      medicineId: 'm1',
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
      endDate: const LocalDate(2026, 6, 2),
      createdAt: DateTime.utc(2026, 5),
    );
    final planned = planDoseMaterialization(
      medicines: [medicine],
      schedules: [schedule],
      existingDoses: const [],
      windowStart: const LocalDate(2026, 6, 1),
      windowEnd: const LocalDate(2026, 6, 5),
    );
    expect(planned, hasLength(2)); // 6/1 and 6/2 only
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/medicine/domain/plan_dose_materialization_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/expand_repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/schedule_activity.dart';

/// A dose instance still to be inserted — the repository assigns its id
/// at insert time (ids are never generated in pure domain code, same
/// precedent as every other use case in this app).
typedef PlannedDose = ({
  String medicineId,
  String scheduleId,
  DateTime scheduledFor,
  int graceWindowMinutes,
});

/// Plans which new [MedicineDose] rows need to exist for
/// `[windowStart, windowEnd]` (D-13's 30-day rolling window), given every
/// active schedule and every dose row that already exists in that range.
///
/// Pure gap-filler: a slot that already has *any* dose row (regardless of
/// its status) is left untouched — this function never regenerates or
/// overwrites an existing row. Editing a schedule's future doses (FR-M-09)
/// is a separate, explicit repository operation
/// (`MedicineRepositoryImpl.updateSchedule`), not this periodic pass.
List<PlannedDose> planDoseMaterialization({
  required List<Medicine> medicines,
  required List<MedicineSchedule> schedules,
  required List<MedicineDose> existingDoses,
  required LocalDate windowStart,
  required LocalDate windowEnd,
}) {
  final medicinesById = {for (final m in medicines) m.id: m};
  final existingSlots = {
    for (final d in existingDoses) (d.medicineId, d.scheduledFor),
  };

  // D-02: if two schedules of the same medicine collide on the same
  // instant, the most-recently-created schedule wins.
  final winners = <(String, DateTime), MedicineSchedule>{};
  for (final schedule in schedules) {
    final medicine = medicinesById[schedule.medicineId];
    if (medicine == null) continue;
    if (!isScheduleActive(medicine: medicine, schedule: schedule, asOf: windowStart)) {
      continue;
    }
    final rangeStart = schedule.startDate.compareTo(windowStart) > 0
        ? schedule.startDate
        : windowStart;
    final rangeEnd = schedule.endDate == null
        ? windowEnd
        : (schedule.endDate!.compareTo(windowEnd) < 0
              ? schedule.endDate!
              : windowEnd);
    if (rangeStart.compareTo(rangeEnd) > 0) continue;

    final instants = expandRepeatRule(
      rule: schedule.rule,
      anchor: schedule.startDate,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    for (final instant in instants) {
      final key = (schedule.medicineId, instant);
      final current = winners[key];
      if (current == null || schedule.createdAt.isAfter(current.createdAt)) {
        winners[key] = schedule;
      }
    }
  }

  final planned = <PlannedDose>[];
  winners.forEach((key, schedule) {
    final (medicineId, scheduledFor) = key;
    if (existingSlots.contains((medicineId, scheduledFor))) return;
    planned.add((
      medicineId: medicineId,
      scheduleId: schedule.id,
      scheduledFor: scheduledFor,
      graceWindowMinutes: schedule.graceWindowMinutes,
    ));
  });
  return planned;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/medicine/domain/plan_dose_materialization_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medicine/domain/usecases/plan_dose_materialization.dart test/features/medicine/domain/plan_dose_materialization_test.dart
git commit -m "feat(medicine): dose materialization planner"
```

---

### Task 7: Adherence calculation

**Files:**
- Create: `lib/features/medicine/domain/usecases/calculate_adherence.dart`
- Test: `test/features/medicine/domain/calculate_adherence_test.dart`

**Interfaces:**
- Consumes: `effectiveDoseStatus` (Task 4), `MedicineDose`,
  `MedicineDoseStatus` (Task 1).
- Produces: `typedef AdherenceStats = ({int takenOnTime, int takenLate,
  int missed, int skipped, int total})`, `AdherenceStats
  calculateAdherence({required List<MedicineDose> doses, required
  DateTime now})` — used by Task 17/18 (detail/stats screens).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/calculate_adherence.dart';

void main() {
  final now = DateTime.utc(2026, 6, 10);

  MedicineDose dose({
    required DateTime scheduledFor,
    required MedicineDoseStatus storedStatus,
    DateTime? statusChangedAt,
    int graceWindowMinutes = 30,
  }) =>
      MedicineDose(
        id: 'd',
        medicineId: 'm1',
        scheduleId: 's1',
        scheduledFor: scheduledFor,
        storedStatus: storedStatus,
        statusChangedAt: statusChangedAt,
        graceWindowMinutes: graceWindowMinutes,
      );

  test('classifies on-time, late, missed, and skipped doses', () {
    final scheduled = DateTime.utc(2026, 6, 1, 8, 0);
    final stats = calculateAdherence(
      doses: [
        dose(
          scheduledFor: scheduled,
          storedStatus: MedicineDoseStatus.done,
          statusChangedAt: scheduled.add(const Duration(minutes: 10)),
        ), // on time
        dose(
          scheduledFor: scheduled,
          storedStatus: MedicineDoseStatus.done,
          statusChangedAt: scheduled.add(const Duration(minutes: 45)),
        ), // late
        dose(scheduledFor: scheduled, storedStatus: MedicineDoseStatus.upcoming), // -> missed (now is far past)
        dose(scheduledFor: scheduled, storedStatus: MedicineDoseStatus.skipped),
      ],
      now: now,
    );
    expect(stats.takenOnTime, 1);
    expect(stats.takenLate, 1);
    expect(stats.missed, 1);
    expect(stats.skipped, 1);
    expect(stats.total, 4);
  });

  test('upcoming/due doses are excluded from the total (not yet resolved)', () {
    final stats = calculateAdherence(
      doses: [
        dose(scheduledFor: now.add(const Duration(hours: 1)), storedStatus: MedicineDoseStatus.upcoming),
      ],
      now: now,
    );
    expect(stats.total, 0);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/medicine/domain/calculate_adherence_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/dose_status.dart';

/// Per-medicine adherence breakdown (FR-M-08).
typedef AdherenceStats = ({
  int takenOnTime,
  int takenLate,
  int missed,
  int skipped,
  int total,
});

/// Classifies [doses] into on-time/late/missed/skipped as of [now].
/// `upcoming`/`due` doses (not yet resolved one way or another) are
/// excluded from every count, including [AdherenceStats.total].
AdherenceStats calculateAdherence({
  required List<MedicineDose> doses,
  required DateTime now,
}) {
  var onTime = 0;
  var late = 0;
  var missed = 0;
  var skipped = 0;
  for (final dose in doses) {
    final status = effectiveDoseStatus(
      storedStatus: dose.storedStatus,
      scheduledFor: dose.scheduledFor,
      now: now,
      graceWindowMinutes: dose.graceWindowMinutes,
    );
    switch (status) {
      case MedicineDoseStatus.done:
        final changedAt = dose.statusChangedAt;
        final onTimeCutoff = dose.scheduledFor.add(
          Duration(minutes: dose.graceWindowMinutes),
        );
        if (changedAt != null && !changedAt.isAfter(onTimeCutoff)) {
          onTime++;
        } else {
          late++;
        }
      case MedicineDoseStatus.missed:
        missed++;
      case MedicineDoseStatus.skipped:
        skipped++;
      case MedicineDoseStatus.upcoming:
      case MedicineDoseStatus.due:
        break;
    }
  }
  return (
    takenOnTime: onTime,
    takenLate: late,
    missed: missed,
    skipped: skipped,
    total: onTime + late + missed + skipped,
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/medicine/domain/calculate_adherence_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medicine/domain/usecases/calculate_adherence.dart test/features/medicine/domain/calculate_adherence_test.dart
git commit -m "feat(medicine): adherence calculation"
```

---

### Task 8: Drift tables + `MedicineRepository` interface

**Files:**
- Create: `lib/features/medicine/data/tables/medicines_table.dart`
- Create: `lib/features/medicine/data/tables/medicine_schedules_table.dart`
- Create: `lib/features/medicine/data/tables/medicine_doses_table.dart`
- Create: `lib/features/medicine/data/tables/medicine_stock_events_table.dart`
- Create: `lib/features/medicine/domain/repositories/medicine_repository.dart`
- Modify: `lib/core/database/app_database.dart`

**Interfaces:**
- Produces: 4 Drift tables registered in `AppDatabase`; the
  `MedicineRepository` abstract interface Task 9-11 implement and every
  presentation task consumes.

- [ ] **Step 1: Write the four table files**

```dart
// lib/features/medicine/data/tables/medicines_table.dart
import 'package:drift/drift.dart';

/// A medicine record (`technical/database-design.md`).
///
/// `low_stock_notified_at` is an addition beyond that doc's original
/// column list — it makes FR-M-04's "one notification per threshold
/// crossing" possible without a background scan: set the instant stock
/// crosses at/below `stock_threshold`, cleared on the next refill that
/// brings it back above threshold.
@DataClassName('MedicineRow')
class MedicinesTable extends Table {
  @override
  String get tableName => 'medicines';

  /// Row id.
  TextColumn get id => text()();

  /// Medicine name.
  TextColumn get name => text()();

  /// Free-text dosage note, e.g. `"500mg"`.
  TextColumn get dosageNote => text().nullable()();

  /// Whether stock tracking is enabled for this medicine.
  BoolColumn get stockEnabled => boolean()();

  /// Current stock count, if tracking is enabled.
  IntColumn get stockCount => integer().nullable()();

  /// Low-stock trigger point.
  IntColumn get stockThreshold => integer().nullable()();

  /// D-04: default false — zero stock alone never ends the schedule.
  BoolColumn get stopWhenStockDepleted =>
      boolean().withDefault(const Constant(false))();

  /// Units consumed per dose marked done.
  IntColumn get consumptionPerDose => integer().withDefault(const Constant(1))();

  /// UTC epoch millis of the last low-stock crossing not yet cleared by a
  /// refill; null if not currently in a "just crossed" state.
  IntColumn get lowStockNotifiedAt => integer().nullable()();

  /// FR-M-10 soft-archive; null = active.
  IntColumn get archivedAt => integer().nullable()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

```dart
// lib/features/medicine/data/tables/medicine_schedules_table.dart
import 'package:drift/drift.dart';

/// One of a medicine's (possibly several, D-02) schedules
/// (`technical/database-design.md`).
@DataClassName('MedicineScheduleRow')
class MedicineSchedulesTable extends Table {
  @override
  String get tableName => 'medicine_schedules';

  /// Row id.
  TextColumn get id => text()();

  /// Owning medicine.
  TextColumn get medicineId => text()();

  /// `'fixed_daily'` | `'every_n_days'` | `'weekday_set'` | `'prn'`.
  TextColumn get frequencyType => text()();

  /// Used only when `frequencyType = 'every_n_days'` (D-03).
  IntColumn get intervalDays => integer().nullable()();

  /// Bitmask Mon=1..Sun=64, used only for `'weekday_set'`.
  IntColumn get weekdaysMask => integer().nullable()();

  /// JSON array of local `"HH:mm"` strings.
  TextColumn get timesOfDay => text()();

  /// Local calendar date `"YYYY-MM-DD"`, anchor for `every_n_days` (D-03).
  TextColumn get startDate => text()();

  /// Local calendar date, null = open-ended.
  TextColumn get endDate => text().nullable()();

  /// Default 30, editable 0-180 (D-05).
  IntColumn get graceWindowMinutes =>
      integer().withDefault(const Constant(30))();

  /// UTC epoch millis — the D-02 collision-priority tiebreaker.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

```dart
// lib/features/medicine/data/tables/medicine_doses_table.dart
import 'package:drift/drift.dart';

/// A materialized dose instance (D-13).
///
/// `grace_window_minutes` is denormalized from the generating schedule at
/// materialization time — an implementation refinement over
/// `technical/database-design.md`'s original column list, avoiding a join
/// back to `medicine_schedules` on the hottest read path (today's dose
/// list, adherence calc).
@DataClassName('MedicineDoseRow')
@TableIndex(name: 'idx_medicine_doses_scheduled_for', columns: {#scheduledFor})
@TableIndex(
  name: 'idx_medicine_doses_medicine_scheduled',
  columns: {#medicineId, #scheduledFor},
)
class MedicineDosesTable extends Table {
  @override
  String get tableName => 'medicine_doses';

  /// Row id.
  TextColumn get id => text()();

  /// Denormalized alongside `scheduleId` so a dose survives being queried
  /// even if its generating schedule is later edited/replaced.
  TextColumn get medicineId => text()();

  /// The schedule that generated this instance.
  TextColumn get scheduleId => text()();

  /// UTC epoch millis this dose is scheduled for.
  IntColumn get scheduledFor => integer()();

  /// `'upcoming'` | `'done'` | `'skipped'` only — `due`/`missed` are
  /// derived at read time (FR-M-06), never stored.
  TextColumn get status => text()();

  /// UTC epoch millis of the last explicit status change; null while
  /// still `upcoming`.
  IntColumn get statusChangedAt => integer().nullable()();

  /// How much stock this specific dose has deducted, so an undo reverses
  /// the exact right amount.
  IntColumn get stockDeltaApplied => integer().withDefault(const Constant(0))();

  /// Grace window (minutes) captured from the generating schedule.
  IntColumn get graceWindowMinutes => integer()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

```dart
// lib/features/medicine/data/tables/medicine_stock_events_table.dart
import 'package:drift/drift.dart';

/// Append-only stock ledger (`technical/database-design.md`) —
/// `medicines.stock_count` is a cached/derived value, this table is the
/// source of truth for "why did stock change."
@DataClassName('MedicineStockEventRow')
class MedicineStockEventsTable extends Table {
  @override
  String get tableName => 'medicine_stock_events';

  /// Row id.
  TextColumn get id => text()();

  /// Owning medicine.
  TextColumn get medicineId => text()();

  /// Null for manual refills/adjustments not tied to a dose.
  TextColumn get doseId => text().nullable()();

  /// Negative = consumption, positive = refill/adjustment.
  IntColumn get delta => integer()();

  /// `'dose_taken'` | `'manual_refill'` | `'manual_adjustment'` |
  /// `'dose_undone'`.
  TextColumn get reason => text()();

  /// UTC epoch millis.
  IntColumn get occurredAt => integer()();

  /// UTC epoch millis.
  IntColumn get createdAt => integer()();

  /// UTC epoch millis, bumped on every write.
  IntColumn get updatedAt => integer()();

  /// Soft-delete marker; null = not deleted.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: Register the tables in `app_database.dart`**

In `lib/core/database/app_database.dart`, add the four imports:

```dart
import 'package:habit_tracker/features/medicine/data/tables/medicine_doses_table.dart';
import 'package:habit_tracker/features/medicine/data/tables/medicine_schedules_table.dart';
import 'package:habit_tracker/features/medicine/data/tables/medicine_stock_events_table.dart';
import 'package:habit_tracker/features/medicine/data/tables/medicines_table.dart';
```

and add the four table classes to the `@DriftDatabase(tables: [...])` list
(alongside the existing `WaterGoalsTable, WaterLogsTable,
WaterSettingsTable`):

```dart
    MedicinesTable,
    MedicineSchedulesTable,
    MedicineDosesTable,
    MedicineStockEventsTable,
```

- [ ] **Step 3: Write the `MedicineRepository` interface**

```dart
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_stock_event.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';

/// Reads and mutates the Medicine module's data.
abstract class MedicineRepository {
  /// Streams every (non-deleted) medicine, optionally including archived
  /// ones (FR-M-10).
  Stream<List<Medicine>> watchMedicines({required bool includeArchived});

  /// Looks up a single medicine by id, or `null` if missing/deleted.
  Future<Medicine?> medicineById(String id);

  /// Creates a medicine (FR-M-01).
  Future<Result<Medicine>> createMedicine({
    required String name,
    String? dosageNote,
    required bool stockEnabled,
    int? stockCount,
    int? stockThreshold,
    bool stopWhenStockDepleted = false,
    int consumptionPerDose = 1,
  });

  /// Edits a medicine's own fields (not its schedules).
  Future<Result<void>> updateMedicine(
    String id, {
    String? name,
    String? dosageNote,
    bool? stockEnabled,
    int? stockCount,
    int? stockThreshold,
    bool? stopWhenStockDepleted,
    int? consumptionPerDose,
  });

  /// Soft-archives a medicine (FR-M-10) — stops generating doses/
  /// notifications, retains history.
  Future<Result<void>> archiveMedicine(String id);

  /// Restores a previously archived medicine.
  Future<Result<void>> restoreMedicine(String id);

  /// Streams a medicine's (non-deleted) schedules.
  Stream<List<MedicineSchedule>> watchSchedules(String medicineId);

  /// Creates a schedule for [medicineId] (D-02: a medicine may have
  /// several concurrent schedules).
  Future<Result<MedicineSchedule>> createSchedule({
    required String medicineId,
    required RepeatRule rule,
    required LocalDate startDate,
    LocalDate? endDate,
    int graceWindowMinutes = 30,
  });

  /// Edits a schedule (FR-M-09: applies to future doses only — deletes
  /// this schedule's still-`upcoming` doses at/after `now` so the next
  /// materialization pass regenerates them from the new rule; past/done/
  /// skipped doses are never touched).
  Future<Result<void>> updateSchedule(
    String id, {
    RepeatRule? rule,
    LocalDate? startDate,
    LocalDate? endDate,
    int? graceWindowMinutes,
  });

  /// Manually ends a schedule as of [endDate] (a user-initiated stop).
  Future<Result<void>> endSchedule(String id, {required LocalDate endDate});

  /// Tops up `medicine_doses` for the D-13 30-day rolling window ahead of
  /// [now]. Idempotent — safe to call from every re-planning trigger.
  Future<void> materializeDoses(DateTime now);

  /// Streams every (non-deleted) dose scheduled on [day], across every
  /// medicine — the flattened cross-schedule timeline (FR-M-02).
  Stream<List<MedicineDose>> watchDosesForDay(LocalDate day);

  /// Every (non-deleted) dose with `scheduledFor` in `[start, end]`
  /// inclusive — for previews/adherence.
  Future<List<MedicineDose>> dosesInRange(LocalDate start, LocalDate end);

  /// Marks a dose done (FR-M-07). [fromOtherSource]: true skips stock
  /// decrement (FR-M-05's out-of-stock allowance).
  Future<Result<void>> markDoseDone(
    String doseId, {
    required bool fromOtherSource,
  });

  /// Marks a dose explicitly skipped (FR-M-07) — never decrements stock,
  /// never counts as missed.
  Future<Result<void>> markDoseSkipped(String doseId);

  /// Un-marks a done dose, reversing its stock effect exactly.
  Future<Result<void>> undoDose(String doseId);

  /// Manually adds stock (a refill), recording a `manual_refill` event.
  /// Clears `lowStockNotifiedAt` once stock rises back above threshold.
  Future<Result<void>> refillStock(String medicineId, int amount);

  /// Medicines currently in a "just crossed below threshold, not yet
  /// cleared" state — the source `MedicineModule.pendingNotifications()`
  /// reads for FR-M-04's one-shot low-stock alert.
  Future<List<Medicine>> medicinesNeedingLowStockAlert();

  /// Every (non-deleted) medicine, including archived — export groundwork
  /// (`strategies/backup-import-export.md`).
  Future<List<Medicine>> allMedicines();

  /// Every (non-deleted) schedule across every medicine — export
  /// groundwork.
  Future<List<MedicineSchedule>> allSchedules();
}
```

- [ ] **Step 4: Generate Drift code and verify it compiles**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `app_database.g.dart` regenerates with the 4 new tables, no
errors.

Run: `flutter analyze lib/features/medicine/ lib/core/database/`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/medicine/data/tables/ lib/features/medicine/domain/repositories/ lib/core/database/app_database.dart lib/core/database/app_database.g.dart
git commit -m "feat(medicine): Drift tables and repository interface"
```

---

### Task 9: `MedicineRepositoryImpl` — medicines and schedules CRUD

**Files:**
- Create: `lib/features/medicine/data/repositories/medicine_repository_impl.dart`
- Test: `test/features/medicine/data/medicine_repository_impl_test.dart`

**Interfaces:**
- Consumes: `MedicineRepository` (Task 8), `RepeatRule`/DB mapping
  (this task), `generateId()` (`core/utils/uuid.dart`).
- Produces: `MedicineRepositoryImpl` class (constructor
  `MedicineRepositoryImpl(AppDatabase db)`) implementing the medicines/
  schedules half of the interface — Task 10 and 11 add the dose/stock
  methods to this same class in later steps.

- [ ] **Step 1: Write the failing tests (medicines/schedules subset)**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';

void main() {
  late AppDatabase db;
  late MedicineRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MedicineRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test('createMedicine persists and watchMedicines reflects it', () async {
    final result = await repo.createMedicine(
      name: 'Amoxicillin',
      stockEnabled: true,
      stockCount: 20,
      stockThreshold: 5,
    );
    expect(result, isA<Success<Medicine>>());

    final medicines = await repo.watchMedicines(includeArchived: false).first;
    expect(medicines, hasLength(1));
    expect(medicines.single.name, 'Amoxicillin');
    expect(medicines.single.stockCount, 20);
  });

  test('archiveMedicine excludes it from includeArchived: false, keeps it '
      'in includeArchived: true', () async {
    final created = await repo.createMedicine(name: 'X', stockEnabled: false);
    final id = (created as Success<Medicine>).value.id;

    await repo.archiveMedicine(id);

    expect(await repo.watchMedicines(includeArchived: false).first, isEmpty);
    final archived = await repo.watchMedicines(includeArchived: true).first;
    expect(archived, hasLength(1));
    expect(archived.single.archivedAt, isNotNull);
  });

  test('createSchedule persists and watchSchedules reflects it, with '
      'RepeatRule round-tripping through the DB', () async {
    final created = await repo.createMedicine(name: 'X', stockEnabled: false);
    final medicineId = (created as Success<Medicine>).value.id;

    final scheduleResult = await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.everyNDays(
        intervalDays: 2,
        timesOfDay: [LocalTime(8, 0), LocalTime(20, 0)],
      ),
      startDate: const LocalDate(2026, 6, 1),
    );
    expect(scheduleResult, isA<Success<MedicineSchedule>>());

    final schedules = await repo.watchSchedules(medicineId).first;
    expect(schedules, hasLength(1));
    final rule = schedules.single.rule;
    expect(rule, isA<EveryNDaysRule>());
    expect((rule as EveryNDaysRule).intervalDays, 2);
    expect(rule.timesOfDay, [const LocalTime(8, 0), const LocalTime(20, 0)]);
  });

  test('updateMedicine on an unknown id fails with NotFoundException', () async {
    final result = await repo.updateMedicine('missing', name: 'Y');
    expect(result, isA<Failure<void>>());
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/medicine/data/medicine_repository_impl_test.dart`
Expected: FAIL — `medicine_repository_impl.dart` doesn't exist.

- [ ] **Step 3: Write the implementation (medicines/schedules half)**

```dart
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/core/utils/uuid.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_stock_event.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/plan_dose_materialization.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/stock_adjustment.dart';

/// How far ahead `materializeDoses` tops up the dose window (D-13).
const _materializationWindowDays = 30;

/// Drift-backed [MedicineRepository]. No DAO — same precedent as Water's
/// `WaterRepositoryImpl`, one caller.
class MedicineRepositoryImpl implements MedicineRepository {
  /// Creates a repository backed by [_db].
  MedicineRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Medicine>> watchMedicines({required bool includeArchived}) {
    final query = _db.select(_db.medicinesTable)
      ..where((t) => t.deletedAt.isNull());
    if (!includeArchived) {
      query.where((t) => t.archivedAt.isNull());
    }
    return query.watch().map(
      (rows) => rows.map(_medicineFromRow).toList(growable: false),
    );
  }

  @override
  Future<Medicine?> medicineById(String id) async {
    final row = await (_db.select(
      _db.medicinesTable,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _medicineFromRow(row);
  }

  @override
  Future<Result<Medicine>> createMedicine({
    required String name,
    String? dosageNote,
    required bool stockEnabled,
    int? stockCount,
    int? stockThreshold,
    bool stopWhenStockDepleted = false,
    int consumptionPerDose = 1,
  }) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final id = generateId();
      await _db
          .into(_db.medicinesTable)
          .insert(
            MedicinesTableCompanion.insert(
              id: id,
              name: name,
              dosageNote: Value(dosageNote),
              stockEnabled: stockEnabled,
              stockCount: Value(stockCount),
              stockThreshold: Value(stockThreshold),
              stopWhenStockDepleted: Value(stopWhenStockDepleted),
              consumptionPerDose: Value(consumptionPerDose),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return Result.success(
        Medicine(
          id: id,
          name: name,
          dosageNote: dosageNote,
          stockEnabled: stockEnabled,
          stockCount: stockCount,
          stockThreshold: stockThreshold,
          stopWhenStockDepleted: stopWhenStockDepleted,
          consumptionPerDose: consumptionPerDose,
        ),
      );
    } on Object catch (e) {
      return Result.failure(AppException.storage('create_medicine', e));
    }
  }

  @override
  Future<Result<void>> updateMedicine(
    String id, {
    String? name,
    String? dosageNote,
    bool? stockEnabled,
    int? stockCount,
    int? stockThreshold,
    bool? stopWhenStockDepleted,
    int? consumptionPerDose,
  }) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(
            _db.medicinesTable,
          )..where((t) => t.id.equals(id))).write(
            MedicinesTableCompanion(
              name: name == null ? const Value.absent() : Value(name),
              dosageNote: dosageNote == null
                  ? const Value.absent()
                  : Value(dosageNote),
              stockEnabled: stockEnabled == null
                  ? const Value.absent()
                  : Value(stockEnabled),
              stockCount: stockCount == null
                  ? const Value.absent()
                  : Value(stockCount),
              stockThreshold: stockThreshold == null
                  ? const Value.absent()
                  : Value(stockThreshold),
              stopWhenStockDepleted: stopWhenStockDepleted == null
                  ? const Value.absent()
                  : Value(stopWhenStockDepleted),
              consumptionPerDose: consumptionPerDose == null
                  ? const Value.absent()
                  : Value(consumptionPerDose),
              updatedAt: Value(now),
            ),
          );
      if (rowsAffected == 0) {
        return Result.failure(AppException.notFound('Medicine', id));
      }
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('update_medicine', e));
    }
  }

  @override
  Future<Result<void>> archiveMedicine(String id) => _setArchived(id, true);

  @override
  Future<Result<void>> restoreMedicine(String id) => _setArchived(id, false);

  Future<Result<void>> _setArchived(String id, bool archived) async {
    try {
      final now = clock.now().toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(
            _db.medicinesTable,
          )..where((t) => t.id.equals(id))).write(
            MedicinesTableCompanion(
              archivedAt: Value(archived ? now : null),
              updatedAt: Value(now),
            ),
          );
      if (rowsAffected == 0) {
        return Result.failure(AppException.notFound('Medicine', id));
      }
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('archive_medicine', e));
    }
  }

  @override
  Stream<List<MedicineSchedule>> watchSchedules(String medicineId) {
    final query = _db.select(_db.medicineSchedulesTable)
      ..where((t) => t.medicineId.equals(medicineId) & t.deletedAt.isNull());
    return query.watch().map(
      (rows) => rows.map(_scheduleFromRow).toList(growable: false),
    );
  }

  @override
  Future<Result<MedicineSchedule>> createSchedule({
    required String medicineId,
    required RepeatRule rule,
    required LocalDate startDate,
    LocalDate? endDate,
    int graceWindowMinutes = 30,
  }) async {
    try {
      final now = clock.now();
      final nowMillis = now.toUtc().millisecondsSinceEpoch;
      final id = generateId();
      await _db
          .into(_db.medicineSchedulesTable)
          .insert(
            MedicineSchedulesTableCompanion.insert(
              id: id,
              medicineId: medicineId,
              frequencyType: rule.toDbFrequencyType(),
              intervalDays: Value(rule.toDbIntervalDays()),
              weekdaysMask: Value(rule.toDbWeekdaysMask()),
              timesOfDay: jsonEncode(
                rule.toDbTimesOfDay().map((t) => t.format()).toList(),
              ),
              startDate: startDate.toIso(),
              endDate: Value(endDate?.toIso()),
              graceWindowMinutes: Value(graceWindowMinutes),
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
      return Result.success(
        MedicineSchedule(
          id: id,
          medicineId: medicineId,
          rule: rule,
          startDate: startDate,
          endDate: endDate,
          graceWindowMinutes: graceWindowMinutes,
          createdAt: now,
        ),
      );
    } on Object catch (e) {
      return Result.failure(AppException.storage('create_schedule', e));
    }
  }

  @override
  Future<Result<void>> updateSchedule(
    String id, {
    RepeatRule? rule,
    LocalDate? startDate,
    LocalDate? endDate,
    int? graceWindowMinutes,
  }) async {
    try {
      final now = clock.now();
      final nowMillis = now.toUtc().millisecondsSinceEpoch;
      final rowsAffected =
          await (_db.update(
            _db.medicineSchedulesTable,
          )..where((t) => t.id.equals(id))).write(
            MedicineSchedulesTableCompanion(
              frequencyType: rule == null
                  ? const Value.absent()
                  : Value(rule.toDbFrequencyType()),
              intervalDays: rule == null
                  ? const Value.absent()
                  : Value(rule.toDbIntervalDays()),
              weekdaysMask: rule == null
                  ? const Value.absent()
                  : Value(rule.toDbWeekdaysMask()),
              timesOfDay: rule == null
                  ? const Value.absent()
                  : Value(
                      jsonEncode(
                        rule.toDbTimesOfDay().map((t) => t.format()).toList(),
                      ),
                    ),
              startDate: startDate == null
                  ? const Value.absent()
                  : Value(startDate.toIso()),
              endDate: endDate == null
                  ? const Value.absent()
                  : Value(endDate.toIso()),
              graceWindowMinutes: graceWindowMinutes == null
                  ? const Value.absent()
                  : Value(graceWindowMinutes),
              updatedAt: Value(nowMillis),
            ),
          );
      if (rowsAffected == 0) {
        return Result.failure(AppException.notFound('MedicineSchedule', id));
      }
      // FR-M-09: edits apply to future doses only. Delete this schedule's
      // still-upcoming doses at/after now so the next `materializeDoses`
      // pass regenerates them from the updated rule; done/skipped/past
      // rows are untouched.
      await (_db.update(_db.medicineDosesTable)..where(
        (t) =>
            t.scheduleId.equals(id) &
            t.status.equals('upcoming') &
            t.scheduledFor.isBiggerOrEqualValue(nowMillis),
      )).write(MedicineDosesTableCompanion(deletedAt: Value(nowMillis)));
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('update_schedule', e));
    }
  }

  @override
  Future<Result<void>> endSchedule(String id, {required LocalDate endDate}) =>
      updateSchedule(id, endDate: endDate);

  Medicine _medicineFromRow(MedicineRow row) => Medicine(
    id: row.id,
    name: row.name,
    dosageNote: row.dosageNote,
    stockEnabled: row.stockEnabled,
    stockCount: row.stockCount,
    stockThreshold: row.stockThreshold,
    stopWhenStockDepleted: row.stopWhenStockDepleted,
    consumptionPerDose: row.consumptionPerDose,
    lowStockNotifiedAt: row.lowStockNotifiedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.lowStockNotifiedAt!,
            isUtc: true,
          ),
    archivedAt: row.archivedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.archivedAt!, isUtc: true),
  );

  MedicineSchedule _scheduleFromRow(MedicineScheduleRow row) =>
      MedicineSchedule(
        id: row.id,
        medicineId: row.medicineId,
        rule: RepeatRuleDb.fromDb(
          frequencyType: row.frequencyType,
          intervalDays: row.intervalDays,
          weekdaysMask: row.weekdaysMask,
          timesOfDayJson: row.timesOfDay,
        ),
        startDate: LocalDate.parse(row.startDate),
        endDate: row.endDate == null ? null : LocalDate.parse(row.endDate!),
        graceWindowMinutes: row.graceWindowMinutes,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAt,
          isUtc: true,
        ),
      );

  // Task 10 adds dose-query/materialization methods here.
  // Task 11 adds stock/status-mutation methods here.
}

/// `RepeatRule` <-> DB column mapping, by explicit literal (same
/// convention as `WaterEntrySourceDb`).
extension RepeatRuleDb on RepeatRule {
  /// The stored `frequency_type` string.
  String toDbFrequencyType() => switch (this) {
    FixedDailyRule() => 'fixed_daily',
    EveryNDaysRule() => 'every_n_days',
    WeekdaySetRule() => 'weekday_set',
    PrnRule() => 'prn',
  };

  /// `interval_days`, only non-null for `every_n_days`.
  int? toDbIntervalDays() => switch (this) {
    EveryNDaysRule(:final intervalDays) => intervalDays,
    _ => null,
  };

  /// `weekdays_mask`, only non-null for `weekday_set`.
  int? toDbWeekdaysMask() => switch (this) {
    WeekdaySetRule(:final weekdaysMask) => weekdaysMask,
    _ => null,
  };

  /// `times_of_day`, empty for `prn`.
  List<LocalTime> toDbTimesOfDay() => switch (this) {
    FixedDailyRule(:final timesOfDay) => timesOfDay,
    EveryNDaysRule(:final timesOfDay) => timesOfDay,
    WeekdaySetRule(:final timesOfDay) => timesOfDay,
    PrnRule() => const [],
  };

  /// Reconstructs a [RepeatRule] from its stored columns.
  static RepeatRule fromDb({
    required String frequencyType,
    required int? intervalDays,
    required int? weekdaysMask,
    required String timesOfDayJson,
  }) {
    final times = (jsonDecode(timesOfDayJson) as List<dynamic>)
        .cast<String>()
        .map(LocalTime.parse)
        .toList();
    return switch (frequencyType) {
      'every_n_days' => RepeatRule.everyNDays(
        intervalDays: intervalDays!,
        timesOfDay: times,
      ),
      'weekday_set' => RepeatRule.weekdaySet(
        weekdaysMask: weekdaysMask!,
        timesOfDay: times,
      ),
      'prn' => const RepeatRule.prn(),
      _ => RepeatRule.fixedDaily(timesOfDay: times),
    };
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/medicine/data/medicine_repository_impl_test.dart`
Expected: PASS (4 tests). Note: this file compiles against the full
`MedicineRepository` interface, so `materializeDoses`/`watchDosesForDay`/
etc. must exist as stubs — see Step 3.5 below.

- [ ] **Step 3.5: Add temporary stubs for the not-yet-implemented interface methods**

Add these inside the class body (replacing the `// Task 10 adds...` /
`// Task 11 adds...` comments) so the class compiles against the full
interface before Tasks 10-11 fill them in for real:

```dart
  @override
  Future<void> materializeDoses(DateTime now) async {
    throw UnimplementedError('materializeDoses: implemented in Task 10');
  }

  @override
  Stream<List<MedicineDose>> watchDosesForDay(LocalDate day) {
    throw UnimplementedError('watchDosesForDay: implemented in Task 10');
  }

  @override
  Future<List<MedicineDose>> dosesInRange(LocalDate start, LocalDate end) {
    throw UnimplementedError('dosesInRange: implemented in Task 10');
  }

  @override
  Future<Result<void>> markDoseDone(
    String doseId, {
    required bool fromOtherSource,
  }) {
    throw UnimplementedError('markDoseDone: implemented in Task 11');
  }

  @override
  Future<Result<void>> markDoseSkipped(String doseId) {
    throw UnimplementedError('markDoseSkipped: implemented in Task 11');
  }

  @override
  Future<Result<void>> undoDose(String doseId) {
    throw UnimplementedError('undoDose: implemented in Task 11');
  }

  @override
  Future<Result<void>> refillStock(String medicineId, int amount) {
    throw UnimplementedError('refillStock: implemented in Task 11');
  }

  @override
  Future<List<Medicine>> medicinesNeedingLowStockAlert() {
    throw UnimplementedError(
      'medicinesNeedingLowStockAlert: implemented in Task 11',
    );
  }

  @override
  Future<List<Medicine>> allMedicines() async {
    final rows = await (_db.select(
      _db.medicinesTable,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(_medicineFromRow).toList(growable: false);
  }

  @override
  Future<List<MedicineSchedule>> allSchedules() async {
    final rows = await (_db.select(
      _db.medicineSchedulesTable,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(_scheduleFromRow).toList(growable: false);
  }
```

(`allMedicines`/`allSchedules` are simple enough to implement for real
now rather than stub — they're used by Task 19's export.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/medicine/data/repositories/medicine_repository_impl.dart test/features/medicine/data/medicine_repository_impl_test.dart
git commit -m "feat(medicine): repository medicines/schedules CRUD"
```

---

### Task 10: `MedicineRepositoryImpl` — dose materialization and queries

**Files:**
- Modify: `lib/features/medicine/data/repositories/medicine_repository_impl.dart`
- Modify: `test/features/medicine/data/medicine_repository_impl_test.dart`

**Interfaces:**
- Consumes: `planDoseMaterialization` (Task 6), `effectiveDoseStatus`
  (Task 4, used indirectly by callers, not here).
- Produces: real implementations of `materializeDoses`,
  `watchDosesForDay`, `dosesInRange` (replacing Task 9's stubs).

- [ ] **Step 1: Add failing tests**

Append to `test/features/medicine/data/medicine_repository_impl_test.dart`:

```dart
  test('materializeDoses fills a fixed-daily schedule\'s window and is '
      'idempotent on a second call', () async {
    final created = await repo.createMedicine(name: 'X', stockEnabled: false);
    final medicineId = (created as Success<Medicine>).value.id;
    await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });

    final firstPass = await repo.dosesInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 7, 1),
    );
    expect(firstPass, hasLength(31)); // 6/1 through 7/1 inclusive

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });
    final secondPass = await repo.dosesInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 7, 1),
    );
    expect(secondPass, hasLength(31)); // unchanged, not duplicated
  });

  test('watchDosesForDay reflects a single day\'s flattened cross-medicine '
      'timeline', () async {
    final medA = await repo.createMedicine(name: 'A', stockEnabled: false);
    final medB = await repo.createMedicine(name: 'B', stockEnabled: false);
    await repo.createSchedule(
      medicineId: (medA as Success<Medicine>).value.id,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await repo.createSchedule(
      medicineId: (medB as Success<Medicine>).value.id,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(9, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });

    final doses = await repo
        .watchDosesForDay(const LocalDate(2026, 6, 1))
        .first;
    expect(doses, hasLength(2));
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/medicine/data/medicine_repository_impl_test.dart`
Expected: FAIL with `UnimplementedError`.

- [ ] **Step 3: Replace the Step-3.5 stubs with real implementations**

Replace the `materializeDoses`/`watchDosesForDay`/`dosesInRange` stubs
from Task 9 with:

```dart
  @override
  Future<void> materializeDoses(DateTime now) async {
    final windowStart = localDayKey(now);
    final windowEnd = windowStart.addDays(_materializationWindowDays);

    final medicines = await (_db.select(
      _db.medicinesTable,
    )..where((t) => t.deletedAt.isNull())).get().then(
      (rows) => rows.map(_medicineFromRow).toList(),
    );
    final schedules = await (_db.select(
      _db.medicineSchedulesTable,
    )..where((t) => t.deletedAt.isNull())).get().then(
      (rows) => rows.map(_scheduleFromRow).toList(),
    );
    final existingDoses = await dosesInRange(windowStart, windowEnd);

    final planned = planDoseMaterialization(
      medicines: medicines,
      schedules: schedules,
      existingDoses: existingDoses,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    if (planned.isEmpty) return;

    final nowMillis = now.toUtc().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final dose in planned) {
        batch.insert(
          _db.medicineDosesTable,
          MedicineDosesTableCompanion.insert(
            id: generateId(),
            medicineId: dose.medicineId,
            scheduleId: dose.scheduleId,
            scheduledFor: dose.scheduledFor.toUtc().millisecondsSinceEpoch,
            status: 'upcoming',
            graceWindowMinutes: dose.graceWindowMinutes,
            createdAt: nowMillis,
            updatedAt: nowMillis,
          ),
        );
      }
    });
  }

  @override
  Stream<List<MedicineDose>> watchDosesForDay(LocalDate day) {
    final range = localDayRangeUtc(day);
    final query = _db.select(_db.medicineDosesTable)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.scheduledFor.isBiggerOrEqualValue(
              range.startUtc.millisecondsSinceEpoch,
            ) &
            t.scheduledFor.isSmallerThanValue(
              range.endUtc.millisecondsSinceEpoch,
            ),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledFor)]);
    return query.watch().map(
      (rows) => rows.map(_doseFromRow).toList(growable: false),
    );
  }

  @override
  Future<List<MedicineDose>> dosesInRange(
    LocalDate start,
    LocalDate end,
  ) async {
    final startUtc = localDayRangeUtc(start).startUtc;
    final endUtc = localDayRangeUtc(end).endUtc;
    final rows =
        await (_db.select(_db.medicineDosesTable)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.scheduledFor.isBiggerOrEqualValue(
                    startUtc.millisecondsSinceEpoch,
                  ) &
                  t.scheduledFor.isSmallerThanValue(
                    endUtc.millisecondsSinceEpoch,
                  ),
            ))
            .get();
    return rows.map(_doseFromRow).toList(growable: false);
  }
```

Add the row mapper next to `_medicineFromRow`/`_scheduleFromRow`:

```dart
  MedicineDose _doseFromRow(MedicineDoseRow row) => MedicineDose(
    id: row.id,
    medicineId: row.medicineId,
    scheduleId: row.scheduleId,
    scheduledFor: DateTime.fromMillisecondsSinceEpoch(
      row.scheduledFor,
      isUtc: true,
    ),
    storedStatus: MedicineDoseStatus.values.byName(row.status),
    statusChangedAt: row.statusChangedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.statusChangedAt!,
            isUtc: true,
          ),
    stockDeltaApplied: row.stockDeltaApplied,
    graceWindowMinutes: row.graceWindowMinutes,
  );
```

Note `status` is stored via `MedicineDoseStatus.values.byName(...)` /
`.name` (`upcoming`/`done`/`skipped` match the enum's own names exactly,
so no separate string-mapping extension is needed here, unlike
`RepeatRuleDb`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/medicine/data/medicine_repository_impl_test.dart`
Expected: PASS (6 tests total).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medicine/data/repositories/medicine_repository_impl.dart test/features/medicine/data/medicine_repository_impl_test.dart
git commit -m "feat(medicine): dose materialization and dose queries"
```

---

### Task 11: `MedicineRepositoryImpl` — dose actions and stock

**Files:**
- Modify: `lib/features/medicine/data/repositories/medicine_repository_impl.dart`
- Modify: `test/features/medicine/data/medicine_repository_impl_test.dart`

**Interfaces:**
- Consumes: `calculateDoseTakenAdjustment`,
  `calculateDoseUndoneAdjustment` (Task 5).
- Produces: real implementations of `markDoseDone`, `markDoseSkipped`,
  `undoDose`, `refillStock`, `medicinesNeedingLowStockAlert` (replacing
  Task 9's stubs).

- [ ] **Step 1: Add failing tests**

Append to `test/features/medicine/data/medicine_repository_impl_test.dart`:

```dart
  Future<String> _doseIdFor(MedicineRepositoryImpl repo, String medicineId) async {
    final doses = await repo.dosesInRange(
      const LocalDate(2026, 6, 1),
      const LocalDate(2026, 6, 1),
    );
    return doses.firstWhere((d) => d.medicineId == medicineId).id;
  }

  test('markDoseDone decrements stock, writes a ledger event, and the '
      'ledger reconciles back to medicines.stock_count', () async {
    final created = await repo.createMedicine(
      name: 'X',
      stockEnabled: true,
      stockCount: 10,
    );
    final medicineId = (created as Success<Medicine>).value.id;
    await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });
    final doseId = await _doseIdFor(repo, medicineId);

    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 8, 5)), () async {
      final result = await repo.markDoseDone(doseId, fromOtherSource: false);
      expect(result, isA<Success<void>>());
    });

    final medicine = await repo.medicineById(medicineId);
    expect(medicine!.stockCount, 9);
  });

  test('undoDose reverses the exact stock amount previously applied', () async {
    final created = await repo.createMedicine(
      name: 'X',
      stockEnabled: true,
      stockCount: 10,
    );
    final medicineId = (created as Success<Medicine>).value.id;
    await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });
    final doseId = await _doseIdFor(repo, medicineId);
    await repo.markDoseDone(doseId, fromOtherSource: false);

    await repo.undoDose(doseId);

    final medicine = await repo.medicineById(medicineId);
    expect(medicine!.stockCount, 10);
  });

  test('crossing the low-stock threshold surfaces the medicine exactly '
      'once, and a refill clears it', () async {
    final created = await repo.createMedicine(
      name: 'X',
      stockEnabled: true,
      stockCount: 1,
      stockThreshold: 5,
    );
    final medicineId = (created as Success<Medicine>).value.id;
    await repo.createSchedule(
      medicineId: medicineId,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });
    final doseId = await _doseIdFor(repo, medicineId);

    await repo.markDoseDone(doseId, fromOtherSource: false); // 1 -> 0, crosses threshold 5

    var alerts = await repo.medicinesNeedingLowStockAlert();
    expect(alerts.map((m) => m.id), contains(medicineId));

    await repo.refillStock(medicineId, 20);

    alerts = await repo.medicinesNeedingLowStockAlert();
    expect(alerts.map((m) => m.id), isNot(contains(medicineId)));
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/medicine/data/medicine_repository_impl_test.dart`
Expected: FAIL with `UnimplementedError` on the remaining stubs.

- [ ] **Step 3: Replace the remaining stubs with real implementations**

```dart
  @override
  Future<Result<void>> markDoseDone(
    String doseId, {
    required bool fromOtherSource,
  }) => _resolveDose(
    doseId,
    resolve: (medicine, dose) async {
      final adjustment = calculateDoseTakenAdjustment(
        medicine: medicine,
        fromOtherSource: fromOtherSource,
      );
      final now = clock.now();
      final nowMillis = now.toUtc().millisecondsSinceEpoch;

      await (_db.update(
        _db.medicineDosesTable,
      )..where((t) => t.id.equals(dose.id))).write(
        MedicineDosesTableCompanion(
          status: const Value('done'),
          statusChangedAt: Value(nowMillis),
          stockDeltaApplied: Value(adjustment.stockDelta),
          updatedAt: Value(nowMillis),
        ),
      );
      await _applyStockAdjustment(
        medicine: medicine,
        dose: dose,
        newStockCount: adjustment.newStockCount,
        stockDelta: adjustment.stockDelta,
        writesEvent: adjustment.writesEvent,
        reason: MedicineStockEventReason.doseTaken,
        occurredAt: now,
      );
    },
  );

  @override
  Future<Result<void>> markDoseSkipped(String doseId) => _resolveDose(
    doseId,
    resolve: (medicine, dose) async {
      final nowMillis = clock.now().toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.medicineDosesTable,
      )..where((t) => t.id.equals(dose.id))).write(
        MedicineDosesTableCompanion(
          status: const Value('skipped'),
          statusChangedAt: Value(nowMillis),
          updatedAt: Value(nowMillis),
        ),
      );
    },
  );

  @override
  Future<Result<void>> undoDose(String doseId) => _resolveDose(
    doseId,
    resolve: (medicine, dose) async {
      final adjustment = calculateDoseUndoneAdjustment(
        medicine: medicine,
        stockDeltaApplied: dose.stockDeltaApplied,
      );
      final now = clock.now();
      final nowMillis = now.toUtc().millisecondsSinceEpoch;
      await (_db.update(
        _db.medicineDosesTable,
      )..where((t) => t.id.equals(dose.id))).write(
        MedicineDosesTableCompanion(
          status: const Value('upcoming'),
          statusChangedAt: const Value(null),
          stockDeltaApplied: const Value(0),
          updatedAt: Value(nowMillis),
        ),
      );
      if (adjustment.stockDelta != 0) {
        await _applyStockAdjustment(
          medicine: medicine,
          dose: dose,
          newStockCount: adjustment.newStockCount,
          stockDelta: adjustment.stockDelta,
          writesEvent: true,
          reason: MedicineStockEventReason.doseUndone,
          occurredAt: now,
        );
      }
    },
  );

  /// Shared "look up medicine+dose, run [resolve], wrap in `Result`"
  /// skeleton for the three dose-action methods above.
  Future<Result<void>> _resolveDose(
    String doseId, {
    required Future<void> Function(Medicine medicine, MedicineDose dose)
    resolve,
  }) async {
    try {
      final doseRow = await (_db.select(
        _db.medicineDosesTable,
      )..where((t) => t.id.equals(doseId) & t.deletedAt.isNull())).getSingleOrNull();
      if (doseRow == null) {
        return Result.failure(AppException.notFound('MedicineDose', doseId));
      }
      final dose = _doseFromRow(doseRow);
      final medicine = await medicineById(dose.medicineId);
      if (medicine == null) {
        return Result.failure(
          AppException.notFound('Medicine', dose.medicineId),
        );
      }
      await resolve(medicine, dose);
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('resolve_dose_action', e));
    }
  }

  Future<void> _applyStockAdjustment({
    required Medicine medicine,
    required MedicineDose dose,
    required int newStockCount,
    required int stockDelta,
    required bool writesEvent,
    required MedicineStockEventReason reason,
    required DateTime occurredAt,
  }) async {
    final nowMillis = clock.now().toUtc().millisecondsSinceEpoch;
    final wasAboveThreshold =
        medicine.stockThreshold == null ||
        (medicine.stockCount ?? 0) > medicine.stockThreshold!;
    final isNowAtOrBelow =
        medicine.stockThreshold != null &&
        newStockCount <= medicine.stockThreshold!;
    final justCrossed =
        wasAboveThreshold && isNowAtOrBelow && medicine.lowStockNotifiedAt == null;

    await (_db.update(
      _db.medicinesTable,
    )..where((t) => t.id.equals(medicine.id))).write(
      MedicinesTableCompanion(
        stockCount: Value(newStockCount),
        lowStockNotifiedAt: justCrossed
            ? Value(nowMillis)
            : const Value.absent(),
        updatedAt: Value(nowMillis),
      ),
    );

    if (writesEvent) {
      await _db
          .into(_db.medicineStockEventsTable)
          .insert(
            MedicineStockEventsTableCompanion.insert(
              id: generateId(),
              medicineId: medicine.id,
              doseId: Value(dose.id),
              delta: stockDelta,
              reason: reason.toDb(),
              occurredAt: occurredAt.toUtc().millisecondsSinceEpoch,
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
    }
  }

  @override
  Future<Result<void>> refillStock(String medicineId, int amount) async {
    try {
      final medicine = await medicineById(medicineId);
      if (medicine == null) {
        return Result.failure(AppException.notFound('Medicine', medicineId));
      }
      final now = clock.now();
      final nowMillis = now.toUtc().millisecondsSinceEpoch;
      final newCount = (medicine.stockCount ?? 0) + amount;
      final clearsLowStock =
          medicine.stockThreshold == null || newCount > medicine.stockThreshold!;

      await (_db.update(
        _db.medicinesTable,
      )..where((t) => t.id.equals(medicineId))).write(
        MedicinesTableCompanion(
          stockCount: Value(newCount),
          lowStockNotifiedAt: clearsLowStock
              ? const Value(null)
              : const Value.absent(),
          updatedAt: Value(nowMillis),
        ),
      );
      await _db
          .into(_db.medicineStockEventsTable)
          .insert(
            MedicineStockEventsTableCompanion.insert(
              id: generateId(),
              medicineId: medicineId,
              delta: amount,
              reason: MedicineStockEventReason.manualRefill.toDb(),
              occurredAt: now.toUtc().millisecondsSinceEpoch,
              createdAt: nowMillis,
              updatedAt: nowMillis,
            ),
          );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(AppException.storage('refill_stock', e));
    }
  }

  @override
  Future<List<Medicine>> medicinesNeedingLowStockAlert() async {
    final rows =
        await (_db.select(_db.medicinesTable)..where(
              (t) => t.deletedAt.isNull() & t.lowStockNotifiedAt.isNotNull(),
            ))
            .get();
    return rows.map(_medicineFromRow).toList(growable: false);
  }
```

Add the `MedicineStockEventReason` <-> DB mapping extension next to
`RepeatRuleDb`:

```dart
/// `MedicineStockEventReason` <-> DB string mapping.
extension MedicineStockEventReasonDb on MedicineStockEventReason {
  /// The stored DB string for this value.
  String toDb() => switch (this) {
    MedicineStockEventReason.doseTaken => 'dose_taken',
    MedicineStockEventReason.manualRefill => 'manual_refill',
    MedicineStockEventReason.manualAdjustment => 'manual_adjustment',
    MedicineStockEventReason.doseUndone => 'dose_undone',
  };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/medicine/data/medicine_repository_impl_test.dart`
Expected: PASS (9 tests total).

Run: `flutter analyze lib/features/medicine/`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/medicine/data/repositories/medicine_repository_impl.dart test/features/medicine/data/medicine_repository_impl_test.dart
git commit -m "feat(medicine): dose actions, stock ledger, and low-stock crossing"
```

---

### Task 12: Riverpod providers and controller

**Files:**
- Create: `lib/features/medicine/presentation/providers/medicine_providers.dart`
- Create: `lib/features/medicine/presentation/providers/medicine_controller.dart`

**Interfaces:**
- Consumes: `MedicineRepositoryImpl` (Task 9-11), `MedicineRepository`,
  entities (Task 1), `effectiveDoseStatus` (Task 4).
- Produces: `medicineRepositoryProvider`, `medicinesProvider(
  {required bool includeArchived})`, `medicineByIdProvider(String id)`,
  `medicineSchedulesProvider(String medicineId)`,
  `todaysDosesProvider`, `todaysDoseViewsProvider`,
  `MedicineDoseView` typedef, `medicineController` — consumed by every
  screen task.

- [ ] **Step 1: Write `medicine_providers.dart`**

```dart
import 'package:clock/clock.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_schedule.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/dose_status.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'medicine_providers.g.dart';

/// The Medicine module's [MedicineRepository].
@Riverpod(keepAlive: true)
MedicineRepository medicineRepository(Ref ref) {
  return MedicineRepositoryImpl(ref.watch(databaseProvider));
}

LocalDate _today() => localDayKey(clock.now());

/// Every (non-deleted) medicine, optionally including archived ones.
@riverpod
Stream<List<Medicine>> medicines(Ref ref, {required bool includeArchived}) {
  return ref
      .watch(medicineRepositoryProvider)
      .watchMedicines(includeArchived: includeArchived);
}

/// A single medicine by id, for the detail/edit screens.
@riverpod
Future<Medicine?> medicineById(Ref ref, String id) {
  return ref.watch(medicineRepositoryProvider).medicineById(id);
}

/// A medicine's (non-deleted) schedules.
@riverpod
Stream<List<MedicineSchedule>> medicineSchedules(Ref ref, String medicineId) {
  return ref.watch(medicineRepositoryProvider).watchSchedules(medicineId);
}

/// Every dose scheduled today, across every medicine.
@riverpod
Stream<List<MedicineDose>> todaysDoses(Ref ref) {
  return ref.watch(medicineRepositoryProvider).watchDosesForDay(_today());
}

/// A dose paired with its medicine and live-derived status — what the
/// dose timeline (Task 14) actually renders.
typedef MedicineDoseView = ({
  MedicineDose dose,
  Medicine medicine,
  MedicineDoseStatus effectiveStatus,
});

/// Today's doses, joined with their medicine and effective status,
/// ordered by scheduled time — or `null` while still loading.
@riverpod
List<MedicineDoseView>? todaysDoseViews(Ref ref) {
  final doses = ref.watch(todaysDosesProvider).value;
  final medicines = ref.watch(medicinesProvider(includeArchived: false)).value;
  if (doses == null || medicines == null) return null;
  final medicinesById = {for (final m in medicines) m.id: m};
  final now = clock.now();
  final views = <MedicineDoseView>[
    for (final dose in doses)
      if (medicinesById[dose.medicineId] case final medicine?)
        (
          dose: dose,
          medicine: medicine,
          effectiveStatus: effectiveDoseStatus(
            storedStatus: dose.storedStatus,
            scheduledFor: dose.scheduledFor,
            now: now,
            graceWindowMinutes: dose.graceWindowMinutes,
          ),
        ),
  ];
  views.sort((a, b) => a.dose.scheduledFor.compareTo(b.dose.scheduledFor));
  return views;
}
```

- [ ] **Step 2: Write `medicine_controller.dart`**

```dart
import 'package:clock/clock.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'medicine_controller.g.dart';

/// Mutation surface for the Medicine module — a pure command controller
/// mirroring `WaterController`'s shape (no state of its own; screens
/// watch the read providers in `medicine_providers.dart`).
@Riverpod(keepAlive: true)
class MedicineController extends _$MedicineController {
  @override
  void build() {}

  /// Creates a medicine with one initial schedule (FR-M-01).
  Future<void> createMedicine({
    required String name,
    String? dosageNote,
    required bool stockEnabled,
    int? stockCount,
    int? stockThreshold,
    bool stopWhenStockDepleted = false,
    int consumptionPerDose = 1,
    required RepeatRule rule,
    required LocalDate startDate,
    LocalDate? endDate,
    int graceWindowMinutes = 30,
  }) async {
    final repository = ref.read(medicineRepositoryProvider);
    final medicineResult = await repository.createMedicine(
      name: name,
      dosageNote: dosageNote,
      stockEnabled: stockEnabled,
      stockCount: stockCount,
      stockThreshold: stockThreshold,
      stopWhenStockDepleted: stopWhenStockDepleted,
      consumptionPerDose: consumptionPerDose,
    );
    if (medicineResult case Failure(:final error)) {
      logException(error);
      return;
    }
    final medicine = (medicineResult as Success).value;
    final scheduleResult = await repository.createSchedule(
      medicineId: medicine.id,
      rule: rule,
      startDate: startDate,
      endDate: endDate,
      graceWindowMinutes: graceWindowMinutes,
    );
    if (scheduleResult case Failure(:final error)) logException(error);
    await repository.materializeDoses(clock.now());
  }

  /// Adds an additional schedule to an existing medicine (D-02).
  Future<void> addSchedule({
    required String medicineId,
    required RepeatRule rule,
    required LocalDate startDate,
    LocalDate? endDate,
    int graceWindowMinutes = 30,
  }) async {
    final repository = ref.read(medicineRepositoryProvider);
    final result = await repository.createSchedule(
      medicineId: medicineId,
      rule: rule,
      startDate: startDate,
      endDate: endDate,
      graceWindowMinutes: graceWindowMinutes,
    );
    if (result case Failure(:final error)) logException(error);
    await repository.materializeDoses(clock.now());
  }

  /// Marks a dose done (FR-M-07).
  Future<void> markDoseDone(String doseId, {bool fromOtherSource = false}) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .markDoseDone(doseId, fromOtherSource: fromOtherSource);
    if (result case Failure(:final error)) logException(error);
  }

  /// Marks a dose skipped (FR-M-07).
  Future<void> markDoseSkipped(String doseId) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .markDoseSkipped(doseId);
    if (result case Failure(:final error)) logException(error);
  }

  /// Un-marks a done dose.
  Future<void> undoDose(String doseId) async {
    final result = await ref.read(medicineRepositoryProvider).undoDose(doseId);
    if (result case Failure(:final error)) logException(error);
  }

  /// Archives a medicine (FR-M-10).
  Future<void> archiveMedicine(String id) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .archiveMedicine(id);
    if (result case Failure(:final error)) logException(error);
  }

  /// Restores an archived medicine.
  Future<void> restoreMedicine(String id) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .restoreMedicine(id);
    if (result case Failure(:final error)) logException(error);
  }

  /// Adds stock via a manual refill.
  Future<void> refillStock(String medicineId, int amount) async {
    final result = await ref
        .read(medicineRepositoryProvider)
        .refillStock(medicineId, amount);
    if (result case Failure(:final error)) logException(error);
  }
}
```

- [ ] **Step 3: Generate Riverpod code and verify it compiles**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `medicine_providers.g.dart`/`medicine_controller.g.dart`
generated, no errors.

Run: `flutter analyze lib/features/medicine/presentation/providers/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/medicine/presentation/providers/
git commit -m "feat(medicine): Riverpod providers and controller"
```

---

### Task 13: `MedicineModule` (`HabitModule` registration) + wiring

**Files:**
- Create: `lib/features/medicine/medicine_module.dart`
- Test: `test/features/medicine/medicine_module_test.dart`
- Modify: `lib/core/modules/module_registry.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/core/notifications/notification_service.dart`
- Delete: `lib/features/medicine/presentation/screens/medicine_home_screen.dart` (placeholder — Task 14 recreates it for real)

**Interfaces:**
- Consumes: `MedicineRepository` (Task 8-11), `HabitModule`/
  `PendingNotification`/`NotificationActionType` (`core/modules/
  habit_module.dart`), screens from Tasks 14-18 (this task wires their
  routes; the screens themselves land in those tasks — write this task's
  route list referencing the not-yet-existing screen classes, then Tasks
  14-18 make them real, matching how a plan's later tasks fill in
  forward references is normal here since Task 13 is the wiring hub).
- Produces: `MedicineModule` class, registered in `buildHabitModules`.

**Note on sequencing:** this task references `MedicineHomeScreen`,
`MedicineListScreen`, `MedicineFormScreen`, `MedicineDetailScreen`,
`MedicineStatsScreen` from Tasks 14-18. Implement this task's non-route
pieces (`pendingNotifications`, `onNotificationAction`, `exportData`/
`importData`, the module test) first and stub the 5 screens as trivial
placeholders in this task so the app compiles, then Tasks 14-18 replace
each stub with the real screen (each is a self-contained find-and-replace
of one file, not a re-wiring of this task).

- [ ] **Step 1: Write minimal screen stubs (Tasks 14-18 replace these)**

```dart
// lib/features/medicine/presentation/screens/medicine_home_screen.dart
import 'package:flutter/material.dart';

/// Stub — replaced by Task 14.
class MedicineHomeScreen extends StatelessWidget {
  /// Creates the stub.
  const MedicineHomeScreen({super.key, this.highlightDoseId});

  /// Dose id to highlight when opened via a notification deep link.
  final String? highlightDoseId;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

Repeat the same trivial `StatelessWidget` + `const Placeholder()` pattern
for:
- `lib/features/medicine/presentation/screens/medicine_list_screen.dart`
  (`MedicineListScreen`, no constructor params)
- `lib/features/medicine/presentation/screens/medicine_form_screen.dart`
  (`MedicineFormScreen({super.key, this.editMedicineId})`)
- `lib/features/medicine/presentation/screens/medicine_detail_screen.dart`
  (`MedicineDetailScreen({super.key, required this.medicineId})`)
- `lib/features/medicine/presentation/screens/medicine_stats_screen.dart`
  (`MedicineStatsScreen({super.key})`)

- [ ] **Step 2: Write the failing module test**

```dart
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/medicine_module.dart';
import 'package:mocktail/mocktail.dart';

class _MockMedicineRepository extends Mock implements MedicineRepository {}

void main() {
  late _MockMedicineRepository repo;
  late MedicineModule module;

  setUp(() {
    repo = _MockMedicineRepository();
    module = MedicineModule(repo);
  });

  test('pendingNotifications maps due doses within 3 days to '
      'PendingNotification with sourceType medicine_dose', () async {
    final now = DateTime.utc(2026, 6, 1, 7);
    final dose = MedicineDose(
      id: 'd1',
      medicineId: 'm1',
      scheduleId: 's1',
      scheduledFor: DateTime.utc(2026, 6, 1, 8),
      storedStatus: MedicineDoseStatus.upcoming,
      graceWindowMinutes: 30,
    );
    final medicine = Medicine(id: 'm1', name: 'X', stockEnabled: false);

    when(() => repo.materializeDoses(any())).thenAnswer((_) async {});
    when(
      () => repo.dosesInRange(any(), any()),
    ).thenAnswer((_) async => [dose]);
    when(() => repo.medicineById('m1')).thenAnswer((_) async => medicine);
    when(() => repo.medicinesNeedingLowStockAlert()).thenAnswer((_) async => []);

    await withClock(Clock.fixed(now), () async {
      final notifications = await module.pendingNotifications();
      expect(notifications, hasLength(1));
      expect(notifications.single.sourceType, 'medicine_dose');
      expect(notifications.single.deepLinkRoute, '/medicine/dose/d1');
    });
  });

  test('pendingNotifications includes a low_stock notification for '
      'medicines returned by medicinesNeedingLowStockAlert', () async {
    final now = DateTime.utc(2026, 6, 1, 7);
    final medicine = Medicine(
      id: 'm1',
      name: 'X',
      stockEnabled: true,
      stockCount: 0,
      stockThreshold: 5,
      lowStockNotifiedAt: now,
    );
    when(() => repo.materializeDoses(any())).thenAnswer((_) async {});
    when(() => repo.dosesInRange(any(), any())).thenAnswer((_) async => []);
    when(
      () => repo.medicinesNeedingLowStockAlert(),
    ).thenAnswer((_) async => [medicine]);

    await withClock(Clock.fixed(now), () async {
      final notifications = await module.pendingNotifications();
      expect(notifications.where((n) => n.sourceType == 'low_stock'), hasLength(1));
    });
  });

  test('onNotificationAction(done) marks the dose done', () async {
    when(
      () => repo.markDoseDone(any(), fromOtherSource: any(named: 'fromOtherSource')),
    ).thenAnswer((_) async => const Result.success(null));

    await module.onNotificationAction('d1', NotificationActionType.done);

    verify(
      () => repo.markDoseDone('d1', fromOtherSource: false),
    ).called(1);
  });

  test('onNotificationAction(skip) marks the dose skipped', () async {
    when(
      () => repo.markDoseSkipped(any()),
    ).thenAnswer((_) async => const Result.success(null));

    await module.onNotificationAction('d1', NotificationActionType.skip);

    verify(() => repo.markDoseSkipped('d1')).called(1);
  });

  test('onNotificationAction(snooze) never mutates dose data', () async {
    await module.onNotificationAction('d1', NotificationActionType.snooze);
    verifyNever(() => repo.markDoseDone(any(), fromOtherSource: any(named: 'fromOtherSource')));
    verifyNever(() => repo.markDoseSkipped(any()));
  });
}
```

Note: `onNotificationAction`'s low-stock-sourced ids (prefixed
`medicine_lowstock_`) are routed differently — see the implementation
below; this test file only exercises the `medicine_dose`-sourced id shape
since that's what `sourceId` looks like for a dose action.

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/features/medicine/medicine_module_test.dart`
Expected: FAIL — `medicine_module.dart` doesn't exist.

- [ ] **Step 4: Write `medicine_module.dart`**

```dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/modules/habit_module.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_day.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/repositories/medicine_repository.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_detail_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_form_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_home_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_list_screen.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_stats_screen.dart';

/// The Medicine module's [HabitModule] registration
/// (`technical/architecture.md`). Mirrors `WaterModule`'s shape exactly.
class MedicineModule implements HabitModule {
  /// Creates the module backed by [_repository].
  const MedicineModule(this._repository);

  final MedicineRepository _repository;

  @override
  String get id => 'medicine';

  @override
  ModuleMetadata get metadata => const ModuleMetadata(
    displayName: 'Medicine',
    icon: Icons.medication,
    accentColor: ModuleAccents.medicine,
  );

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/medicine',
      builder: (context, state) => const MedicineHomeScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => const MedicineFormScreen(),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => MedicineDetailScreen(
            medicineId: state.pathParameters['id']!,
          ),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => MedicineFormScreen(
                editMedicineId: state.pathParameters['id'],
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'dose/:id',
          builder: (context, state) => MedicineHomeScreen(
            highlightDoseId: state.pathParameters['id'],
          ),
        ),
        GoRoute(
          path: 'stats',
          builder: (context, state) => const MedicineStatsScreen(),
        ),
      ],
    ),
  ];

  @override
  Widget dashboardSummary(WidgetRef ref) {
    final views = ref.watch(todaysDoseViewsProvider);
    if (views == null) return const SizedBox.shrink();
    final dueOrUpcoming = views
        .where(
          (v) =>
              v.effectiveStatus == MedicineDoseStatus.due ||
              v.effectiveStatus == MedicineDoseStatus.upcoming,
        )
        .toList();
    return Builder(
      builder: (context) => Card(
        child: ListTile(
          leading: const Icon(Icons.medication, color: ModuleAccents.medicine),
          title: Text(metadata.displayName),
          subtitle: Text(
            dueOrUpcoming.isEmpty
                ? 'All doses done for today'
                : '${dueOrUpcoming.first.medicine.name} next',
          ),
          onTap: () => context.go('/medicine'),
        ),
      ),
    );
  }

  @override
  Widget? settingsEntry(WidgetRef ref) => null; // no medicine_settings table

  /// Matches `core/notifications`' own materialization window
  /// (`strategies/notifications.md`'s "Window 2") — same constant/
  /// reasoning as `WaterModule._lookaheadDays`.
  static const _lookaheadDays = 3;

  /// D-13's "topped up on app foreground and via a daily background
  /// refresh" is exactly what `core/notifications`' existing triggers
  /// (`main.dart` resume, the WorkManager top-up) already do — both call
  /// this method, so materializing here needs no new call site anywhere
  /// else in the app.
  @override
  Future<List<PendingNotification>> pendingNotifications() async {
    final now = clock.now();
    await _repository.materializeDoses(now);

    final windowEnd = localDayKey(now).addDays(_lookaheadDays);
    final doses = await _repository.dosesInRange(
      localDayKey(now),
      windowEnd,
    );
    final notifications = <PendingNotification>[];
    for (final dose in doses) {
      if (dose.storedStatus != MedicineDoseStatus.upcoming) continue;
      if (!dose.scheduledFor.isAfter(now)) continue;
      final medicine = await _repository.medicineById(dose.medicineId);
      if (medicine == null) continue;
      notifications.add(
        PendingNotification(
          id: 'medicine_dose_${dose.id}',
          scheduledAt: dose.scheduledFor,
          title: medicine.name,
          body: medicine.dosageNote ?? 'Time for your dose',
          sourceType: 'medicine_dose',
          deepLinkRoute: '/medicine/dose/${dose.id}',
        ),
      );
    }

    final lowStockMedicines = await _repository.medicinesNeedingLowStockAlert();
    for (final medicine in lowStockMedicines) {
      final crossedAt = medicine.lowStockNotifiedAt;
      if (crossedAt == null) continue;
      notifications.add(
        PendingNotification(
          // Stable per-crossing: the timestamp only changes when a
          // refill clears and a later crossing re-sets it, so this
          // naturally dedupes against the ledger across repeated
          // planning passes for the same crossing.
          id: 'medicine_lowstock_${medicine.id}_${crossedAt.millisecondsSinceEpoch}',
          scheduledAt: now.add(const Duration(minutes: 1)),
          title: '${medicine.name} is running low',
          body: 'Refill soon to keep your schedule on track.',
          sourceType: 'low_stock',
          deepLinkRoute: '/medicine/${medicine.id}',
        ),
      );
    }
    return notifications;
  }

  @override
  Future<void> onNotificationAction(
    String sourceId,
    NotificationActionType action,
  ) async {
    if (!sourceId.startsWith('medicine_dose_')) {
      return; // low-stock notifications have no dose to act on
    }
    final doseId = sourceId.substring('medicine_dose_'.length);
    switch (action) {
      case NotificationActionType.done:
        await _repository.markDoseDone(doseId, fromOtherSource: false);
      case NotificationActionType.skip:
        await _repository.markDoseSkipped(doseId);
      case NotificationActionType.snooze:
        break; // streak-neutral, same precedent as Water; snooze-count
        // cap enforced by the existing ledger logic, not duplicated here.
    }
  }

  @override
  Future<ModuleExport> exportData() async {
    final medicines = await _repository.allMedicines();
    final schedules = await _repository.allSchedules();
    return ModuleExport({
      'medicines': medicines.map(_medicineToJson).toList(),
      'schedules': schedules.map(_scheduleToJson).toList(),
    });
  }

  @override
  Future<void> importData(ModuleExport data) async {
    final medicineIdMap = <String, String>{};
    final medicines = (data.payload['medicines'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final json in medicines) {
      final result = await _repository.createMedicine(
        name: json['name'] as String,
        dosageNote: json['dosageNote'] as String?,
        stockEnabled: json['stockEnabled'] as bool,
        stockCount: json['stockCount'] as int?,
        stockThreshold: json['stockThreshold'] as int?,
        stopWhenStockDepleted: json['stopWhenStockDepleted'] as bool,
        consumptionPerDose: json['consumptionPerDose'] as int,
      );
      if (result case Success(:final value)) {
        medicineIdMap[json['id'] as String] = value.id;
      }
    }
    final schedules = (data.payload['schedules'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final json in schedules) {
      final newMedicineId = medicineIdMap[json['medicineId'] as String];
      if (newMedicineId == null) continue;
      await _repository.createSchedule(
        medicineId: newMedicineId,
        rule: _ruleFromJson(json),
        startDate: LocalDate.parse(json['startDate'] as String),
        endDate: json['endDate'] == null
            ? null
            : LocalDate.parse(json['endDate'] as String),
        graceWindowMinutes: json['graceWindowMinutes'] as int,
      );
    }
    await _repository.materializeDoses(clock.now());
  }

  Map<String, Object?> _medicineToJson(Medicine medicine) => {
    'id': medicine.id,
    'name': medicine.name,
    'dosageNote': medicine.dosageNote,
    'stockEnabled': medicine.stockEnabled,
    'stockCount': medicine.stockCount,
    'stockThreshold': medicine.stockThreshold,
    'stopWhenStockDepleted': medicine.stopWhenStockDepleted,
    'consumptionPerDose': medicine.consumptionPerDose,
  };

  Map<String, Object?> _scheduleToJson(MedicineSchedule schedule) => {
    'medicineId': schedule.medicineId,
    'frequencyType': schedule.rule.toDbFrequencyType(),
    'intervalDays': schedule.rule.toDbIntervalDays(),
    'weekdaysMask': schedule.rule.toDbWeekdaysMask(),
    'timesOfDay': schedule.rule.toDbTimesOfDay().map((t) => t.format()).toList(),
    'startDate': schedule.startDate.toIso(),
    'endDate': schedule.endDate?.toIso(),
    'graceWindowMinutes': schedule.graceWindowMinutes,
  };

  RepeatRule _ruleFromJson(Map<String, dynamic> json) {
    final times = (json['timesOfDay'] as List<dynamic>)
        .cast<String>()
        .map(LocalTime.parse)
        .toList();
    return switch (json['frequencyType'] as String) {
      'every_n_days' => RepeatRule.everyNDays(
        intervalDays: json['intervalDays'] as int,
        timesOfDay: times,
      ),
      'weekday_set' => RepeatRule.weekdaySet(
        weekdaysMask: json['weekdaysMask'] as int,
        timesOfDay: times,
      ),
      'prn' => const RepeatRule.prn(),
      _ => RepeatRule.fixedDaily(timesOfDay: times),
    };
  }
}
```

This needs `RepeatRuleDb`'s extension methods (`toDbFrequencyType()` etc.,
Task 9) — add
`import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';`
and `import 'package:habit_tracker/core/error/result.dart';` and
`import 'package:habit_tracker/core/utils/local_date.dart';` alongside
the imports already listed above.

- [ ] **Step 5: Run the module test**

Run: `flutter test test/features/medicine/medicine_module_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Register in `module_registry.dart`**

In `lib/core/modules/module_registry.dart`, add the import and replace
the `// NEW MODULE GOES HERE` comment:

```dart
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/medicine_module.dart';
```

```dart
List<HabitModule> buildHabitModules(AppDatabase db) {
  return [
    MedicineModule(MedicineRepositoryImpl(db)),
    WaterModule(WaterRepositoryImpl(db)),
  ];
}
```

- [ ] **Step 7: Wire the real routes into `app_router.dart`**

In `lib/core/router/app_router.dart`, remove the
`import 'package:habit_tracker/features/medicine/presentation/screens/medicine_home_screen.dart';`
import and the placeholder `MedicineHomeScreen()` branch; mirror how
Water's branch is built:

```dart
  final waterRoutes = modules.firstWhere((m) => m.id == 'water').routes;
  final medicineRoutes = modules.firstWhere((m) => m.id == 'medicine').routes;
```

and replace the Medicine `StatefulShellBranch` body with:

```dart
          StatefulShellBranch(routes: medicineRoutes),
```

- [ ] **Step 8: Register the Android notification channel**

In `lib/core/notifications/notification_service.dart`, add a `medicine`
entry to `notificationChannels`:

```dart
const Map<String, AndroidNotificationChannel> notificationChannels = {
  'water': AndroidNotificationChannel(
    'water_reminders',
    'Water reminders',
    description: 'Reminders to log your water intake',
  ),
  'medicine': AndroidNotificationChannel(
    'medicine_reminders',
    'Medicine reminders',
    description: 'Reminders to take your medicine and low-stock alerts',
  ),
};
```

- [ ] **Step 9: Verify the app compiles and analyzes clean**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/features/medicine/medicine_module.dart lib/features/medicine/presentation/screens/ test/features/medicine/medicine_module_test.dart lib/core/modules/module_registry.dart lib/core/router/app_router.dart lib/core/notifications/notification_service.dart
git commit -m "feat(medicine): HabitModule registration, notification wiring, and routing"
```

---

### Task 14: Medicine home screen (today's dose timeline)

**Files:**
- Modify: `lib/features/medicine/presentation/screens/medicine_home_screen.dart` (replaces Task 13's stub)
- Create: `lib/features/medicine/presentation/widgets/dose_tile.dart`
- Test: `test/features/medicine/presentation/medicine_home_screen_test.dart`

**Interfaces:**
- Consumes: `todaysDoseViewsProvider`, `MedicineDoseView`
  (`medicine_providers.dart`, Task 12), `medicineControllerProvider`
  (Task 12).
- Produces: `DoseTile` widget, the real `MedicineHomeScreen`.

- [ ] **Step 1: Write the failing widget test (testing.md suite 10)**

```dart
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/data/repositories/medicine_repository_impl.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/presentation/screens/medicine_home_screen.dart';

Future<void> _pumpMedicineHome(
  WidgetTester tester,
  AppDatabase db, {
  required DateTime now,
}) async {
  await withClock(Clock.fixed(now), () async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MedicineHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('empty state: no medicines yet', (tester) async {
    final now = DateTime.utc(2026, 6, 1, 8);
    await _pumpMedicineHome(tester, db, now: now);

    expect(find.text('No doses scheduled for today'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('populated state: shows an upcoming dose tile', (tester) async {
    final now = DateTime.utc(2026, 6, 1, 7);
    final repo = MedicineRepositoryImpl(db);
    final medicine = await repo.createMedicine(name: 'Amoxicillin', stockEnabled: false);
    await repo.createSchedule(
      medicineId: (medicine as Success<Medicine>).value.id,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(now), () async {
      await repo.materializeDoses(clock.now());
    });

    await _pumpMedicineHome(tester, db, now: now);

    expect(find.text('Amoxicillin'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('overdue (missed) dose is visually distinct', (tester) async {
    final repo = MedicineRepositoryImpl(db);
    final medicine = await repo.createMedicine(name: 'Ibuprofen', stockEnabled: false);
    await repo.createSchedule(
      medicineId: (medicine as Success<Medicine>).value.id,
      rule: const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
      startDate: const LocalDate(2026, 6, 1),
    );
    await withClock(Clock.fixed(DateTime.utc(2026, 6, 1, 7)), () async {
      await repo.materializeDoses(clock.now());
    });

    // Now well past the grace window -> missed.
    final now = DateTime.utc(2026, 6, 1, 10);
    await _pumpMedicineHome(tester, db, now: now);

    expect(find.text('Missed'), findsOneWidget);
    await disposeTree(tester);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/medicine/presentation/medicine_home_screen_test.dart`
Expected: FAIL — the real screen/widget don't exist yet (Task 13's stub
renders a bare `Placeholder`).

- [ ] **Step 3: Write `dose_tile.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:intl/intl.dart';

/// One row in the today's-dose timeline.
class DoseTile extends StatelessWidget {
  /// Creates a dose tile for [view].
  const DoseTile({
    required this.view,
    required this.onDone,
    required this.onSkip,
    this.highlighted = false,
    super.key,
  });

  /// The dose/medicine/status to render.
  final MedicineDoseView view;

  /// Called when the user marks this dose done.
  final VoidCallback onDone;

  /// Called when the user marks this dose skipped.
  final VoidCallback onSkip;

  /// Whether this tile arrived from a notification deep link.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final (label, color) = switch (view.effectiveStatus) {
      MedicineDoseStatus.upcoming => ('Upcoming', theme.colorScheme.outline),
      MedicineDoseStatus.due => ('Due', theme.colorScheme.primary),
      MedicineDoseStatus.done => ('Done', semantic.success),
      MedicineDoseStatus.missed => ('Missed', theme.colorScheme.error),
      MedicineDoseStatus.skipped => ('Skipped', theme.colorScheme.outline),
    };
    final resolved = view.effectiveStatus == MedicineDoseStatus.done ||
        view.effectiveStatus == MedicineDoseStatus.skipped;

    return Card(
      color: highlighted ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.medication, color: color),
        ),
        title: Text(view.medicine.name),
        subtitle: Text(
          '${DateFormat.jm().format(view.dose.scheduledFor.toLocal())} · $label',
        ),
        trailing: resolved
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Skip',
                    onPressed: onSkip,
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: 'Done',
                    onPressed: onDone,
                  ),
                ],
              ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write the real `medicine_home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_controller.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:habit_tracker/features/medicine/presentation/widgets/dose_tile.dart';

/// The Medicine module's home screen: today's dose timeline, grouped
/// chronologically, tap to take/skip (FR-M-02's most complex UI surface).
class MedicineHomeScreen extends ConsumerWidget {
  /// Creates the medicine home screen. [highlightDoseId], if set, came
  /// from a notification tap deep link (FR-C-09).
  const MedicineHomeScreen({super.key, this.highlightDoseId});

  /// Dose id to visually highlight, if opened via deep link.
  final String? highlightDoseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final views = ref.watch(todaysDoseViewsProvider);
    final controller = ref.read(medicineControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMedicine),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'All medicines',
            onPressed: () => context.push('/medicine/list'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Stats',
            onPressed: () => context.push('/medicine/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add medicine',
            onPressed: () => context.push('/medicine/new'),
          ),
        ],
      ),
      body: views == null
          ? const Center(child: CircularProgressIndicator())
          : views.isEmpty
          ? const Center(child: Text('No doses scheduled for today'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final view in views)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DoseTile(
                      view: view,
                      highlighted: view.dose.id == highlightDoseId,
                      onDone: () => controller.markDoseDone(view.dose.id),
                      onSkip: () => controller.markDoseSkipped(view.dose.id),
                    ),
                  ),
              ],
            ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/medicine/presentation/medicine_home_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/medicine/presentation/screens/medicine_home_screen.dart lib/features/medicine/presentation/widgets/dose_tile.dart test/features/medicine/presentation/medicine_home_screen_test.dart
git commit -m "feat(medicine): dose timeline home screen"
```

---

### Task 15: Medicine list screen

**Files:**
- Modify: `lib/features/medicine/presentation/screens/medicine_list_screen.dart` (replaces Task 13's stub)

**Interfaces:**
- Consumes: `medicinesProvider({required bool includeArchived})`
  (Task 12).

- [ ] **Step 1: Write the screen (no dedicated widget test — this screen
  is straightforward list rendering over an already-tested provider;
  testing.md's suite-10 budget was spent on the denser home-screen
  timeline in Task 14, and DoD's manual script covers this screen)**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';

/// Lists every medicine, active and archived, in two tabs (FR-M-10).
class MedicineListScreen extends ConsumerStatefulWidget {
  /// Creates the medicine list screen.
  const MedicineListScreen({super.key});

  @override
  ConsumerState<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends ConsumerState<MedicineListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicines'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Active'), Tab(text: 'Archived')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MedicineListView(includeArchived: false),
          _MedicineListView(includeArchived: true, archivedOnly: true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/medicine/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MedicineListView extends ConsumerWidget {
  const _MedicineListView({required this.includeArchived, this.archivedOnly = false});

  final bool includeArchived;
  final bool archivedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicines = ref.watch(medicinesProvider(includeArchived: includeArchived)).value;
    if (medicines == null) return const Center(child: CircularProgressIndicator());
    final filtered = archivedOnly
        ? medicines.where((m) => m.archivedAt != null).toList()
        : medicines;
    if (filtered.isEmpty) {
      return Center(child: Text(archivedOnly ? 'No archived medicines' : 'No medicines yet'));
    }
    return ListView(
      children: [
        for (final medicine in filtered)
          ListTile(
            leading: const Icon(Icons.medication),
            title: Text(medicine.name),
            subtitle: medicine.dosageNote == null ? null : Text(medicine.dosageNote!),
            onTap: () => context.push('/medicine/${medicine.id}'),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Add the `/medicine/list` route**

Add to `medicine_module.dart`'s `routes` (Task 13), as a sibling of
`new`/`stats`:

```dart
        GoRoute(
          path: 'list',
          builder: (context, state) => const MedicineListScreen(),
        ),
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/features/medicine/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/medicine/presentation/screens/medicine_list_screen.dart lib/features/medicine/medicine_module.dart
git commit -m "feat(medicine): medicine list screen (active/archived)"
```

---

### Task 16: Medicine add/edit form (multi-step)

**Files:**
- Modify: `lib/features/medicine/presentation/screens/medicine_form_screen.dart` (replaces Task 13's stub)

**Interfaces:**
- Consumes: `medicineControllerProvider` (Task 12), `medicineByIdProvider`
  (Task 12), `RepeatRule` (Task 1).

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_controller.dart';

/// Adds (or, once `editMedicineId` is set, will edit — full edit support
/// beyond the initial schedule is Task 17's detail-screen "add schedule"
/// action) a medicine, in three simple steps: details, dosage/stock,
/// schedule. FR-M-01.
class MedicineFormScreen extends ConsumerStatefulWidget {
  /// Creates the medicine form screen. [editMedicineId] is reserved for
  /// future in-place editing of a medicine's own fields; this run's form
  /// only handles creation (editing a medicine's name/stock happens from
  /// the detail screen, Task 17).
  const MedicineFormScreen({super.key, this.editMedicineId});

  /// Unused this run — see class doc.
  final String? editMedicineId;

  @override
  ConsumerState<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends ConsumerState<MedicineFormScreen> {
  final _pageController = PageController();
  int _step = 0;

  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  bool _stockEnabled = false;
  final _stockCountController = TextEditingController();
  final _stockThresholdController = TextEditingController();

  RepeatRule _rule = const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]);

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _dosageController.dispose();
    _stockCountController.dispose();
    _stockThresholdController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0 && _nameController.text.trim().isEmpty) return;
    setState(() => _step += 1);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _save() async {
    await ref.read(medicineControllerProvider.notifier).createMedicine(
      name: _nameController.text.trim(),
      dosageNote: _dosageController.text.trim().isEmpty
          ? null
          : _dosageController.text.trim(),
      stockEnabled: _stockEnabled,
      stockCount: _stockEnabled ? int.tryParse(_stockCountController.text) : null,
      stockThreshold: _stockEnabled
          ? int.tryParse(_stockThresholdController.text)
          : null,
      rule: _rule,
      startDate: LocalDate.fromDateTime(DateTime.now()),
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add medicine'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / 3),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _DetailsStep(nameController: _nameController, dosageController: _dosageController),
          _StockStep(
            stockEnabled: _stockEnabled,
            onStockEnabledChanged: (v) => setState(() => _stockEnabled = v),
            stockCountController: _stockCountController,
            stockThresholdController: _stockThresholdController,
          ),
          _ScheduleStep(rule: _rule, onRuleChanged: (r) => setState(() => _rule = r)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _step < 2 ? _nextStep : _save,
            child: Text(_step < 2 ? 'Next' : 'Save'),
          ),
        ),
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({required this.nameController, required this.dosageController});

  final TextEditingController nameController;
  final TextEditingController dosageController;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: dosageController,
          decoration: const InputDecoration(labelText: 'Dosage note (optional)'),
        ),
      ],
    ),
  );
}

class _StockStep extends StatelessWidget {
  const _StockStep({
    required this.stockEnabled,
    required this.onStockEnabledChanged,
    required this.stockCountController,
    required this.stockThresholdController,
  });

  final bool stockEnabled;
  final ValueChanged<bool> onStockEnabledChanged;
  final TextEditingController stockCountController;
  final TextEditingController stockThresholdController;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        SwitchListTile(
          title: const Text('Track stock'),
          value: stockEnabled,
          onChanged: onStockEnabledChanged,
        ),
        if (stockEnabled) ...[
          TextField(
            controller: stockCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Current stock count'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: stockThresholdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Low-stock threshold'),
          ),
        ],
      ],
    ),
  );
}

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({required this.rule, required this.onRuleChanged});

  final RepeatRule rule;
  final ValueChanged<RepeatRule> onRuleChanged;

  @override
  Widget build(BuildContext context) {
    final selected = switch (rule) {
      FixedDailyRule() => 0,
      EveryNDaysRule() => 1,
      WeekdaySetRule() => 2,
      PrnRule() => 3,
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How often?'),
          RadioListTile<int>(
            title: const Text('Fixed times daily'),
            value: 0,
            groupValue: selected,
            onChanged: (_) => onRuleChanged(
              const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
            ),
          ),
          RadioListTile<int>(
            title: const Text('Every other day'),
            value: 1,
            groupValue: selected,
            onChanged: (_) => onRuleChanged(
              const RepeatRule.everyNDays(
                intervalDays: 2,
                timesOfDay: [LocalTime(8, 0)],
              ),
            ),
          ),
          RadioListTile<int>(
            title: const Text('Specific weekdays'),
            value: 2,
            groupValue: selected,
            onChanged: (_) => onRuleChanged(
              const RepeatRule.weekdaySet(
                weekdaysMask: 0x7F,
                timesOfDay: [LocalTime(8, 0)],
              ),
            ),
          ),
          RadioListTile<int>(
            title: const Text('As needed (PRN)'),
            value: 3,
            groupValue: selected,
            onChanged: (_) => onRuleChanged(const RepeatRule.prn()),
          ),
        ],
      ),
    );
  }
}
```

`ponytail:` the time-of-day/weekday picker UI is a single default value
per pattern (8am, all-7-days) rather than a full per-time editor — add a
time-of-day chip editor when a real user reports 8am doesn't fit their
schedule; the domain layer (`RepeatRule.timesOfDay` is already a list)
already supports it, only this form's UI is simplified.

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/medicine/presentation/screens/medicine_form_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/medicine/presentation/screens/medicine_form_screen.dart
git commit -m "feat(medicine): add-medicine multi-step form"
```

---

### Task 17: Medicine detail screen (7-day preview, stock, adherence)

**Files:**
- Modify: `lib/features/medicine/presentation/screens/medicine_detail_screen.dart` (replaces Task 13's stub)
- Create: `lib/features/medicine/presentation/widgets/stock_card.dart`

**Interfaces:**
- Consumes: `medicineByIdProvider`, `medicineSchedulesProvider`
  (Task 12), `expandRepeatRule` (Task 2), `calculateAdherence` (Task 7),
  `medicineControllerProvider.refillStock` (Task 12).

- [ ] **Step 1: Write `stock_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine.dart';

/// Stock level + refill action (FR-M-04).
class StockCard extends StatelessWidget {
  /// Creates a stock card for [medicine].
  const StockCard({required this.medicine, required this.onRefill, super.key});

  /// The medicine whose stock this card shows.
  final Medicine medicine;

  /// Called with the amount to add when the user confirms a refill.
  final ValueChanged<int> onRefill;

  @override
  Widget build(BuildContext context) {
    if (!medicine.stockEnabled) return const SizedBox.shrink();
    final low = medicine.stockThreshold != null &&
        (medicine.stockCount ?? 0) <= medicine.stockThreshold!;
    return Card(
      color: low ? Theme.of(context).colorScheme.errorContainer : null,
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text('${medicine.stockCount ?? 0} remaining'),
        subtitle: low ? const Text('Low stock — refill soon') : null,
        trailing: TextButton(
          onPressed: () => _showRefillDialog(context),
          child: const Text('Refill'),
        ),
      ),
    );
  }

  Future<void> _showRefillDialog(BuildContext context) async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add stock'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0) onRefill(amount);
  }
}
```

- [ ] **Step 2: Write `medicine_detail_screen.dart`**

```dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/calculate_adherence.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/expand_repeat_rule.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_controller.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:habit_tracker/features/medicine/presentation/widgets/stock_card.dart';
import 'package:intl/intl.dart';

/// A medicine's detail screen: 7-day schedule preview (computed directly
/// via `expandRepeatRule`, not a DB read — cheaper than materializing
/// just to render a preview), stock/refill, adherence.
class MedicineDetailScreen extends ConsumerWidget {
  /// Creates the detail screen for [medicineId].
  const MedicineDetailScreen({required this.medicineId, super.key});

  /// The medicine to show.
  final String medicineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicine = ref.watch(medicineByIdProvider(medicineId)).value;
    final schedules = ref.watch(medicineSchedulesProvider(medicineId)).value;
    final controller = ref.read(medicineControllerProvider.notifier);

    if (medicine == null || schedules == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final today = LocalDate.fromDateTime(clock.now());
    final previewEnd = today.addDays(6);
    final previewInstants = <DateTime>[
      for (final schedule in schedules)
        ...expandRepeatRule(
          rule: schedule.rule,
          anchor: schedule.startDate,
          rangeStart: schedule.startDate.compareTo(today) > 0 ? schedule.startDate : today,
          rangeEnd: schedule.endDate == null
              ? previewEnd
              : (schedule.endDate!.compareTo(previewEnd) < 0
                    ? schedule.endDate!
                    : previewEnd),
        ),
    ]..sort();

    final dosesAsync = ref.watch(
      medicineRepositoryProvider,
    ); // repository read for adherence below

    return Scaffold(
      appBar: AppBar(
        title: Text(medicine.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/medicine/$medicineId/edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (medicine.dosageNote != null) Text(medicine.dosageNote!),
          const SizedBox(height: 8),
          StockCard(
            medicine: medicine,
            onRefill: (amount) => controller.refillStock(medicineId, amount),
          ),
          const SizedBox(height: 16),
          Text('Next 7 days', style: Theme.of(context).textTheme.titleMedium),
          for (final instant in previewInstants)
            ListTile(
              dense: true,
              leading: const Icon(Icons.event_outlined),
              title: Text(DateFormat.MMMEd().add_jm().format(instant.toLocal())),
            ),
          const SizedBox(height: 16),
          FutureBuilder<AdherenceStats>(
            future: dosesAsync
                .dosesInRange(today.addDays(-30), today)
                .then((doses) => calculateAdherence(doses: doses, now: clock.now())),
            builder: (context, snapshot) {
              final stats = snapshot.data;
              if (stats == null) return const SizedBox.shrink();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    stats.total == 0
                        ? 'No dose history yet'
                        : 'Last 30 days: '
                              '${((stats.takenOnTime + stats.takenLate) / stats.total * 100).round()}% taken '
                              '(${stats.missed} missed, ${stats.skipped} skipped)',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/features/medicine/presentation/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/medicine/presentation/screens/medicine_detail_screen.dart lib/features/medicine/presentation/widgets/stock_card.dart
git commit -m "feat(medicine): detail screen with 7-day preview, stock card, adherence"
```

---

### Task 18: Medicine stats screen

**Files:**
- Modify: `lib/features/medicine/presentation/screens/medicine_stats_screen.dart` (replaces Task 13's stub)

**Interfaces:**
- Consumes: `medicinesProvider`, `medicineRepositoryProvider` (Task 12),
  `calculateAdherence` (Task 7), `PeriodBarChart`/`BarChartPoint`
  (`core/widgets/charts/period_bar_chart.dart`, existing).

- [ ] **Step 1: Write the screen**

```dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/core/widgets/charts/period_bar_chart.dart';
import 'package:habit_tracker/features/medicine/domain/entities/medicine_dose.dart';
import 'package:habit_tracker/features/medicine/domain/usecases/dose_status.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_providers.dart';
import 'package:intl/intl.dart';

/// Adherence chart across all medicines over the last 7 days, plus a
/// missed-doses list (FR-M-08).
class MedicineStatsScreen extends ConsumerWidget {
  /// Creates the medicine stats screen.
  const MedicineStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(medicineRepositoryProvider);
    final today = LocalDate.fromDateTime(clock.now());
    final start = today.addDays(-6);

    return Scaffold(
      appBar: AppBar(title: const Text('Medicine stats')),
      body: FutureBuilder<List<MedicineDose>>(
        future: repository.dosesInRange(start, today),
        builder: (context, snapshot) {
          final doses = snapshot.data;
          if (doses == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final now = clock.now();
          final byDay = <LocalDate, int>{};
          final missed = <MedicineDose>[];
          for (final dose in doses) {
            final status = effectiveDoseStatus(
              storedStatus: dose.storedStatus,
              scheduledFor: dose.scheduledFor,
              now: now,
              graceWindowMinutes: dose.graceWindowMinutes,
            );
            if (status == MedicineDoseStatus.done) {
              final day = LocalDate.fromDateTime(dose.scheduledFor.toLocal());
              byDay[day] = (byDay[day] ?? 0) + 1;
            } else if (status == MedicineDoseStatus.missed) {
              missed.add(dose);
            }
          }
          final points = [
            for (var i = 0; i <= 6; i++)
              BarChartPoint(
                label: DateFormat.E().format(start.addDays(i).toDateTimeUtc()),
                value: (byDay[start.addDays(i)] ?? 0).toDouble(),
              ),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Doses taken, last 7 days', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              PeriodBarChart(points: points, color: ModuleAccents.medicine),
              const SizedBox(height: 24),
              Text('Missed doses', style: Theme.of(context).textTheme.titleMedium),
              if (missed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('None — great adherence!'),
                )
              else
                for (final dose in missed)
                  ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(DateFormat.MMMEd().add_jm().format(dose.scheduledFor.toLocal())),
                  ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/medicine/presentation/screens/medicine_stats_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/medicine/presentation/screens/medicine_stats_screen.dart
git commit -m "feat(medicine): stats screen with adherence chart and missed-doses list"
```

---

### Task 19: Localization (en + bn)

**Files:**
- Modify: `lib/core/l10n/app_en.arb`
- Modify: `lib/core/l10n/app_bn.arb`
- Modify: every screen from Tasks 14-18 that currently uses a hardcoded
  English string (replace with `AppLocalizations.of(context)!.<key>`)

**Interfaces:**
- Produces: `medicineHome*`, `medicineList*`, `medicineForm*`,
  `medicineDetail*`, `medicineStats*` keys, following the exact
  `water*`-key convention already in `app_en.arb`.

- [ ] **Step 1: Add English keys to `app_en.arb`**

Add these entries (alongside the existing `water*` block, same
`"key": "value"` + `"@key": {"description": "..."}` pairing style):

```json
  "medicineHomeEmpty": "No doses scheduled for today",
  "@medicineHomeEmpty": {
    "description": "Shown on the medicine home screen when there are no doses today."
  },
  "medicineHomeAllMedicinesButton": "All medicines",
  "@medicineHomeAllMedicinesButton": {
    "description": "Button/icon that navigates to the medicine list screen."
  },
  "medicineHomeStatsButton": "Stats",
  "@medicineHomeStatsButton": {
    "description": "Button/icon that navigates to the medicine stats screen."
  },
  "medicineHomeAddButton": "Add medicine",
  "@medicineHomeAddButton": {
    "description": "Button/icon that navigates to the add-medicine form."
  },
  "medicineDoseStatusUpcoming": "Upcoming",
  "@medicineDoseStatusUpcoming": {
    "description": "Label for a dose not yet due."
  },
  "medicineDoseStatusDue": "Due",
  "@medicineDoseStatusDue": {
    "description": "Label for a dose within its grace window."
  },
  "medicineDoseStatusDone": "Done",
  "@medicineDoseStatusDone": {
    "description": "Label for a dose marked taken."
  },
  "medicineDoseStatusMissed": "Missed",
  "@medicineDoseStatusMissed": {
    "description": "Label for a dose past its grace window, unactioned."
  },
  "medicineDoseStatusSkipped": "Skipped",
  "@medicineDoseStatusSkipped": {
    "description": "Label for a dose explicitly skipped."
  },
  "medicineListTitle": "Medicines",
  "@medicineListTitle": {
    "description": "Title of the medicine list screen."
  },
  "medicineListActiveTab": "Active",
  "@medicineListActiveTab": {
    "description": "Tab label for active medicines."
  },
  "medicineListArchivedTab": "Archived",
  "@medicineListArchivedTab": {
    "description": "Tab label for archived medicines."
  },
  "medicineListEmpty": "No medicines yet",
  "@medicineListEmpty": {
    "description": "Shown when the active medicines list is empty."
  },
  "medicineListArchivedEmpty": "No archived medicines",
  "@medicineListArchivedEmpty": {
    "description": "Shown when the archived medicines list is empty."
  },
  "medicineFormTitle": "Add medicine",
  "@medicineFormTitle": {
    "description": "Title of the add-medicine form."
  },
  "medicineFormNameLabel": "Name",
  "@medicineFormNameLabel": {
    "description": "Label for the medicine name field."
  },
  "medicineFormDosageLabel": "Dosage note (optional)",
  "@medicineFormDosageLabel": {
    "description": "Label for the free-text dosage note field."
  },
  "medicineFormTrackStockLabel": "Track stock",
  "@medicineFormTrackStockLabel": {
    "description": "Switch label enabling stock tracking."
  },
  "medicineFormStockCountLabel": "Current stock count",
  "@medicineFormStockCountLabel": {
    "description": "Label for the current stock count field."
  },
  "medicineFormStockThresholdLabel": "Low-stock threshold",
  "@medicineFormStockThresholdLabel": {
    "description": "Label for the low-stock threshold field."
  },
  "medicineFormFrequencyLabel": "How often?",
  "@medicineFormFrequencyLabel": {
    "description": "Section label for the repeat-rule picker."
  },
  "medicineFormFrequencyFixedDaily": "Fixed times daily",
  "@medicineFormFrequencyFixedDaily": {
    "description": "Repeat-rule option: fixed times every day."
  },
  "medicineFormFrequencyEveryOtherDay": "Every other day",
  "@medicineFormFrequencyEveryOtherDay": {
    "description": "Repeat-rule option: every 2 days."
  },
  "medicineFormFrequencyWeekdays": "Specific weekdays",
  "@medicineFormFrequencyWeekdays": {
    "description": "Repeat-rule option: a set of weekdays."
  },
  "medicineFormFrequencyPrn": "As needed (PRN)",
  "@medicineFormFrequencyPrn": {
    "description": "Repeat-rule option: no fixed schedule."
  },
  "medicineFormNextButton": "Next",
  "@medicineFormNextButton": {
    "description": "Advances to the next form step."
  },
  "medicineFormSaveButton": "Save",
  "@medicineFormSaveButton": {
    "description": "Saves the new medicine."
  },
  "medicineDetailNext7DaysLabel": "Next 7 days",
  "@medicineDetailNext7DaysLabel": {
    "description": "Section header for the schedule preview."
  },
  "medicineDetailStockRemaining": "{count} remaining",
  "@medicineDetailStockRemaining": {
    "description": "Current stock count display.",
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "medicineDetailLowStockWarning": "Low stock — refill soon",
  "@medicineDetailLowStockWarning": {
    "description": "Shown when stock is at or below the low-stock threshold."
  },
  "medicineDetailRefillButton": "Refill",
  "@medicineDetailRefillButton": {
    "description": "Opens the add-stock dialog."
  },
  "medicineStatsTitle": "Medicine stats",
  "@medicineStatsTitle": {
    "description": "Title of the medicine stats screen."
  },
  "medicineStatsDosesTakenLabel": "Doses taken, last 7 days",
  "@medicineStatsDosesTakenLabel": {
    "description": "Section header for the adherence chart."
  },
  "medicineStatsMissedDosesLabel": "Missed doses",
  "@medicineStatsMissedDosesLabel": {
    "description": "Section header for the missed-doses list."
  },
  "medicineStatsNoMissedDoses": "None — great adherence!",
  "@medicineStatsNoMissedDoses": {
    "description": "Shown when there are no missed doses in range."
  },
```

- [ ] **Step 2: Add matching Bangla keys to `app_bn.arb`**

Add the same key set with Bangla translations, following `app_bn.arb`'s
existing style (values only — no `@key` metadata blocks in that file,
matching how `navMedicine`/other existing bn entries are structured):

```json
  "medicineHomeEmpty": "আজকের জন্য কোনো ডোজ নির্ধারিত নেই",
  "medicineHomeAllMedicinesButton": "সব ওষুধ",
  "medicineHomeStatsButton": "পরিসংখ্যান",
  "medicineHomeAddButton": "ওষুধ যোগ করুন",
  "medicineDoseStatusUpcoming": "আসন্ন",
  "medicineDoseStatusDue": "বাকি",
  "medicineDoseStatusDone": "সম্পন্ন",
  "medicineDoseStatusMissed": "মিস হয়েছে",
  "medicineDoseStatusSkipped": "এড়িয়ে যাওয়া হয়েছে",
  "medicineListTitle": "ওষুধসমূহ",
  "medicineListActiveTab": "সক্রিয়",
  "medicineListArchivedTab": "আর্কাইভ করা",
  "medicineListEmpty": "এখনো কোনো ওষুধ নেই",
  "medicineListArchivedEmpty": "আর্কাইভ করা কোনো ওষুধ নেই",
  "medicineFormTitle": "ওষুধ যোগ করুন",
  "medicineFormNameLabel": "নাম",
  "medicineFormDosageLabel": "ডোজ নোট (ঐচ্ছিক)",
  "medicineFormTrackStockLabel": "মজুদ ট্র্যাক করুন",
  "medicineFormStockCountLabel": "বর্তমান মজুদ",
  "medicineFormStockThresholdLabel": "কম-মজুদ সীমা",
  "medicineFormFrequencyLabel": "কত ঘন ঘন?",
  "medicineFormFrequencyFixedDaily": "প্রতিদিন নির্দিষ্ট সময়ে",
  "medicineFormFrequencyEveryOtherDay": "একদিন পর পর",
  "medicineFormFrequencyWeekdays": "নির্দিষ্ট সপ্তাহের দিন",
  "medicineFormFrequencyPrn": "প্রয়োজন অনুসারে",
  "medicineFormNextButton": "পরবর্তী",
  "medicineFormSaveButton": "সংরক্ষণ করুন",
  "medicineDetailNext7DaysLabel": "আগামী ৭ দিন",
  "medicineDetailStockRemaining": "{count}টি বাকি",
  "medicineDetailLowStockWarning": "মজুদ কম — শীঘ্রই পুনরায় পূরণ করুন",
  "medicineDetailRefillButton": "পুনরায় পূরণ",
  "medicineStatsTitle": "ওষুধের পরিসংখ্যান",
  "medicineStatsDosesTakenLabel": "গত ৭ দিনে নেওয়া ডোজ",
  "medicineStatsMissedDosesLabel": "মিস হওয়া ডোজ",
  "medicineStatsNoMissedDoses": "কোনোটি নেই — দুর্দান্ত!",
```

- [ ] **Step 3: Generate localizations and wire the keys into the screens**

Run: `flutter gen-l10n`

In each of `medicine_home_screen.dart`, `medicine_list_screen.dart`,
`medicine_form_screen.dart`, `medicine_detail_screen.dart`,
`medicine_stats_screen.dart` (Tasks 14-18), replace every hardcoded
English string literal used in Step 1's key list with
`AppLocalizations.of(context)!.<matchingKey>` (add the `import
'package:habit_tracker/core/l10n/app_localizations.dart';` import to any
file that doesn't already have it). `DoseTile`'s status labels
(`'Upcoming'`/`'Due'`/etc.) become a `switch` on
`AppLocalizations.of(context)!` using the five `medicineDoseStatus*`
keys, same pattern.

- [ ] **Step 4: Re-run the widget/module tests**

Run: `flutter test test/features/medicine/`
Expected: PASS — `medicine_home_screen_test.dart`'s string assertions
(`'No doses scheduled for today'`, `'Missed'`) still match since the en
arb values are unchanged text, just routed through `AppLocalizations` now.

- [ ] **Step 5: Commit**

```bash
git add lib/core/l10n/ lib/features/medicine/presentation/
git commit -m "feat(medicine): en/bn localization"
```

---

### Task 20: Final verification pass

**Files:** none created — verification only.

- [ ] **Step 1: Regenerate all codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: clean regeneration, no conflicts.

- [ ] **Step 2: Full analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Full format check**

Run: `dart format --output=none --set-exit-if-changed .`
Expected: no output (nothing needs reformatting). If it lists files, run
`dart format .` and re-check.

- [ ] **Step 4: Full test suite**

Run: `flutter test`
Expected: all tests pass, including every `test/features/medicine/**`
file from Tasks 2-19 and the pre-existing Water/core suites (unaffected).

- [ ] **Step 5: Manual smoke pass (per the original run's DoD)**

Launch the app (`flutter run`), and walk:
1. Add a medicine with each of the 4 repeat types; confirm the detail
   screen's 7-day preview matches expectation for each.
2. Take/skip a dose from the home screen; confirm stock decrements (if
   enabled) and the tile updates.
3. Wait past a short grace window (or use a schedule with `graceWindow:
   0` and a dose a minute in the past) and confirm it shows "Missed."
4. Drive a medicine's stock to its threshold; confirm the low-stock
   banner appears on the detail screen and a notification arrives within
   the next `pendingNotifications()` cycle (foreground resume triggers
   it immediately).
5. Set a schedule's `endDate` to yesterday; confirm no new doses
   materialize for it.
6. Switch the device/app language to Bangla; confirm every new Medicine
   string renders translated, no layout overflow.

- [ ] **Step 6: Update `CLAUDE.md`'s "Project state" section**

Add a short paragraph (matching the existing style/tense of that
section) noting Medicine is now a complete module registered in
`module_registry.dart`, mirroring how the Water paragraph is written —
write this by hand at commit time based on what actually shipped, not
copied verbatim from this plan.

- [ ] **Step 7: Final commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat(medicine): complete medicine tracking module

Domain (repeat-rule engine, dose-status/stock state machines,
materialization planner, adherence calc), data (4 Drift tables, no-DAO
repository), presentation (dose timeline, list, add form, detail,
stats), and HabitModule/notification wiring — reusing the Run 08
notification engine's existing triggers for dose materialization with
no new call sites.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-review notes (writing-plans skill's mandatory pass)

**Spec coverage:** FR-M-01 (Task 9/16), FR-M-02 (Task 6/10/14), FR-M-03
(Task 1-3), FR-M-04 (Task 5/11/13/17), FR-M-05 (Task 5/11), FR-M-06
(Task 4), FR-M-07 (Task 11/12/13/14), FR-M-08 (Task 7/17/18), FR-M-09
(Task 9's `updateSchedule`), FR-M-10 (Task 9/15) — all covered. D-02
(Task 6), D-03 (Task 2-3), D-04 (Task 4), D-05 (Task 4), D-13 (Task 10,
13), D-14 (Task 2, entities) — all covered.

**Placeholder scan:** no `TODO`/`TBD` left in any step's code. Task 13's
screen stubs are explicitly temporary and explicitly replaced by name in
Tasks 14-18 (not a silently-incomplete placeholder — each is tracked as
that task's own "Modify" file).

**Type consistency:** `MedicineDoseView`, `PlannedDose`,
`StockAdjustment`, `UndoAdjustment`, `AdherenceStats` are each defined
once (Tasks 6/12/5/5/7 respectively) and referenced by identical name/
shape everywhere downstream — verified by re-reading every consuming
task's `Interfaces:` block against its producing task.

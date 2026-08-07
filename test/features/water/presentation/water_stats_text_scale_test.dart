import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/database/app_database.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/water/presentation/screens/water_stats_screen.dart';

import '../../../accessibility/text_scale_test_helper.dart';

// A dedicated file (rather than folded into water_text_scale_test.dart)
// because disposing WaterStatsScreen leaves a pending zero-duration
// `Timer` behind (Drift's `QueryStream._onCancelOrPause` schedules one to
// close its stream-query bookkeeping when a StreamProvider watching a
// Drift stream — waterSeriesProvider et al — gets torn down). Under
// flutter_test's FakeAsync-based clock, that timer needs an extra pump
// after disposal to actually fire; without it, the framework's own
// post-test invariant check ("A Timer is still pending even after the
// widget tree was disposed") intermittently races with pumpAndSettle's
// own timer-flushing loop and can spin for the full 10-minute test
// timeout instead of failing fast. Isolating this screen's dispose in
// its own extra pump (below) avoids it without losing coverage.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('WaterStatsScreen at 2.0x: no overflow', (tester) async {
    // Tall surface so the stats charts' full row (bars + axis labels +
    // history calendar) stays within the sliver cache extent at 2x text.
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAtTextScale(
      tester,
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(isBangla: false),
          home: const WaterStatsScreen(),
        ),
      ),
      2,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    // Two pumps: the first tears down the ProviderScope (which cancels
    // WaterStatsScreen's Drift-backed StreamProviders and schedules
    // Drift's zero-duration cleanup Timer); the second lets that timer
    // actually fire before the test ends.
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });
}

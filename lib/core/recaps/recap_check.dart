import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/recaps/recap_providers.dart';
import 'package:habit_tracker/core/recaps/recap_trigger.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// Checks whether a yearly recap should be shown and triggers generation
/// if needed. Called from the app lifecycle on foreground resume.
Future<void> checkAndShowYearlyRecap(WidgetRef ref) async {
  final settings = await ref.read(appSettingsProvider.future);
  final generator = ref.read(yearRecapGeneratorProvider);
  final db = ref.read(databaseProvider);

  // Read lastRecapYear directly from the DB row (implementation detail,
  // not exposed in the AppSettings domain entity).
  final row =
      await (db.select(db.appSettingsTable)
            ..where((t) => t.id.equals('singleton'))
            ..limit(1))
          .getSingleOrNull();
  final lastRecapYear = row?.lastRecapYear ?? 0;

  final triggerResult = checkYearlyRecapTrigger(
    installDate: settings.installDate,
    lastRecapYear: lastRecapYear,
    now: DateTime.now(),
    recapEnabled: settings.recapEnabled,
  );

  if (triggerResult.action == RecapTriggerAction.showRecap &&
      triggerResult.yearNumber != null) {
    final today = LocalDate.fromDateTime(DateTime.now());
    final profileId = (await ref.read(activeProfileProvider.future)).id;
    await generator.execute(
      triggerResult.yearNumber!,
      today: today,
      profileId: profileId,
    );
  }
}

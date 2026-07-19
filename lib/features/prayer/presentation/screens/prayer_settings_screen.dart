import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_city.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/presentation/prayer_city_labels.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_controller.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';

/// Calculation method, Asr madhab, Jumu'ah toggle, location, reminders,
/// Isha day-rollover time, and the "using manual location" banner (D-09).
class PrayerSettingsScreen extends ConsumerWidget {
  /// Creates the settings screen.
  const PrayerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(prayerSettingsProvider).value;
    final cities = ref.watch(prayerCitiesProvider).value ?? const [];
    final controller = ref.read(prayerControllerProvider.notifier);
    if (settings == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.prayerSettingsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.prayerSettingsTitle)),
      body: ListView(
        children: [
          if (settings.locationMode == LocationMode.manual)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(12),
              child: Text(l10n.prayerSettingsManualLocationBanner),
            ),
          ListTile(
            title: Text(l10n.prayerSettingsMethodLabel),
            trailing: DropdownButton<CalculationMethod>(
              value: settings.calculationMethod,
              items: [
                for (final method in CalculationMethod.values)
                  DropdownMenuItem(
                    value: method,
                    child: Text(_methodLabel(l10n, method)),
                  ),
              ],
              onChanged: (method) {
                if (method != null) {
                  unawaited(
                    controller.updateSettings(calculationMethod: method),
                  );
                }
              },
            ),
          ),
          ListTile(
            title: Text(l10n.prayerSettingsAsrLabel),
            trailing: DropdownButton<AsrMethod>(
              value: settings.asrMethod,
              items: [
                DropdownMenuItem(
                  value: AsrMethod.standard,
                  child: Text(l10n.prayerSettingsAsrStandard),
                ),
                DropdownMenuItem(
                  value: AsrMethod.hanafi,
                  child: Text(l10n.prayerSettingsAsrHanafi),
                ),
              ],
              onChanged: (method) {
                if (method != null) {
                  unawaited(controller.updateSettings(asrMethod: method));
                }
              },
            ),
          ),
          SwitchListTile(
            title: Text(l10n.prayerSettingsJumuahLabel),
            value: settings.observesJumuah,
            onChanged: (value) =>
                controller.updateSettings(observesJumuah: value),
          ),
          ListTile(
            title: Text(l10n.prayerSettingsLocationModeLabel),
            trailing: DropdownButton<LocationMode>(
              value: settings.locationMode,
              items: [
                DropdownMenuItem(
                  value: LocationMode.auto,
                  child: Text(l10n.prayerSettingsLocationAuto),
                ),
                DropdownMenuItem(
                  value: LocationMode.manual,
                  child: Text(l10n.prayerSettingsLocationManual),
                ),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  unawaited(controller.updateSettings(locationMode: mode));
                }
              },
            ),
          ),
          if (settings.locationMode == LocationMode.manual)
            ListTile(
              title: Text(l10n.prayerSettingsCityPickerLabel),
              trailing: DropdownButton<PrayerCity>(
                items: [
                  for (final city in cities)
                    DropdownMenuItem(
                      value: city,
                      child: Text(
                        cityDisplayName(l10n, city.nameKey),
                      ),
                    ),
                ],
                onChanged: (city) {
                  if (city != null) {
                    unawaited(
                      controller.updateSettings(
                        manualLatitude: city.latitude,
                        manualLongitude: city.longitude,
                        manualTimezone: city.ianaTimezone,
                      ),
                    );
                  }
                },
              ),
            ),
          SwitchListTile(
            title: Text(l10n.prayerSettingsNotificationsLabel),
            value: settings.notificationsEnabled,
            onChanged: (value) => controller.updateSettings(
              notificationsEnabled: value,
            ),
          ),
          SwitchListTile(
            title: Text(l10n.prayerSettingsPreReminderLabel),
            value: settings.preReminderEnabled,
            onChanged: (value) => controller.updateSettings(
              preReminderEnabled: value,
            ),
          ),
        ],
      ),
    );
  }

  String _methodLabel(
    AppLocalizations l10n,
    CalculationMethod method,
  ) => switch (method) {
    CalculationMethod.mwl => l10n.calcMethodMwl,
    CalculationMethod.isna => l10n.calcMethodIsna,
    CalculationMethod.egyptian => l10n.calcMethodEgyptian,
    CalculationMethod.ummAlQura => l10n.calcMethodUmmAlQura,
    CalculationMethod.karachi => l10n.calcMethodKarachi,
    CalculationMethod.tehran => l10n.calcMethodTehran,
    CalculationMethod.dubai => l10n.calcMethodDubai,
    CalculationMethod.kuwait => l10n.calcMethodKuwait,
    CalculationMethod.qatar => l10n.calcMethodQatar,
    CalculationMethod.singapore => l10n.calcMethodSingapore,
  };
}

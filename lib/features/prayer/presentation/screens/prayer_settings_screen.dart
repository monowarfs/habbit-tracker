import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_city.dart';
import 'package:habit_tracker/features/prayer/domain/entities/prayer_settings.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_controller.dart';
import 'package:habit_tracker/features/prayer/presentation/providers/prayer_providers.dart';

/// Calculation method, Asr madhab, Jumu'ah toggle, location, reminders,
/// Isha day-rollover time, and the "using manual location" banner (D-09).
class PrayerSettingsScreen extends ConsumerWidget {
  /// Creates the settings screen.
  const PrayerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(prayerSettingsProvider).value;
    final cities = ref.watch(prayerCitiesProvider).value ?? const [];
    final controller = ref.read(prayerControllerProvider.notifier);
    if (settings == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prayer settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer settings')),
      body: ListView(
        children: [
          if (settings.locationMode == LocationMode.manual)
            Container(
              width: double.infinity,
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              padding: const EdgeInsets.all(12),
              child: const Text('Using manual location'),
            ),
          ListTile(
            title: const Text('Calculation method'),
            trailing: DropdownButton<CalculationMethod>(
              value: settings.calculationMethod,
              items: [
                for (final method in CalculationMethod.values)
                  DropdownMenuItem(
                    value: method,
                    child: Text(method.name),
                  ),
              ],
              onChanged: (method) {
                if (method != null) {
                  controller.updateSettings(
                    calculationMethod: method,
                  );
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Asr method'),
            trailing: DropdownButton<AsrMethod>(
              value: settings.asrMethod,
              items: const [
                DropdownMenuItem(
                  value: AsrMethod.standard,
                  child: Text('Standard'),
                ),
                DropdownMenuItem(
                  value: AsrMethod.hanafi,
                  child: Text('Hanafi'),
                ),
              ],
              onChanged: (method) {
                if (method != null) {
                  controller.updateSettings(asrMethod: method);
                }
              },
            ),
          ),
          SwitchListTile(
            title: const Text("Observe Jumu'ah"),
            value: settings.observesJumuah,
            onChanged: (value) =>
                controller.updateSettings(observesJumuah: value),
          ),
          ListTile(
            title: const Text('Location'),
            trailing: DropdownButton<LocationMode>(
              value: settings.locationMode,
              items: const [
                DropdownMenuItem(
                  value: LocationMode.auto,
                  child: Text('Automatic (GPS)'),
                ),
                DropdownMenuItem(
                  value: LocationMode.manual,
                  child: Text('Manual'),
                ),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  controller.updateSettings(locationMode: mode);
                }
              },
            ),
          ),
          if (settings.locationMode == LocationMode.manual)
            ListTile(
              title: const Text('City'),
              trailing: DropdownButton<PrayerCity>(
                items: [
                  for (final city in cities)
                    DropdownMenuItem(
                      value: city,
                      child: Text(city.nameKey),
                    ),
                ],
                onChanged: (city) {
                  if (city != null) {
                    controller.updateSettings(
                      manualLatitude: city.latitude,
                      manualLongitude: city.longitude,
                      manualTimezone: city.ianaTimezone,
                    );
                  }
                },
              ),
            ),
          SwitchListTile(
            title: const Text('Prayer-time notifications'),
            value: settings.notificationsEnabled,
            onChanged: (value) => controller.updateSettings(
              notificationsEnabled: value,
            ),
          ),
          SwitchListTile(
            title: const Text('Pre-prayer reminder'),
            value: settings.preReminderEnabled,
            onChanged: (value) => controller.updateSettings(
              preReminderEnabled: value,
            ),
          ),
        ],
      ),
    );
  }
}

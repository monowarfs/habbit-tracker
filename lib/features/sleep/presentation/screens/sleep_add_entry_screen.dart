import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/sleep/presentation/providers/sleep_controller.dart';

/// Form to log a night's sleep (bed time, wake time, optional quality).
class SleepAddEntryScreen extends ConsumerStatefulWidget {
  /// Creates the add-entry screen.
  const SleepAddEntryScreen({super.key});

  @override
  ConsumerState<SleepAddEntryScreen> createState() =>
      _SleepAddEntryScreenState();
}

class _SleepAddEntryScreenState extends ConsumerState<SleepAddEntryScreen> {
  late DateTime _bedTime;
  late DateTime _wakeTime;
  int? _quality;

  @override
  void initState() {
    super.initState();
    final now = clock.now();
    _wakeTime = now;
    _bedTime = now.subtract(const Duration(hours: 8));
  }

  Future<void> _pickDateTime({required bool isBedTime}) async {
    final initial = isBedTime ? _bedTime : _wakeTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: clock.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isBedTime) {
        _bedTime = picked;
      } else {
        _wakeTime = picked;
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_wakeTime.isAfter(_bedTime)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.sleepAddEntryInvalidRange)));
      return;
    }
    await ref
        .read(sleepControllerProvider.notifier)
        .logSleep(bedTime: _bedTime, wakeTime: _wakeTime, quality: _quality);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sleepAddEntryTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(l10n.sleepAddEntryBedTimeLabel),
            subtitle: Text(_bedTime.toLocal().toString()),
            onTap: () => _pickDateTime(isBedTime: true),
          ),
          ListTile(
            title: Text(l10n.sleepAddEntryWakeTimeLabel),
            subtitle: Text(_wakeTime.toLocal().toString()),
            onTap: () => _pickDateTime(isBedTime: false),
          ),
          const SizedBox(height: 16),
          Text(l10n.sleepAddEntryQualityLabel),
          Slider(
            value: (_quality ?? 3).toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '${_quality ?? 3}',
            onChanged: (value) => setState(() => _quality = value.round()),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
        ],
      ),
    );
  }
}

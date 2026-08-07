import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/medicine/domain/entities/repeat_rule.dart';
import 'package:habit_tracker/features/medicine/domain/medicine_schedule_presets.dart';
import 'package:habit_tracker/features/medicine/presentation/providers/medicine_controller.dart';

/// Adds (or, once `editMedicineId` is set, will edit — full edit support
/// beyond the initial schedule is Task 17's detail-screen "add schedule"
/// action) a medicine, in four steps: schedule preset, details,
/// dosage/stock, schedule. FR-M-01.
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
  final _nameFocusNode = FocusNode();
  String? _nameError;
  final _dosageController = TextEditingController();
  bool _stockEnabled = false;
  final _stockCountController = TextEditingController();
  final _stockThresholdController = TextEditingController();

  RepeatRule _rule = const RepeatRule.fixedDaily(
    timesOfDay: [LocalTime(20, 0)],
  );

  /// Selected duration in days, or null for indefinite.
  int? _durationDays;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _dosageController.dispose();
    _stockCountController.dispose();
    _stockThresholdController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 1 && _nameController.text.trim().isEmpty) {
      setState(() {
        _nameError = AppLocalizations.of(context)!.profileNameRequiredError;
      });
      _nameFocusNode.requestFocus();
      return;
    }
    setState(() => _step += 1);
    unawaited(
      _pageController.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
    );
  }

  Future<void> _save() async {
    final startDate = LocalDate.fromDateTime(clock.now());
    final endDate = _durationDays != null
        ? startDate.addDays(_durationDays!)
        : null;
    await ref
        .read(medicineControllerProvider.notifier)
        .createMedicine(
          name: _nameController.text.trim(),
          dosageNote: _dosageController.text.trim().isEmpty
              ? null
              : _dosageController.text.trim(),
          stockEnabled: _stockEnabled,
          stockCount: _stockEnabled
              ? int.tryParse(_stockCountController.text)
              : null,
          stockThreshold: _stockEnabled
              ? int.tryParse(_stockThresholdController.text)
              : null,
          rule: _rule,
          startDate: startDate,
          endDate: endDate,
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.medicineFormTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / 4),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _PresetStep(
            onPresetSelected: (rule) {
              setState(() => _rule = rule);
              _nextStep();
            },
            onCustomSelected: _nextStep,
          ),
          _DetailsStep(
            nameController: _nameController,
            nameFocusNode: _nameFocusNode,
            nameError: _nameError,
            onNameChanged: _nameError == null
                ? null
                : (_) => setState(() => _nameError = null),
            dosageController: _dosageController,
          ),
          _StockStep(
            stockEnabled: _stockEnabled,
            onStockEnabledChanged: (v) => setState(() => _stockEnabled = v),
            stockCountController: _stockCountController,
            stockThresholdController: _stockThresholdController,
          ),
          _ScheduleStep(
            rule: _rule,
            onRuleChanged: (r) => setState(() => _rule = r),
            durationDays: _durationDays,
            onDurationChanged: (d) => setState(() => _durationDays = d),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _step < 3 ? _nextStep : _save,
            child: Text(
              _step < 3
                  ? l10n.medicineFormNextButton
                  : l10n.medicineFormSaveButton,
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetStep extends StatelessWidget {
  const _PresetStep({
    required this.onPresetSelected,
    required this.onCustomSelected,
  });

  final ValueChanged<RepeatRule> onPresetSelected;
  final VoidCallback onCustomSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final preset in medicineSchedulePresets)
          Card(
            child: ListTile(
              title: Text(_presetLabel(l10n, preset)),
              subtitle: Text(_presetDescription(l10n, preset)),
              onTap: () => onPresetSelected(preset.rule),
            ),
          ),
        Card(
          child: ListTile(
            title: Text(l10n.medPresetCustom),
            onTap: onCustomSelected,
          ),
        ),
      ],
    );
  }
}

String _presetLabel(AppLocalizations l10n, MedicineSchedulePreset preset) =>
    switch (preset.labelKey) {
      'medPresetOnceDaily' => l10n.medPresetOnceDaily,
      'medPresetTwiceDaily' => l10n.medPresetTwiceDaily,
      'medPresetEveryOtherDay' => l10n.medPresetEveryOtherDay,
      'medPresetAsNeeded' => l10n.medPresetAsNeeded,
      _ => preset.labelKey,
    };

String _presetDescription(
  AppLocalizations l10n,
  MedicineSchedulePreset preset,
) => switch (preset.descriptionKey) {
  'medPresetOnceDailyDesc' => l10n.medPresetOnceDailyDesc,
  'medPresetTwiceDailyDesc' => l10n.medPresetTwiceDailyDesc,
  'medPresetEveryOtherDayDesc' => l10n.medPresetEveryOtherDayDesc,
  'medPresetAsNeededDesc' => l10n.medPresetAsNeededDesc,
  _ => preset.descriptionKey,
};

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.nameController,
    required this.nameFocusNode,
    required this.nameError,
    required this.onNameChanged,
    required this.dosageController,
  });

  final TextEditingController nameController;
  final FocusNode nameFocusNode;
  final String? nameError;
  final ValueChanged<String>? onNameChanged;
  final TextEditingController dosageController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            focusNode: nameFocusNode,
            onChanged: onNameChanged,
            decoration: InputDecoration(
              labelText: l10n.medicineFormNameLabel,
              errorText: nameError,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: dosageController,
            decoration: InputDecoration(
              labelText: l10n.medicineFormDosageLabel,
            ),
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(l10n.medicineFormTrackStockLabel),
            value: stockEnabled,
            onChanged: onStockEnabledChanged,
          ),
          if (stockEnabled) ...[
            TextField(
              controller: stockCountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.medicineFormStockCountLabel,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: stockThresholdController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.medicineFormStockThresholdLabel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({
    required this.rule,
    required this.onRuleChanged,
    required this.durationDays,
    required this.onDurationChanged,
  });

  final RepeatRule rule;
  final ValueChanged<RepeatRule> onRuleChanged;
  final int? durationDays;
  final ValueChanged<int?> onDurationChanged;

  List<LocalTime> _currentTimes() => switch (rule) {
    FixedDailyRule(:final timesOfDay) => timesOfDay,
    EveryNDaysRule(:final timesOfDay) => timesOfDay,
    WeekdaySetRule(:final timesOfDay) => timesOfDay,
    PrnRule() => const [],
  };

  Future<void> _pickTime(BuildContext context) async {
    final current = _currentTimes();
    final initial = current.isNotEmpty ? current.first : const LocalTime(20, 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initial.hour,
        minute: initial.minute,
      ),
    );
    if (picked == null) return;
    final newTime = LocalTime(picked.hour, picked.minute);
    final newTimes = [newTime, ..._currentTimes().skip(1)];
    onRuleChanged(_ruleWithTimes(newTimes));
  }

  RepeatRule _ruleWithTimes(List<LocalTime> times) => switch (rule) {
    FixedDailyRule() => RepeatRule.fixedDaily(timesOfDay: times),
    EveryNDaysRule(:final intervalDays) => RepeatRule.everyNDays(
      intervalDays: intervalDays,
      timesOfDay: times,
    ),
    WeekdaySetRule(:final weekdaysMask) => RepeatRule.weekdaySet(
      weekdaysMask: weekdaysMask,
      timesOfDay: times,
    ),
    PrnRule() => rule,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final times = _currentTimes();
    final selected = switch (rule) {
      FixedDailyRule() => 0,
      EveryNDaysRule() => 1,
      WeekdaySetRule() => 2,
      PrnRule() => 3,
    };
    final timeLabel = times.isNotEmpty
        ? times
              .map(
                (t) =>
                    '${t.hour.toString().padLeft(2, '0')}:'
                    '${t.minute.toString().padLeft(2, '0')}',
              )
              .join(', ')
        : '—';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          RadioGroup<int>(
            groupValue: selected,
            onChanged: (value) => switch (value) {
              0 => onRuleChanged(
                const RepeatRule.fixedDaily(
                  timesOfDay: [LocalTime(20, 0)],
                ),
              ),
              1 => onRuleChanged(
                const RepeatRule.everyNDays(
                  intervalDays: 2,
                  timesOfDay: [LocalTime(20, 0)],
                ),
              ),
              2 => onRuleChanged(
                const RepeatRule.weekdaySet(
                  weekdaysMask: 0x7F,
                  timesOfDay: [LocalTime(20, 0)],
                ),
              ),
              3 => onRuleChanged(const RepeatRule.prn()),
              _ => null,
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.medicineFormFrequencyLabel),
                RadioListTile<int>(
                  title: Text(
                    l10n.medicineFormFrequencyFixedDaily,
                  ),
                  value: 0,
                ),
                RadioListTile<int>(
                  title: Text(
                    l10n.medicineFormFrequencyEveryOtherDay,
                  ),
                  value: 1,
                ),
                RadioListTile<int>(
                  title: Text(
                    l10n.medicineFormFrequencyWeekdays,
                  ),
                  value: 2,
                ),
                RadioListTile<int>(
                  title: Text(l10n.medicineFormFrequencyPrn),
                  value: 3,
                ),
                if (selected != 3) ...[
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: Text(l10n.medicineFormTimeLabel),
                    subtitle: Text(timeLabel),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickTime(context),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.medicineFormDurationLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DurationChip(
                label: l10n.medicineFormDuration7Days,
                selected: durationDays == 7,
                onTap: () => onDurationChanged(7),
              ),
              _DurationChip(
                label: l10n.medicineFormDuration15Days,
                selected: durationDays == 15,
                onTap: () => onDurationChanged(15),
              ),
              _DurationChip(
                label: l10n.medicineFormDuration1Month,
                selected: durationDays == 30,
                onTap: () => onDurationChanged(30),
              ),
              _DurationChip(
                label: l10n.medicineFormDuration3Months,
                selected: durationDays == 90,
                onTap: () => onDurationChanged(90),
              ),
              _DurationChip(
                label: l10n.medicineFormDurationCustom,
                selected:
                    durationDays != null &&
                    ![7, 15, 30, 90].contains(durationDays),
                onTap: () => _pickEndDate(context),
              ),
              _DurationChip(
                label: l10n.medicineFormDurationIndefinite,
                selected: durationDays == null,
                onTap: () => onDurationChanged(null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = picked.difference(today).inDays;
    onDurationChanged(days > 0 ? days : 1);
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface,
      ),
    );
  }
}

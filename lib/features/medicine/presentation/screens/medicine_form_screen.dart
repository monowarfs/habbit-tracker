import 'dart:async';

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
    unawaited(
      _pageController.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
    );
  }

  Future<void> _save() async {
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
          _DetailsStep(
            nameController: _nameController,
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
          ),
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
  const _DetailsStep({
    required this.nameController,
    required this.dosageController,
  });

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
          decoration: const InputDecoration(
            labelText: 'Dosage note (optional)',
          ),
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
      child: RadioGroup<int>(
        groupValue: selected,
        onChanged: (value) => switch (value) {
          0 => onRuleChanged(
            const RepeatRule.fixedDaily(timesOfDay: [LocalTime(8, 0)]),
          ),
          1 => onRuleChanged(
            const RepeatRule.everyNDays(
              intervalDays: 2,
              timesOfDay: [LocalTime(8, 0)],
            ),
          ),
          2 => onRuleChanged(
            const RepeatRule.weekdaySet(
              weekdaysMask: 0x7F,
              timesOfDay: [LocalTime(8, 0)],
            ),
          ),
          3 => onRuleChanged(const RepeatRule.prn()),
          _ => null,
        },
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How often?'),
            RadioListTile<int>(title: Text('Fixed times daily'), value: 0),
            RadioListTile<int>(title: Text('Every other day'), value: 1),
            RadioListTile<int>(title: Text('Specific weekdays'), value: 2),
            RadioListTile<int>(title: Text('As needed (PRN)'), value: 3),
          ],
        ),
      ),
    );
  }
}

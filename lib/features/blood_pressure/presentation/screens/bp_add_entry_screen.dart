import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_gate_widget.dart';
import 'package:habit_tracker/features/blood_pressure/presentation/providers/bp_controller.dart';

/// Form to log a blood-pressure reading (systolic, diastolic, optional
/// pulse). Wrapped in `PremiumGateWidget` — defense in depth against a
/// direct deep link bypassing `BpHomeScreen`'s own gate.
class BpAddEntryScreen extends ConsumerStatefulWidget {
  /// Creates the add-entry screen.
  const BpAddEntryScreen({super.key});

  @override
  ConsumerState<BpAddEntryScreen> createState() => _BpAddEntryScreenState();
}

class _BpAddEntryScreenState extends ConsumerState<BpAddEntryScreen> {
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final systolic = int.tryParse(_systolicController.text);
    final diastolic = int.tryParse(_diastolicController.text);
    if (systolic == null || diastolic == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bpAddEntryInvalidInput)));
      return;
    }
    final pulse = int.tryParse(_pulseController.text);
    final succeeded = await ref
        .read(bpControllerProvider.notifier)
        .logReading(systolic: systolic, diastolic: diastolic, pulse: pulse);
    if (!mounted) return;
    if (!succeeded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bpAddEntryInvalidInput)));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bpAddEntryTitle)),
      body: PremiumGateWidget(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _systolicController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.bpAddEntrySystolicLabel,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _diastolicController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.bpAddEntryDiastolicLabel,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pulseController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.bpAddEntryPulseLabel,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
          ],
        ),
      ),
    );
  }
}

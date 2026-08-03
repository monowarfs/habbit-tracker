import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_gate_widget.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_classification.dart';
import 'package:habit_tracker/features/blood_pressure/domain/entities/bp_log.dart';
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
  bool _saving = false;

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(AppLocalizations l10n, AppException error) {
    return switch (error) {
      ValidationException(:final field) => switch (field) {
        'systolic' => l10n.bpAddEntryInvalidSystolic,
        'diastolic' => l10n.bpAddEntryInvalidDiastolic,
        'pulse' => l10n.bpAddEntryInvalidPulse,
        'loggedAt' => l10n.bpAddEntryFutureError,
        _ => l10n.bpAddEntryInvalidInput,
      },
      _ => l10n.bpAddEntryInvalidInput,
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final systolic = int.tryParse(_systolicController.text);
    final diastolic = int.tryParse(_diastolicController.text);
    final pulseText = _pulseController.text.trim();
    final pulse = pulseText.isEmpty ? null : int.tryParse(pulseText);
    if (systolic == null ||
        diastolic == null ||
        (pulseText.isNotEmpty && pulse == null)) {
      _showError(l10n.bpAddEntryInvalidInput);
      return;
    }
    setState(() => _saving = true);
    final result = await ref
        .read(bpControllerProvider.notifier)
        .logReading(systolic: systolic, diastolic: diastolic, pulse: pulse);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result case Failure(:final error)) {
      _showError(_messageFor(l10n, error));
      return;
    }
    final log = (result as Success<BpLog>).value;
    if (log.classification == BpClassification.hypertensionCrisis) {
      await _showCrisisWarning(l10n);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// AHA guidance for a crisis-range reading (180+/120+ mmHg) is to seek
  /// immediate medical attention — a color-coded list icon alone isn't a
  /// strong enough signal for a reading at this severity.
  Future<void> _showCrisisWarning(AppLocalizations l10n) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bpCrisisWarningTitle),
        content: Text(l10n.bpCrisisWarningBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
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
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}

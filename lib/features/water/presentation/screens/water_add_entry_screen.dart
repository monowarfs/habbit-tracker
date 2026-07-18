import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/water/domain/entities/water_entry.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_controller.dart';
import 'package:habit_tracker/features/water/presentation/providers/water_providers.dart';
import 'package:intl/intl.dart';

/// Custom-amount entry screen — creates a new entry, or edits
/// [editEntryId] if given (FR-W-03/FR-W-05/FR-W-09).
class WaterAddEntryScreen extends ConsumerStatefulWidget {
  /// Creates the add/edit entry screen. Edits [editEntryId] if given,
  /// otherwise creates a new entry.
  const WaterAddEntryScreen({this.editEntryId, super.key});

  /// The entry to edit, or `null` to create a new one.
  final String? editEntryId;

  @override
  ConsumerState<WaterAddEntryScreen> createState() =>
      _WaterAddEntryScreenState();
}

class _WaterAddEntryScreenState extends ConsumerState<WaterAddEntryScreen> {
  final _amountController = TextEditingController();
  DateTime _loggedAt = clock.now();
  String? _error;
  bool _prefilled = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = clock.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (time == null) return;
    setState(() {
      _loggedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save(AppLocalizations l10n) async {
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = l10n.waterAddEntryInvalidAmount);
      return;
    }
    if (_loggedAt.isAfter(clock.now())) {
      setState(() => _error = l10n.waterAddEntryFutureError);
      return;
    }
    final controller = ref.read(waterControllerProvider.notifier);
    if (widget.editEntryId case final id?) {
      await controller.updateEntry(id, amountMl: amount, loggedAt: _loggedAt);
    } else {
      await controller.logCustom(amountMl: amount, loggedAt: _loggedAt);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _prefillIfNeeded(WaterEntry entry) {
    if (_prefilled) return;
    _prefilled = true;
    _amountController.text = '${entry.amountMl}';
    _loggedAt = entry.loggedAt.toLocal();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.editEntryId != null;

    if (isEdit) {
      final entryAsync = ref.watch(waterEntryByIdProvider(widget.editEntryId!));
      final entry = entryAsync.value;
      if (entry == null) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.waterAddEntryTitleEdit)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      _prefillIfNeeded(entry);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? l10n.waterAddEntryTitleEdit : l10n.waterAddEntryTitleNew,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.waterAddEntryAmountLabel,
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.waterAddEntryDateTimeLabel),
              subtitle: Text(
                DateFormat.yMMMd(
                  Localizations.localeOf(context).toString(),
                ).add_jm().format(_loggedAt),
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _save(l10n),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}

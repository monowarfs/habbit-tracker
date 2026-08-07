import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/pauses/pause_providers.dart';
import 'package:habit_tracker/core/profiles/active_profile_provider.dart';
import 'package:habit_tracker/core/utils/local_date.dart';

/// Screen for creating a new pause for a module.
class CreatePauseScreen extends ConsumerStatefulWidget {
  /// Creates the create pause screen.
  const CreatePauseScreen({required this.moduleId, super.key});

  /// The module to pause.
  final String moduleId;

  @override
  ConsumerState<CreatePauseScreen> createState() => _CreatePauseScreenState();
}

class _CreatePauseScreenState extends ConsumerState<CreatePauseScreen> {
  late LocalDate _startDate;
  late LocalDate _endDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = LocalDate.fromDateTime(DateTime.now());
    _startDate = today;
    _endDate = today.addDays(7);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final moduleLabel = _moduleLabel(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pauseModuleTitle(moduleLabel))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.pauseModuleTitle(moduleLabel),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            _DateTile(
              label: l10n.pauseStartDate,
              date: _startDate,
              onTap: _pickStartDate,
            ),
            const SizedBox(height: 8),
            _DateTile(
              label: l10n.pauseEndDate,
              date: _endDate,
              onTap: _pickEndDate,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _create,
              child: Text(l10n.pauseCreateButton),
            ),
          ],
        ),
      ),
    );
  }

  String _moduleLabel(AppLocalizations l10n) => switch (widget.moduleId) {
    'water' => l10n.navWater,
    'medicine' => l10n.navMedicine,
    'prayer' => l10n.navPrayer,
    _ => widget.moduleId,
  };

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.toDateTimeUtc(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: _endDate.toDateTimeUtc(),
    );
    if (picked != null) {
      setState(() {
        _startDate = LocalDate.fromDateTime(picked);
        _error = null;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.toDateTimeUtc(),
      firstDate: _startDate.toDateTimeUtc(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = LocalDate.fromDateTime(picked);
        _error = null;
      });
    }
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;

    if (_endDate.compareTo(_startDate) < 0) {
      setState(() => _error = l10n.pauseEndDateMustBeAfterStart);
      return;
    }
    final today = LocalDate.fromDateTime(DateTime.now());
    final isBackfill = _startDate.compareTo(today) <= 0;

    // Confirm if backfilling past days.
    if (isBackfill) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.pauseConfirmBackfill),
          content: Text(
            l10n.pauseConfirmBackfillBody(
              _startDate.toIso(),
              _endDate.toIso(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.pauseCreateButton),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // Check for overlaps first.
    final profile = await ref.read(activeProfileProvider.future);
    final repo = ref.read(pauseRepositoryProvider);
    final overlaps = await repo.overlapping(
      moduleId: widget.moduleId,
      start: _startDate,
      end: _endDate,
      profileId: profile.id,
    );
    if (overlaps.isNotEmpty) {
      setState(() => _error = l10n.pauseOverlapError);
      return;
    }

    await ref
        .read(pauseServiceProvider)
        .createPause(
          moduleId: widget.moduleId,
          startDate: _startDate,
          endDate: _endDate,
          profileId: profile.id,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final LocalDate date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(date.toIso()),
      trailing: const Icon(Icons.calendar_today),
      onTap: onTap,
    );
  }
}

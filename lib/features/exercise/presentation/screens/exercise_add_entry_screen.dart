import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/error/app_exception.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_gate_widget.dart';
import 'package:habit_tracker/features/exercise/presentation/providers/exercise_controller.dart';

/// Form to log a workout (exercise type, duration, optional calories).
/// Wrapped in `PremiumGateWidget` — defense in depth against a direct
/// deep link bypassing `ExerciseHomeScreen`'s own gate.
class ExerciseAddEntryScreen extends ConsumerStatefulWidget {
  /// Creates the add-entry screen.
  const ExerciseAddEntryScreen({super.key});

  @override
  ConsumerState<ExerciseAddEntryScreen> createState() =>
      _ExerciseAddEntryScreenState();
}

class _ExerciseAddEntryScreenState
    extends ConsumerState<ExerciseAddEntryScreen> {
  final _typeController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _typeController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
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
        'exerciseType' => l10n.exerciseAddEntryInvalidType,
        'durationMinutes' => l10n.exerciseAddEntryInvalidDuration,
        'calories' => l10n.exerciseAddEntryInvalidCalories,
        'loggedAt' => l10n.exerciseAddEntryFutureError,
        _ => l10n.exerciseAddEntryInvalidInput,
      },
      _ => l10n.exerciseAddEntryInvalidInput,
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final exerciseType = _typeController.text.trim();
    final duration = int.tryParse(_durationController.text);
    final caloriesText = _caloriesController.text.trim();
    final calories = caloriesText.isEmpty ? null : int.tryParse(caloriesText);
    // exerciseType's emptiness is left to LogExerciseUseCase's own
    // validation below — it produces the specific
    // exerciseAddEntryInvalidType message; short-circuiting here would
    // make that message unreachable.
    if (duration == null || (caloriesText.isNotEmpty && calories == null)) {
      _showError(l10n.exerciseAddEntryInvalidInput);
      return;
    }
    setState(() => _saving = true);
    final result = await ref
        .read(exerciseControllerProvider.notifier)
        .logWorkout(
          exerciseType: exerciseType,
          durationMinutes: duration,
          calories: calories,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result case Failure(:final error)) {
      _showError(_messageFor(l10n, error));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exerciseAddEntryTitle)),
      body: PremiumGateWidget(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _typeController,
              decoration: InputDecoration(
                labelText: l10n.exerciseAddEntryTypeLabel,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.exerciseAddEntryDurationLabel,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.exerciseAddEntryCaloriesLabel,
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

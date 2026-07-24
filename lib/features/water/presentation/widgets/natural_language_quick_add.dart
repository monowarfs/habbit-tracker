import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/features/settings/domain/entities/app_settings.dart';
import 'package:habit_tracker/features/water/domain/entities/parsed_water_entry.dart';
import 'package:habit_tracker/features/water/domain/usecases/parse_water_quick_add.dart';
import 'package:habit_tracker/features/water/presentation/water_amount_formatter.dart';

const _debounceDuration = Duration(milliseconds: 300);

/// A free-text quick-add field (`docs/superpowers/plans/ai-powered/
/// 02-natural-language-quick-add-impl-plan.md`): parses the typed phrase
/// after a debounce and shows a preview the user confirms before it's
/// actually logged — this widget never logs on its own.
class NaturalLanguageQuickAdd extends StatefulWidget {
  /// Creates the natural-language quick-add field.
  const NaturalLanguageQuickAdd({
    required this.unit,
    required this.onLog,
    required this.onEdit,
    super.key,
  });

  /// The user's preferred display unit (D-01/FR-W-02).
  final WaterUnit unit;

  /// Called with the confirmed parse when the user taps "Log" — the exact
  /// entry shown in the preview, never re-parsed at tap-time (re-parsing
  /// against a fresh clock/unit could silently diverge from what the user
  /// approved).
  final ValueChanged<ParsedWaterEntry> onLog;

  /// Called when the user taps "Edit" — switches to the custom-amount form.
  final VoidCallback onEdit;

  @override
  State<NaturalLanguageQuickAdd> createState() =>
      _NaturalLanguageQuickAddState();
}

class _NaturalLanguageQuickAddState extends State<NaturalLanguageQuickAdd> {
  final _controller = TextEditingController();
  final _parser = const ParseWaterQuickAddUseCase();
  Timer? _debounce;
  ParsedWaterEntry? _parsed;

  @override
  void didUpdateWidget(NaturalLanguageQuickAdd oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The preview was parsed under the old unit — a bare number means
    // something different in ml vs. fl oz, so re-parse rather than let a
    // stale preview be logged under the new unit.
    if (oldWidget.unit != widget.unit) _reparse(_controller.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _reparse(String text) {
    setState(
      () => _parsed = text.trim().isEmpty
          ? null
          : _parser.execute(
              rawText: text,
              now: clock.now(),
              waterUnit: widget.unit,
            ),
    );
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _parsed = null);
      return;
    }
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      _reparse(text);
    });
  }

  void _log() {
    final parsed = _parsed;
    if (parsed == null) return;
    widget.onLog(parsed);
    _controller.clear();
    setState(() => _parsed = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parsed = _parsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(hintText: l10n.waterQuickAddHintText),
        ),
        if (parsed != null) ...[
          const SizedBox(height: 8),
          _QuickAddPreview(
            parsed: parsed,
            unit: widget.unit,
            onLog: parsed.amountMl != null ? _log : null,
            onEdit: widget.onEdit,
          ),
        ],
      ],
    );
  }
}

class _QuickAddPreview extends StatelessWidget {
  const _QuickAddPreview({
    required this.parsed,
    required this.unit,
    required this.onLog,
    required this.onEdit,
  });

  final ParsedWaterEntry parsed;
  final WaterUnit unit;
  final VoidCallback? onLog;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final amountMl = parsed.amountMl;
    final loggedAt = parsed.loggedAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (amountMl != null && loggedAt != null)
              ListTile(
                leading: Icon(
                  parsed.confidence == 'high'
                      ? Icons.check_circle
                      : Icons.warning_amber,
                  color: parsed.confidence == 'high'
                      ? Colors.green
                      : Colors.amber.shade700,
                ),
                title: Text(
                  l10n.waterQuickAddPreviewTitle(
                    formatWaterAmount(context, amountMl, unit),
                    formatWaterLogTime(context, loggedAt),
                  ),
                ),
                subtitle: parsed.confidence != 'high'
                    ? Text(l10n.waterQuickAddConfidenceWarning)
                    : null,
              )
            else
              ListTile(
                leading: Icon(
                  Icons.warning_amber,
                  color: Colors.amber.shade700,
                ),
                title: Text(l10n.waterQuickAddUnparsedMessage),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onEdit,
                  child: Text(l10n.waterQuickAddEditButton),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onLog,
                  child: Text(l10n.waterQuickAddConfirmButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

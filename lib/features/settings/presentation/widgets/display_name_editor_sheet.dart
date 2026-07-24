import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// UI-enforced max length for the display name — same "cap in the UI, no
/// DB `CHECK` constraint" precedent as `core/widgets/note_editor_sheet
/// .dart`'s `noteMaxLength`.
const displayNameMaxLength = 40;

/// Shows a bottom sheet with one text field (prefilled with
/// [initialName]) and a Save button. Returns the trimmed name, or `null`
/// if cleared — same shape as `showNoteEditorSheet`
/// (`core/widgets/note_editor_sheet.dart`), this item's own copy/length
/// cap.
Future<String?> showDisplayNameEditorSheet(
  BuildContext context, {
  required String? initialName,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _DisplayNameEditorSheet(initialName: initialName),
  );
}

class _DisplayNameEditorSheet extends StatefulWidget {
  const _DisplayNameEditorSheet({required this.initialName});

  final String? initialName;

  @override
  State<_DisplayNameEditorSheet> createState() =>
      _DisplayNameEditorSheetState();
}

class _DisplayNameEditorSheetState extends State<_DisplayNameEditorSheet> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsDisplayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controller,
            maxLength: displayNameMaxLength,
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                final trimmed = _controller.text.trim();
                Navigator.of(context).pop(trimmed.isEmpty ? null : trimmed);
              },
              child: Text(l10n.commonSave),
            ),
          ),
        ],
      ),
    );
  }
}

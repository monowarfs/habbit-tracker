import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// The max length UI-enforced (`TextField.maxLength`), not a DB constraint
/// — same "UI caps input, no `CHECK` constraint" treatment
/// `Medicine.dosageNote` already gets.
const noteMaxLength = 500;

/// Canonicalizes raw note input: trims whitespace, then treats an empty
/// result as "no note" (`null`) — one representation for "no note," not
/// two.
String? canonicalizeNote(String raw) {
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Shows a bottom sheet with one multi-line text field (prefilled with
/// [initialNotes]) and a Save button. Returns the trimmed note, or `null`
/// if cleared — the shared note-editing affordance for Medicine's
/// `DoseTile` and Prayer's `PrayerTile`, whose one-tap done/skip/prayed
/// toggles stay note-free by design.
Future<String?> showNoteEditorSheet(
  BuildContext context, {
  required String? initialNotes,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _NoteEditorSheet(initialNotes: initialNotes),
  );
}

class _NoteEditorSheet extends StatefulWidget {
  const _NoteEditorSheet({required this.initialNotes});

  final String? initialNotes;

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late final _controller = TextEditingController(text: widget.initialNotes);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.logNotesSheetTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controller,
            maxLength: noteMaxLength,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.logNotesSheetHint),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(canonicalizeNote(_controller.text)),
              child: Text(l10n.commonSave),
            ),
          ),
        ],
      ),
    );
  }
}

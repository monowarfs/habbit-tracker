import 'package:flutter/material.dart';

/// A one-line, dismissible, non-modal educational card
/// (`docs/superpowers/specs/02-delightful/
/// 06-why-this-matters-micro-education-cards-design.md`). The caller
/// owns whether to render it at all (checked against the relevant
/// `*HintSeenAt` `AppSettings` field being null) and wires [onDismiss]
/// to the matching `mark*HintSeen()` repository call, so a dismissal
/// persists and this never shows again.
class DismissibleHintCard extends StatelessWidget {
  /// Creates a dismissible hint card showing [message].
  const DismissibleHintCard({
    required this.message,
    required this.onDismiss,
    super.key,
  });

  /// The one-line educational copy to show.
  final String message;

  /// Called when the user taps the close button.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.lightbulb_outline),
      title: Text(message),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onDismiss,
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      ),
    ),
  );
}

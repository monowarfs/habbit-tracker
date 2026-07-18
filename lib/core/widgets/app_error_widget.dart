import 'package:flutter/material.dart';

/// Last-resort fallback shown in place of a crashed widget subtree
/// (`ErrorWidget.builder`).
///
/// Deliberately not localized: this can render before `Localizations`
/// mounts (a build error during app startup itself), so it can't depend on
/// `AppLocalizations.of(context)` being available.
class AppErrorWidget extends StatelessWidget {
  /// Creates the fallback error widget.
  const AppErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Material(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Something went wrong. Please restart the app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

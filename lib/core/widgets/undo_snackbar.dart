import 'dart:async';

import 'package:flutter/material.dart';

/// Shows a Gmail-style Undo snackbar. If the user taps Undo, [onUndo]
/// runs and [onCommit] never does; otherwise (timeout, swipe-dismiss,
/// navigating away) [onCommit] runs once the snackbar closes.
Future<void> showUndoSnackbar(
  BuildContext context, {
  required String message,
  required String undoLabel,
  required FutureOr<void> Function() onCommit,
  VoidCallback? onUndo,
  Duration duration = const Duration(seconds: 4),
}) async {
  final reason = await ScaffoldMessenger.of(context)
      .showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          action: SnackBarAction(label: undoLabel, onPressed: () {}),
          // `SnackBar.persist` defaults to true whenever `action` is
          // non-null ("the snackbar will persist as well" per its own
          // doc) — without this, the timeout never fires and `onCommit`
          // would never run unless the user explicitly tapped Undo.
          persist: false,
        ),
      )
      .closed;
  if (reason == SnackBarClosedReason.action) {
    onUndo?.call();
  } else {
    await onCommit();
  }
}

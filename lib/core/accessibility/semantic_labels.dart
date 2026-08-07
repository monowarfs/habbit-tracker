import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Centralized TalkBack/VoiceOver labeling conventions
/// (`docs/superpowers/specs/07-accessibility/
/// 01-TALKBACK-VOICEOVER-NAVIGATION-AUDIT-IMPLEMENTATION-PLAN.md`) — a
/// thin wrapper so screens build localized [Semantics] nodes consistently
/// instead of scattering ad hoc `Semantics(label: ...)` calls.
class SemanticLabels {
  const SemanticLabels._();

  /// Wraps [child] in a [Semantics] node carrying [label]. Set
  /// [excludeSemantics] to `true` for purely decorative/display children
  /// (no focusable descendants) so [label] fully replaces whatever the
  /// subtree would otherwise announce, rather than being read alongside
  /// it. Leave it `false` (the default) whenever [child] contains its own
  /// interactive controls (buttons, switches) that must stay individually
  /// reachable.
  static Widget wrap({
    required String label,
    required Widget child,
    bool excludeSemantics = false,
  }) {
    return Semantics(
      label: label,
      excludeSemantics: excludeSemantics,
      child: child,
    );
  }

  /// Pushes a live-region announcement (e.g. after a success snackbar) to
  /// the active screen reader. Uses [SemanticsService.sendAnnouncement]
  /// (the non-deprecated replacement for `SemanticsService.announce`),
  /// which needs the `FlutterView` behind [context].
  static void announce(BuildContext context, String message) {
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        TextDirection.ltr,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] in an external app, showing [fallbackMessage] in a
/// snackbar if it can't be launched (unsupported scheme, no handler
/// installed, or the platform call itself throws) — the one shared
/// "best-effort external link" behavior every settings tile that opens
/// a URL or `mailto:` link uses.
Future<void> launchExternalLink(
  BuildContext context, {
  required Uri uri,
  required String fallbackMessage,
}) async {
  var launched = false;
  try {
    if (await canLaunchUrl(uri)) {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } on Object {
    launched = false;
  }
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(fallbackMessage)));
  }
}

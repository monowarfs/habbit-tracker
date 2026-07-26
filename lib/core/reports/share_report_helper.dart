import 'package:share_plus/share_plus.dart';

/// Opens the OS share sheet for an exported report file
/// (`docs/superpowers/specs/04-premium/05-exportable-pdf-csv-reports-
/// IMPLEMENTATION-PLAN.md`) — same `share_plus` precedent every other
/// file-sharing flow in the app already uses (`LocalFileBackupTarget
/// .upload`, `recap_share_usecase.dart`).
Future<void> shareReportFile(String filePath) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(filePath)],
      text: 'Habit Tracker Report',
    ),
  );
}

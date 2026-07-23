import 'dart:io';
import 'dart:typed_data';

import 'package:habit_tracker/core/reports/aggregate_report_usecase.dart';
import 'package:habit_tracker/core/utils/local_date.dart';
import 'package:habit_tracker/features/reports/presentation/widgets/recap_card_capture.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:share_plus/share_plus.dart';

/// Renders the current month's recap (already painted, off-screen, onto
/// a `RecapCardCapture`'s `RepaintBoundary` by the caller — see
/// `ReportsScreen`'s share button) and hands it to the OS share sheet,
/// which already includes "Save to Photos"/"Save to Files" on both
/// platforms — same precedent `LocalFileBackupTarget.upload` already
/// relies on, so no separate gallery-save code path is needed
/// (`docs/superpowers/specs/02-delightful/
/// 05-shareable-monthly-recap-card-design.md`).
///
/// [capturePng]/[getTemporaryDirectory]/[share] are test-only seams —
/// the real platform channels behind `path_provider`/`share_plus` aren't
/// exercised under `flutter test`, same precedent as `PinSettingsScreen`
/// 's `biometricAvailable` seam
/// (`docs/superpowers/plans/2026-07-21-pin-lock-toggles-fix.md`).
Future<void> shareMonthlyRecap({
  // Never read in this function's own body — kept required so a caller
  // can't call this without having already rendered the off-screen
  // `MonthlyRecapCard(reports: reports, ...)` this function assumes
  // exists; self-documents the precondition rather than silently
  // trusting it.
  required List<ModuleReport> reports,
  required LocalDate monthAnchor,
  Future<Uint8List> Function({double pixelRatio}) capturePng =
      RecapCardCapture.capturePng,
  Future<Directory> Function() getTemporaryDirectory =
      path_provider.getTemporaryDirectory,
  Future<void> Function(ShareParams params) share = _defaultShare,
}) async {
  final pngBytes = await capturePng(pixelRatio: 3);
  final dir = await getTemporaryDirectory();
  final fileName =
      'habit_tracker_recap_${monthAnchor.year}_'
      '${monthAnchor.month.toString().padLeft(2, '0')}.png';
  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(pngBytes);
  // No explicit delete — same precedent as `data_settings_screen.dart`'s
  // export file: the OS-managed temp directory is left to reclaim it.
  await share(ShareParams(files: [XFile(file.path)]));
}

Future<void> _defaultShare(ShareParams params) async {
  await SharePlus.instance.share(params);
}

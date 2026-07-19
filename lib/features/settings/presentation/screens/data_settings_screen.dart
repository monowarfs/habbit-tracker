import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/backup/export_orchestrator.dart';
import 'package:habit_tracker/core/backup/import_orchestrator.dart';
import 'package:habit_tracker/core/backup/local_file_backup_target.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Export, import, and share-diagnostic-logs — the Data section
/// (`strategies/backup-import-export.md`).
class DataSettingsScreen extends ConsumerStatefulWidget {
  /// Creates the Data settings screen.
  const DataSettingsScreen({super.key});

  @override
  ConsumerState<DataSettingsScreen> createState() => _DataSettingsScreenState();
}

class _DataSettingsScreenState extends ConsumerState<DataSettingsScreen> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final envelope = await buildExport(
        modules: ref.read(habitModulesProvider),
        settingsRepository: ref.read(settingsRepositoryProvider),
        achievementRepository: AchievementRepository(
          ref.read(databaseProvider),
        ),
        appVersion: packageInfo.version,
      );
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'habit_tracker_backup.json'));
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(envelope.toJson()),
      );
      await LocalFileBackupTarget().upload(file);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final file = await LocalFileBackupTarget().download();
    if (file == null) return;
    final rawJson = await file.readAsString();
    final validation = await validateImport(rawJson);
    if (!mounted) return;
    if (validation case Failure(:final error)) {
      _showFailure(error.toString());
      return;
    }
    final preview = (validation as Success<ImportPreview>).value;
    final confirmed = await _confirmImport(preview);
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final applied = await applyImport(
        envelope: preview.envelope,
        modules: ref.read(habitModulesProvider),
        db: ref.read(databaseProvider),
        settingsRepository: ref.read(settingsRepositoryProvider),
      );
      if (!mounted) return;
      if (applied case Failure(:final error)) {
        _showFailure(error.toString());
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.dataImportSuccess),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showFailure(String reason) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.dataImportFailed(reason))),
    );
  }

  Future<bool?> _confirmImport(ImportPreview preview) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dataImportPreviewTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.dataImportPreviewWarning),
            const SizedBox(height: 8),
            for (final entry in preview.countsByModule.entries)
              Text(l10n.dataImportPreviewCount(entry.value, entry.key)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.lockResetCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.dataImportConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _shareLogs() async {
    final files = await logFilesForSharing();
    if (files.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(files: [for (final file in files) XFile(file.path)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsData)),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_outlined),
                  title: Text(l10n.dataSettingsExport),
                  onTap: _export,
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: Text(l10n.dataSettingsImport),
                  onTap: _import,
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text(l10n.dataSettingsShareLogs),
                  onTap: _shareLogs,
                ),
              ],
            ),
    );
  }
}

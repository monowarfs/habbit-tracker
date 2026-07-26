import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/achievements/achievement_repository.dart';
import 'package:habit_tracker/core/backup/drive_auth_service.dart';
import 'package:habit_tracker/core/backup/drive_backup_repository.dart';
import 'package:habit_tracker/core/backup/drive_backup_use_case.dart';
import 'package:habit_tracker/core/backup/google_drive_backup_target.dart';
import 'package:habit_tracker/core/backup/import_orchestrator.dart';
import 'package:habit_tracker/core/database/database_provider.dart';
import 'package:habit_tracker/core/error/result.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/logging/app_logger.dart';
import 'package:habit_tracker/core/modules/module_registry.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Google Drive backup/restore settings screen
/// (`docs/superpowers/specs/04-premium/01-google-drive-backup-restore-
/// design.md`) — gated behind [isPremiumUserProvider]. Reuses the exact
/// same `BackupEnvelope`/`export_orchestrator.dart`/`import_orchestrator
/// .dart` pipeline `DataSettingsScreen`'s local export/import already
/// uses, just via `drive_backup_use_case.dart`'s Drive-flavored wrapper.
class BackupSettingsScreen extends ConsumerStatefulWidget {
  /// Creates the backup settings screen.
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  final _authService = DriveAuthService();
  late final _driveTarget = GoogleDriveBackupTarget(
    authService: _authService,
  );

  bool _busy = false;
  bool _connected = false;
  DateTime? _lastBackupAt;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshStatus());
  }

  Future<void> _refreshStatus() async {
    final connected = await _authService.isDriveConnected();
    final backupRepo = DriveBackupRepository(ref.read(databaseProvider));
    final latest = await backupRepo.latestBackup();
    var lastBackupAt = latest == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(latest.backedUpAt, isUtc: true);
    // The local drive_backups history doesn't survive a reinstall/new
    // device — fall back to asking Drive itself when there's no local
    // record but a Drive account is connected.
    if (lastBackupAt == null && connected) {
      try {
        lastBackupAt = await _driveTarget.getLastBackupTime();
      } on Object {
        // Best-effort fallback only — the local history (if any) already
        // won above, and a real error surfaces on the next explicit
        // backup/restore action instead.
      }
    }
    if (!mounted) return;
    setState(() {
      _connected = connected;
      _lastBackupAt = lastBackupAt;
    });
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      await _authService.connectDrive();
    } on Object catch (e, st) {
      logger.e('drive_connect_failed', error: e, stackTrace: st);
      if (mounted) _showMessage(e.toString());
    } finally {
      await _refreshStatus();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    try {
      await _authService.disconnectDrive();
    } on Object catch (e, st) {
      logger.e('drive_disconnect_failed', error: e, stackTrace: st);
      if (mounted) _showMessage(e.toString());
    } finally {
      await _refreshStatus();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupNow() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      final packageInfo = await PackageInfo.fromPlatform();
      final result = await performBackup(
        modules: ref.read(habitModulesProvider),
        settingsRepository: ref.read(settingsRepositoryProvider),
        achievementRepository: AchievementRepository(db),
        appVersion: packageInfo.version,
        driveTarget: _driveTarget,
        backupRepository: DriveBackupRepository(db),
      );
      if (!mounted) return;
      if (result case Failure(:final error)) {
        _showMessage(l10n.backupSettingsBackupFailed(error.toString()));
      } else {
        _showMessage(l10n.backupSettingsBackupSuccess);
      }
    } finally {
      await _refreshStatus();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final preview = await previewDriveRestore(driveTarget: _driveTarget);
    if (!mounted) return;
    if (preview case Failure(:final error)) {
      setState(() => _busy = false);
      _showMessage(l10n.backupSettingsRestoreFailed(error.toString()));
      return;
    }
    final validated = (preview as Success<ImportPreview>).value;
    setState(() => _busy = false);
    final confirmed = await _confirmRestore(validated);
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      final packageInfo = await PackageInfo.fromPlatform();
      final result = await applyDriveRestore(
        preview: validated,
        modules: ref.read(habitModulesProvider),
        db: db,
        settingsRepository: ref.read(settingsRepositoryProvider),
        achievementRepository: AchievementRepository(db),
        appVersion: packageInfo.version,
      );
      if (!mounted) return;
      if (result case Failure(:final error)) {
        _showMessage(l10n.backupSettingsRestoreFailed(error.toString()));
      } else {
        _showMessage(l10n.backupSettingsRestoreSuccess);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmRestore(ImportPreview preview) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupSettingsRestoreConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.backupSettingsRestoreConfirmWarning),
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
            child: Text(l10n.backupSettingsRestore),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = ref.watch(isPremiumUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupSettingsTitle)),
      body: !isPremium
          ? _PremiumRequiredView(l10n: l10n)
          : _busy
          ? const Center(child: CircularProgressIndicator())
          : _content(l10n),
    );
  }

  Widget _content(AppLocalizations l10n) {
    final dateFormat = DateFormat.yMMMd().add_jm();
    final reminderEnabled =
        ref.watch(appSettingsProvider).value?.driveBackupReminderEnabled ??
        false;
    return ListView(
      children: [
        ListTile(
          leading: Icon(
            _connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
          ),
          title: Text(
            _connected
                ? l10n.backupSettingsConnected
                : l10n.backupSettingsNotConnected,
          ),
          trailing: FilledButton(
            onPressed: _connected ? _disconnect : _connect,
            child: Text(
              _connected
                  ? l10n.backupSettingsDisconnectDrive
                  : l10n.backupSettingsConnectDrive,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(
            _lastBackupAt == null
                ? l10n.backupSettingsNeverBackedUp
                : l10n.backupSettingsLastBackup(
                    dateFormat.format(_lastBackupAt!.toLocal()),
                  ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: Text(l10n.backupSettingsBackupNow),
          enabled: _connected,
          onTap: _connected ? _backupNow : null,
        ),
        ListTile(
          leading: const Icon(Icons.restore_outlined),
          title: Text(l10n.backupSettingsRestore),
          enabled: _connected,
          onTap: _connected ? _restore : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: Text(l10n.backupSettingsReminderToggle),
          subtitle: Text(l10n.backupSettingsReminderDescription),
          value: reminderEnabled,
          onChanged: (value) => ref
              .read(settingsRepositoryProvider)
              .updateDriveBackupReminderEnabled(enabled: value),
        ),
      ],
    );
  }
}

class _PremiumRequiredView extends StatelessWidget {
  const _PremiumRequiredView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.diamond_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              l10n.backupSettingsPremiumRequired,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              // TODO(spec-07): navigate to the real purchase screen once
              // docs/superpowers/specs/04-premium/
              // 07-lifetime-unlock-pricing-tier-IMPLEMENTATION-PLAN.md
              // ships it.
              onPressed: () {},
              child: Text(l10n.backupSettingsUnlockPremium),
            ),
          ],
        ),
      ),
    );
  }
}

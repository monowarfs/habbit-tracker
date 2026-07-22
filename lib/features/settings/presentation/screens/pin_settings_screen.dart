import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/security/biometric_service.dart';
import 'package:habit_tracker/core/security/pin_lock_controller.dart';
import 'package:habit_tracker/core/widgets/pin_keypad.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// PIN lock's own Settings section: enable/disable, change, timeout,
/// biometric and screen-privacy toggles (both gated on PIN already
/// being enabled, `strategies/security.md`).
class PinSettingsScreen extends ConsumerWidget {
  /// Creates the PIN settings screen. [biometricAvailable] overrides the
  /// real `BiometricService().isAvailable` check — test-only seam, since
  /// `local_auth`'s platform channel isn't available under `flutter test`.
  const PinSettingsScreen({super.key, this.biometricAvailable});

  /// Test seam for [BiometricService.isAvailable].
  final Future<bool> Function()? biometricAvailable;

  static const _timeoutOptions = [0, 60, 300, 1800];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider).value;
    final pinEnabled = settings?.pinEnabled ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSecurity)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.pinSettingsEnable),
            subtitle: pinEnabled ? null : Text(l10n.pinSettingsEnableWarning),
            value: pinEnabled,
            onChanged: (enable) async {
              if (enable) {
                await context.push('/settings/pin/set');
                return;
              }
              await _confirmAndDisable(context, ref);
            },
          ),
          if (pinEnabled) ...[
            ListTile(
              title: Text(l10n.pinSettingsChange),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _changePin(context, ref),
            ),
            ListTile(
              title: Text(l10n.pinSettingsTimeout),
              trailing: DropdownButton<int>(
                value: settings?.pinLockTimeoutSeconds ?? 0,
                items: [
                  DropdownMenuItem(
                    value: _timeoutOptions[0],
                    child: Text(l10n.pinSettingsTimeoutImmediate),
                  ),
                  DropdownMenuItem(
                    value: _timeoutOptions[1],
                    child: Text(l10n.pinSettingsTimeout1Min),
                  ),
                  DropdownMenuItem(
                    value: _timeoutOptions[2],
                    child: Text(l10n.pinSettingsTimeout5Min),
                  ),
                  DropdownMenuItem(
                    value: _timeoutOptions[3],
                    child: Text(l10n.pinSettingsTimeout30Min),
                  ),
                ],
                onChanged: (seconds) async {
                  if (seconds == null) return;
                  await ref
                      .read(settingsRepositoryProvider)
                      .updatePinLockTimeoutSeconds(seconds);
                },
              ),
            ),
            FutureBuilder<bool>(
              future: (biometricAvailable ?? BiometricService().isAvailable)(),
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return SwitchListTile(
                  title: Text(l10n.pinSettingsBiometric),
                  value: settings?.biometricEnabled ?? true,
                  onChanged: (enable) async {
                    await ref
                        .read(settingsRepositoryProvider)
                        .updateBiometricEnabled(enabled: enable);
                  },
                );
              },
            ),
            SwitchListTile(
              title: Text(l10n.pinSettingsScreenPrivacy),
              value: settings?.screenPrivacyEnabled ?? false,
              onChanged: (enable) async {
                await ref
                    .read(settingsRepositoryProvider)
                    .updateScreenPrivacyEnabled(enabled: enable);
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmAndDisable(BuildContext context, WidgetRef ref) async {
    final pin = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => const _CurrentPinPrompt(),
    );
    if (pin == null) return;
    await ref.read(pinLockControllerProvider).disablePin(pin);
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final oldPin = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => const _CurrentPinPrompt(),
    );
    if (oldPin == null) return;
    final ok = await ref.read(pinLockControllerProvider).verify(oldPin);
    if (!ok || !context.mounted) return;
    await context.push('/settings/pin/set', extra: oldPin);
  }
}

class _CurrentPinPrompt extends ConsumerStatefulWidget {
  const _CurrentPinPrompt();

  @override
  ConsumerState<_CurrentPinPrompt> createState() => _CurrentPinPromptState();
}

class _CurrentPinPromptState extends ConsumerState<_CurrentPinPrompt> {
  String _entered = '';

  void _onDigit(String digit) {
    if (_entered.length >= 4) return;
    setState(() => _entered += digit);
    if (_entered.length == 4) Navigator.of(context).pop(_entered);
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.pinSetEnterCurrent),
          const SizedBox(height: 16),
          PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
        ],
      ),
    );
  }
}

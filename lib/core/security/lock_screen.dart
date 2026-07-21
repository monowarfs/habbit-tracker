import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/router/app_router.dart';
import 'package:habit_tracker/core/security/biometric_service.dart';
import 'package:habit_tracker/core/security/pin_lock_controller.dart';
import 'package:habit_tracker/core/widgets/pin_keypad.dart';
import 'package:habit_tracker/features/settings/presentation/providers/app_settings_providers.dart';

/// PIN entry — the router's `/lock` redirect target
/// (`strategies/security.md`). Shows a shake + error on a wrong PIN, a
/// backoff countdown while locked out, and an optional biometric
/// shortcut offered up front when available.
class LockScreen extends ConsumerStatefulWidget {
  /// Creates the lock screen. [returnTo] is the route to navigate to on
  /// a successful unlock, or the dashboard if absent.
  const LockScreen({this.returnTo, super.key});

  /// Route to return to once unlocked.
  final String? returnTo;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entered = '';
  bool _showError = false;
  Duration _backoff = Duration.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshBackoff());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_tryBiometric()),
    );
  }

  Future<void> _refreshBackoff() async {
    final backoff = await ref.read(pinLockControllerProvider).currentBackoff();
    if (mounted) setState(() => _backoff = backoff);
  }

  Future<void> _tryBiometric() async {
    final biometricEnabled =
        ref.read(appSettingsProvider).value?.biometricEnabled ?? true;
    if (!biometricEnabled) return;
    final biometric = BiometricService();
    if (!await biometric.isAvailable()) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final ok = await biometric.authenticate(
      localizedReason: l10n.lockScreenTitle,
    );
    if (ok) await _unlock();
  }

  Future<void> _onDigit(String digit) async {
    if (_backoff > Duration.zero || _entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _showError = false;
    });
    if (_entered.length == 4) {
      final ok = await ref.read(pinLockControllerProvider).verify(_entered);
      if (ok) {
        await _unlock();
      } else {
        setState(() {
          _entered = '';
          _showError = true;
        });
        await _refreshBackoff();
      }
    }
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    context.go(widget.returnTo ?? AppRoutes.dashboard);
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.lockScreenTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: i < _entered.length
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
            if (_showError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.lockScreenWrongPin,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_backoff > Duration.zero)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.lockScreenBackoff(_backoff.inSeconds)),
              ),
            const SizedBox(height: 16),
            PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            TextButton(
              onPressed: () => context.push(AppRoutes.lockReset),
              child: Text(l10n.lockScreenForgotPin),
            ),
          ],
        ),
      ),
    );
  }
}

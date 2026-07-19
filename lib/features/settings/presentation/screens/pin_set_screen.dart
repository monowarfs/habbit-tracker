import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/security/pin_lock_controller.dart';
import 'package:habit_tracker/core/widgets/pin_keypad.dart';

/// Set/change PIN — enter, then confirm (must match). Reachable from
/// `/settings/pin` when enabling for the first time or tapping "change".
class PinSetScreen extends ConsumerStatefulWidget {
  /// Creates the PIN set/change screen.
  const PinSetScreen({super.key});

  @override
  ConsumerState<PinSetScreen> createState() => _PinSetScreenState();
}

class _PinSetScreenState extends ConsumerState<PinSetScreen> {
  String _first = '';
  String _entered = '';
  bool _confirming = false;
  bool _mismatch = false;

  Future<void> _onDigit(String digit) async {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _mismatch = false;
    });
    if (_entered.length < 4) return;

    if (!_confirming) {
      setState(() {
        _first = _entered;
        _entered = '';
        _confirming = true;
      });
      return;
    }

    if (_entered != _first) {
      setState(() {
        _entered = '';
        _confirming = false;
        _first = '';
        _mismatch = true;
      });
      return;
    }

    await ref.read(pinLockControllerProvider).setPin(_entered);
    if (mounted) context.pop();
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _confirming ? l10n.pinSetTitleConfirm : l10n.pinSetTitleNew,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_mismatch) Text(l10n.pinSetMismatch),
            const SizedBox(height: 16),
            PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// A 4-digit PIN entry keypad — a plain grid of digit buttons, no
/// package (this is simple enough that a package would be a needless
/// dependency). Shared by `LockScreen`
/// (`core/security/lock_screen.dart`) and the settings PIN-set flow
/// (`features/settings/presentation/screens/pin_set_screen.dart`).
class PinKeypad extends StatelessWidget {
  /// Creates a PIN keypad. [onDigit] fires with `'0'`-`'9'`; [onBackspace]
  /// fires on the backspace key.
  const PinKeypad({
    required this.onDigit,
    required this.onBackspace,
    super.key,
  });

  /// Called with the tapped digit, `'0'`-`'9'`.
  final ValueChanged<String> onDigit;

  /// Called when the backspace key is tapped.
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const layout = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in layout)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final key in row)
                SizedBox(
                  width: 72,
                  height: 72,
                  child: key.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          onPressed: () =>
                              key == '⌫' ? onBackspace() : onDigit(key),
                          icon: key == '⌫'
                              ? const Icon(Icons.backspace_outlined)
                              : Text(
                                  key,
                                  style: const TextStyle(fontSize: 24),
                                ),
                        ),
                ),
            ],
          ),
      ],
    );
  }
}

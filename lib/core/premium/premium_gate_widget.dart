import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';

/// A wrapper widget that gates content behind a premium entitlement check.
///
/// If the user is premium, [child] is shown. Otherwise, [lockedChild] or
/// a default "Unlock Premium" CTA is shown.
class PremiumGateWidget extends ConsumerWidget {
  /// The content to show to premium users.
  final Widget child;

  /// The content to show to non-premium users. If null, shows a default CTA.
  final Widget? lockedChild;

  /// Creates a premium gate.
  const PremiumGateWidget({
    super.key,
    required this.child,
    this.lockedChild,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumUserProvider);

    if (isPremium) {
      return child;
    }

    return lockedChild ?? _DefaultLockedCTA();
  }
}

class _DefaultLockedCTA extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Premium Feature',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlock Premium to access advanced themes, detailed reports, and more.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                // TODO: Navigate to purchase screen (Task 8).
              },
              child: const Text('View Plans'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';

/// The screen where users can choose a premium plan (subscription or lifetime).
class PurchaseScreen extends ConsumerWidget {
  /// Creates the purchase screen.
  const PurchaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock Premium'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Master your habits with Premium',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildFeatureList(theme),
            const SizedBox(height: 40),
            _PricingCard(
              title: 'Monthly Subscription',
              price: '$2.99 / month',
              description: 'Access all premium features on one device.',
              onTap: () {
                // TODO: Start IAP flow.
              },
            ),
            const SizedBox(height: 16),
            _PricingCard(
              title: 'Lifetime Unlock',
              price: '$29.99 once',
              description: 'One-time payment for lifetime access.',
              isHighlighted: true,
              onTap: () {
                // TODO: Start IAP flow.
              },
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () {
                // TODO: Restore purchases.
              },
              child: const Text('Restore Purchase'),
            ),
            const SizedBox(height: 16),
            const _LegalLinks(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList(ThemeData theme) {
    final features = [
      'Advanced themes & icon packs',
      'Additional habit modules',
      'PDF/CSV report export',
      'Extended stats & trends',
      'Priority support',
    ];

    return Column(
      children: features.map((f) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(f),
          ],
        ),
      )).toList(),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String description;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.description,
    this.isHighlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isHighlighted ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isHighlighted
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  if (isHighlighted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Best Value', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onPrimaryContainer)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(price, style: theme.textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Subscription clarifies recurring cost. Sync excluded from lifetime tier.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Terms of Service', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
            SizedBox(width: 16),
            Text('Privacy Policy', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
          ],
        ),
      ],
    );
  }
}

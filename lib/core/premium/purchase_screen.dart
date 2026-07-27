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
        title: Text(l10n.premiumPurchaseTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.premiumPurchaseHeadline,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildFeatureList(l10n, theme),
            const SizedBox(height: 40),
            _PricingCard(
              title: l10n.premiumPlanMonthly,
              price: l10n.premiumPriceMonthly(r'$2.99'),
              description: l10n.premiumPlanMonthlyDesc,
              onTap: () {
                // TODO(monowarmini): Start IAP flow.
              },
            ),
            const SizedBox(height: 16),
            _PricingCard(
              title: l10n.premiumPlanLifetime,
              price: l10n.premiumPriceLifetime(r'$29.99'),
              description: l10n.premiumPlanLifetimeDesc,
              isHighlighted: true,
              onTap: () {
                // TODO(monowarmini): Start IAP flow.
              },
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () {
                // TODO(monowarmini): Restore purchases.
              },
              child: Text(l10n.premiumRestorePurchase),
            ),
            const SizedBox(height: 16),
            _LegalLinks(l10n: l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList(AppLocalizations l10n, ThemeData theme) {
    final features = [
      l10n.premiumFeatureThemes,
      l10n.premiumFeatureModules,
      l10n.premiumFeatureExport,
      l10n.premiumFeatureStats,
      l10n.premiumFeatureSupport,
    ];

    return Column(
      children: features
          .map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(f)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.title,
    required this.price,
    required this.description,
    required this.onTap,
    this.isHighlighted = false,
  });

  final String title;
  final String price;
  final String description;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

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
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isHighlighted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.premiumBestValue,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                price,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
  const _LegalLinks({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          l10n.premiumSyncExclusionNote,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Terms of Service',
              style: TextStyle(
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
            SizedBox(width: 16),
            Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

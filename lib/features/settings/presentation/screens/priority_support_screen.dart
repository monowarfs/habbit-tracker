import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:habit_tracker/core/premium/premium_status.dart';
import 'package:habit_tracker/features/settings/priority_support_links.dart';
import 'package:url_launcher/url_launcher.dart';

/// Priority Support channel screen
/// (`docs/superpowers/specs/04-premium/09-priority-community-support-
/// channel-design.md`) — gated behind [isPremiumUserProvider].
class PrioritySupportScreen extends ConsumerWidget {
  /// Creates the priority support screen.
  const PrioritySupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = ref.watch(isPremiumUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.prioritySupportTitle)),
      body: isPremium ? _Content(l10n: l10n) : _PremiumRequiredView(l10n: l10n),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.l10n});

  final AppLocalizations l10n;

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: PrioritySupportLinks.priorityEmail),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.prioritySupportEmailCopied)));
  }

  Future<void> _openMailApp(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: PrioritySupportLinks.priorityEmail,
    );
    await _launch(context, uri, PrioritySupportLinks.priorityEmail);
  }

  Future<void> _joinTelegram(BuildContext context) async {
    final uri = Uri.parse(PrioritySupportLinks.telegramUrl);
    await _launch(context, uri, PrioritySupportLinks.telegramUrlDisplay);
  }

  Future<void> _launch(
    BuildContext context,
    Uri uri,
    String displayValue,
  ) async {
    var launched = false;
    try {
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on Object {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.prioritySupportLinkFailed(displayValue))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.prioritySupportThankYou),
        const SizedBox(height: 24),
        Text(
          l10n.prioritySupportEmailSectionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const SelectableText(PrioritySupportLinks.priorityEmail),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _copyEmail(context),
              icon: const Icon(Icons.copy_outlined),
              label: Text(l10n.prioritySupportCopyEmail),
            ),
            FilledButton.icon(
              onPressed: () => _openMailApp(context),
              icon: const Icon(Icons.mail_outline),
              label: Text(l10n.prioritySupportOpenMailApp),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.prioritySupportReceiptGuidance,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.prioritySupportTelegramSectionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _joinTelegram(context),
          icon: const Icon(Icons.forum_outlined),
          label: Text(l10n.prioritySupportJoinGroup),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          l10n.prioritySupportGeneralSectionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.prioritySupportGeneralDescription(
            PrioritySupportLinks.generalEmail,
          ),
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
              l10n.prioritySupportPremiumRequired,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              // TODO(spec-07): navigate to the real purchase screen once
              // docs/superpowers/specs/04-premium/
              // 07-lifetime-unlock-pricing-tier-IMPLEMENTATION-PLAN.md
              // ships it.
              onPressed: () {},
              child: Text(l10n.prioritySupportUnlockPremium),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:habit_tracker/core/changelog/changelog_data.dart';
import 'package:habit_tracker/core/changelog/presentation/whats_new_sheet.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Version, open-source licenses (Flutter's built-in `LicenseRegistry`
/// auto-collects from bundled packages' `LICENSE` files, no manual
/// registration needed), and a static offline-first privacy policy.
class AboutScreen extends StatelessWidget {
  /// Creates the About screen.
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAbout)),
      body: ListView(
        children: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '';
              return ListTile(title: Text(l10n.aboutVersion(version)));
            },
          ),
          ListTile(
            title: Text(l10n.aboutLicenses),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(context: context),
          ),
          ListTile(
            title: Text(l10n.aboutWhatsNew),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showWhatsNewSheet(context, kChangelogEntries),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aboutPrivacyPolicy,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(l10n.aboutPrivacyPolicyBody),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

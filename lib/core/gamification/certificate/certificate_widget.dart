import 'package:flutter/material.dart';
import 'package:habit_tracker/core/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// A clean, dignified 1080x1080 certificate image for a big streak
/// milestone (`target >= 30`), rendered off-screen and captured by
/// `core/widgets/image_renderer.dart` (`docs/superpowers/specs/
/// 06-gamification/07-milestone-certificate-image-design.md`). A plain
/// previewable `Widget` — capture plumbing lives separately, same split
/// as `MonthlyRecapCard`/`RecapCardCapture`.
///
/// [l10n] is a constructor field rather than read via
/// `AppLocalizations.of(context)` — `CertificateGenerator` already
/// resolves it once for the whole generate call, and threading it
/// explicitly keeps this widget capturable (and testable) without
/// depending on a `Localizations` ancestor.
class CertificateWidget extends StatelessWidget {
  /// Creates the certificate widget.
  const CertificateWidget({
    required this.moduleName,
    required this.streakDays,
    required this.date,
    required this.accentColor,
    required this.l10n,
    this.userName,
    super.key,
  });

  /// The module's localized display name (e.g. "Water").
  final String moduleName;

  /// The streak length being certified.
  final int streakDays;

  /// The date the milestone was achieved.
  final DateTime date;

  /// The module's accent color, used as the certificate's gradient accent.
  final Color accentColor;

  /// Localized strings for the certificate's fixed copy.
  final AppLocalizations l10n;

  /// Optional user display name, shown under the date if provided.
  final String? userName;

  static const _size = 1080.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accentColor.withValues(alpha: 0.15), Colors.white],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTitle(context),
          const SizedBox(height: 24),
          _buildStreakText(context),
          const SizedBox(height: 16),
          _buildModuleName(context),
          const SizedBox(height: 16),
          _buildDate(context),
          _buildUserName(context),
          const SizedBox(height: 80),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80),
      child: Column(
        children: [
          Icon(Icons.emoji_events, color: accentColor, size: 96),
          const SizedBox(height: 24),
          Text(
            l10n.certificateTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakText(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80),
      child: Text(
        l10n.certificateDayStreak(streakDays),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.bold,
          color: accentColor,
        ),
      ),
    );
  }

  Widget _buildModuleName(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80),
      child: Text(
        l10n.certificateModuleName(moduleName),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 36, color: Colors.black87),
      ),
    );
  }

  Widget _buildDate(BuildContext context) {
    final formatted = DateFormat.yMMMd(l10n.localeName).format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80),
      child: Text(
        l10n.certificateDate(formatted),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, color: Colors.black54),
      ),
    );
  }

  Widget _buildUserName(BuildContext context) {
    final name = userName;
    if (name == null || name.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        name,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, color: Colors.black54),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Text(
      l10n.certificateFooter,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 20, color: Colors.black38),
    );
  }
}

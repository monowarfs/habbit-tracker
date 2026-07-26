/// Contact details for the Priority Support channel
/// (`docs/superpowers/specs/04-premium/09-priority-community-support-
/// channel-design.md`) — update these constants when they change.
class PrioritySupportLinks {
  /// Priority (premium) support email address.
  static const priorityEmail = 'priority@shurjomoy.dev';

  /// General (non-premium) support email address, shown for comparison.
  static const generalEmail = 'support@shurjomoy.dev';

  /// Priority-supporter Telegram group URL.
  static const telegramUrl = 'https://t.me/habittracker_priority';

  /// Raw Telegram URL to display if launch fails (without protocol prefix).
  static String get telegramUrlDisplay =>
      telegramUrl.replaceFirst('https://', '');
}

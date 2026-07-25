/// External community links for the Community feature.
///
/// Update these constants when URLs change.
class CommunityLinks {
  /// Telegram community channel URL.
  static const communityUrl = 'https://t.me/habittracker_community';

  /// Raw URL to display if launch fails (without protocol prefix).
  static String get communityUrlDisplay =>
      communityUrl.replaceFirst('https://', '');
}

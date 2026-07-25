/// External community links for the Community feature.
///
/// Update these constants when URLs change.
class CommunityLinks {
  /// Telegram community channel URL.
  static const communityUrl = 'https://t.me/habittracker_community';

  /// Feedback/feature-request board URL (Canny or equivalent).
  static const feedbackUrl = 'https://habittracker.canny.io/feature-requests';

  /// Raw URL to display if launch fails (without protocol prefix).
  static String get communityUrlDisplay =>
      communityUrl.replaceFirst('https://', '');

  /// Raw feedback URL to display if launch fails.
  static String get feedbackUrlDisplay =>
      feedbackUrl.replaceFirst('https://', '');
}

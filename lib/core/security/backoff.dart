import 'dart:math';

/// The lockout backoff delay after [consecutiveFailedAttempts] wrong PIN
/// entries (`strategies/security.md`'s table): none for 1-3, 5s at 4,
/// 30s at 5, doubling each additional attempt from there, capped at 5
/// minutes.
Duration calculateBackoffDelay(int consecutiveFailedAttempts) {
  if (consecutiveFailedAttempts <= 3) return Duration.zero;
  if (consecutiveFailedAttempts == 4) return const Duration(seconds: 5);
  if (consecutiveFailedAttempts == 5) return const Duration(seconds: 30);
  final doublings = consecutiveFailedAttempts - 5;
  final seconds = 30 * pow(2, doublings).toInt();
  return Duration(seconds: min(seconds, 300));
}

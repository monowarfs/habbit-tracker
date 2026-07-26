import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// The OAuth 2.0 client id from the Google Cloud Console, required on
/// iOS/macOS (Android resolves it from `google-services.json` plus the
/// registered SHA-1 fingerprints instead). Passed at build time via
/// `--dart-define=DRIVE_OAUTH_CLIENT_ID=...` once that GCP project
/// exists — empty until then, so sign-in fails with a clear platform
/// config error rather than silently misbehaving. The rest of the
/// backup pipeline is fully wired against this service regardless.
const driveOAuthClientId = String.fromEnvironment('DRIVE_OAUTH_CLIENT_ID');

/// Wraps `google_sign_in` for the Drive `appdata` scope — the only scope
/// this app ever requests, since backups live in the hidden per-app
/// folder, never the user's visible Drive.
///
/// No access/refresh token is stored directly: `google_sign_in` manages
/// and refreshes those itself. This service only persists a marker
/// (the connected account's email) so [isDriveConnected] is a fast local
/// check, and re-derives a fresh authorization header from
/// [authorizedHttpClient] on demand.
class DriveAuthService {
  /// Creates a service backed by [storage] (a real [FlutterSecureStorage]
  /// by default, overridable for tests).
  DriveAuthService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _driveScope = 'https://www.googleapis.com/auth/drive.appdata';
  static const _connectedAccountKey = 'drive_connected_account_email';

  // `GoogleSignIn.instance` is itself a process-wide singleton whose own
  // docs say `initialize()` must run exactly once — this guard must be
  // shared across every `DriveAuthService` instance (e.g. a fresh one is
  // constructed each time `BackupSettingsScreen` remounts), not per
  // instance, and memoizing the `Future` itself (not just a `bool`) also
  // keeps two near-simultaneous calls from both racing into `initialize`.
  static Future<void>? _initializeFuture;

  Future<void> _ensureInitialized() {
    return _initializeFuture ??= GoogleSignIn.instance.initialize(
      clientId: driveOAuthClientId.isEmpty ? null : driveOAuthClientId,
    );
  }

  /// Initiates interactive Google Sign-In and requests the Drive
  /// `appdata` scope. Must be called from a user-interaction handler
  /// (e.g. a button's `onPressed`).
  Future<void> connectDrive() async {
    await _ensureInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    await account.authorizationClient.authorizeScopes([_driveScope]);
    await _storage.write(key: _connectedAccountKey, value: account.email);
  }

  /// Revokes Drive access and clears the local connection marker. Local
  /// app data is never touched by this.
  Future<void> disconnectDrive() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.disconnect();
    await _storage.delete(key: _connectedAccountKey);
  }

  /// Whether a Drive account is currently connected (a local check —
  /// does not itself verify the session is still valid with Google).
  Future<bool> isDriveConnected() async {
    return await _storage.read(key: _connectedAccountKey) != null;
  }

  /// An authenticated [http.Client] for the Drive API, silently
  /// restoring the sign-in session and refreshing the authorization
  /// token as needed. Throws [StateError] if Drive isn't connected or
  /// the session can no longer be restored (the caller should treat
  /// that as "reconnect required").
  Future<http.Client> authorizedHttpClient() async {
    await _ensureInitialized();
    if (!await isDriveConnected()) {
      throw StateError('Google Drive is not connected');
    }
    final future = GoogleSignIn.instance.attemptLightweightAuthentication();
    final account = future == null ? null : await future;
    if (account == null) {
      throw StateError('Google Drive session expired — reconnect required');
    }
    final headers = await account.authorizationClient.authorizationHeaders([
      _driveScope,
    ], promptIfNecessary: true);
    if (headers == null) {
      throw StateError('Google Drive authorization was not granted');
    }
    return _BearerTokenClient(headers);
  }
}

class _BearerTokenClient extends http.BaseClient {
  _BearerTokenClient(this._headers);

  final Map<String, String> _headers;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

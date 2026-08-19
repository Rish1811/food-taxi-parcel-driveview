import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted storage for the JWT pair.
///
/// Tokens are a security boundary — they live in Keychain / EncryptedSharedPrefs,
/// never in SharedPreferences alongside app settings. [clear] is what "log out
/// securely" means; app preferences stored elsewhere survive it.
class TokenStorage {
  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';

  final FlutterSecureStorage _storage;

  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  /// Cached in memory so the auth interceptor doesn't hit the keychain on
  /// every single request.
  String? _accessToken;
  String? _refreshToken;
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _accessToken = await _storage.read(key: _accessKey);
    _refreshToken = await _storage.read(key: _refreshKey);
    _loaded = true;
  }

  Future<String?> get accessToken async {
    await _ensureLoaded();
    return _accessToken;
  }

  Future<String?> get refreshToken async {
    await _ensureLoaded();
    return _refreshToken;
  }

  Future<bool> get hasSession async => (await accessToken)?.isNotEmpty ?? false;

  /// Stores an access token on its own, leaving any existing refresh token
  /// untouched.
  ///
  /// The ride-side OTP endpoints return a bare `token` rather than the
  /// access/refresh pair the food endpoints issue. Until k9's unified auth is
  /// the only login path, both shapes have to be storable — and blanking the
  /// refresh token here would silently downgrade a session to non-refreshable.
  Future<void> saveAccessToken(String accessToken) async {
    await _ensureLoaded();
    _accessToken = accessToken;
    await _storage.write(key: _accessKey, value: accessToken);
  }

  Future<void> save({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _loaded = true;
    await Future.wait([
      _storage.write(key: _accessKey, value: accessToken),
      _storage.write(key: _refreshKey, value: refreshToken),
    ]);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _loaded = true;
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
    ]);
  }
}

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:superapp_user/core/config/api_config.dart';
import 'package:superapp_user/core/error/failures.dart';
import 'package:superapp_user/core/storage/token_storage.dart';

/// The single Dio instance for the whole app.
///
/// Responsibilities, all in one place so no call site repeats them:
///  * base URL + timeouts
///  * attach `Authorization: Bearer <token>`
///  * unwrap the `{ success, message, data }` envelope so models parse `data`
///    directly and never see `success` / `message`
///  * on 401, refresh the token **once** (single-flight) and replay the request;
///    if refresh fails, clear the session and notify the app
///  * map every transport/HTTP error onto a typed [Failure]
class ApiClient {
  final Dio _dio;
  final TokenStorage _tokens;

  /// Invoked when the session is unrecoverable (refresh failed / no refresh
  /// token). The auth layer listens to this to drop the user to guest mode.
  final void Function()? onSessionExpired;

  /// Guards against N concurrent 401s firing N refresh calls.
  Future<bool>? _refreshInFlight;

  /// In-memory GET cache. Opt in per call via [get]'s `cacheTtl`; feeds an
  /// instant paint via `onCache` and stands in for the network when offline.
  final _CacheInterceptor _cacheInterceptor = _CacheInterceptor();

  ApiClient({
    required TokenStorage tokens,
    this.onSessionExpired,
    Dio? dio,
  })  : _tokens = tokens,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = ApiConfig.baseUrl
      ..connectTimeout = ApiConfig.connectTimeout
      ..receiveTimeout = ApiConfig.receiveTimeout
      ..headers = {'Content-Type': 'application/json', 'Accept': 'application/json'}
      // We handle non-2xx ourselves so the envelope's `message` survives.
      ..validateStatus = (s) => s != null && s < 500;

    _dio.interceptors.addAll([
      _cacheInterceptor,
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    ]);
  }

  Dio get raw => _dio;

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['skipAuth'] != true) {
      final token = await _tokens.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    _log('→ ${options.method} ${options.path}');
    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    _log('← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  void _onError(DioException e, ErrorInterceptorHandler handler) {
    _log('✗ ${e.requestOptions.path} — ${e.type} ${e.message}');
    handler.next(e);
  }

  void _log(String msg) {
    if (kDebugMode) developer.log(msg, name: 'API');
  }

  // ---------------------------------------------------------------- verbs

  /// [onCache] fires synchronously — before this returns — with whatever's
  /// still cached for this request, so a caller can paint that immediately
  /// while the real response is in flight. The future always resolves with
  /// the network result; if the network is unreachable, the cache interceptor
  /// stands in and it resolves with the last-known-good copy instead.
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
    Duration? cacheTtl,
    void Function(T cached)? onCache,
  }) {
    if (onCache != null) {
      final cached = _cacheInterceptor.peek<T>(path, _clean(query));
      if (cached != null) onCache(cached);
    }
    return _send<T>(() => _dio.get(path, queryParameters: _clean(query), options: _opts(auth, cacheTtl: cacheTtl)));
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = true,
  }) =>
      _send<T>(() => _dio.post(path, data: body, queryParameters: _clean(query), options: _opts(auth)));

  Future<T> patch<T>(String path, {Object? body, bool auth = true}) =>
      _send<T>(() => _dio.patch(path, data: body, options: _opts(auth)));

  Future<T> put<T>(String path, {Object? body, bool auth = true}) =>
      _send<T>(() => _dio.put(path, data: body, options: _opts(auth)));

  Future<T> delete<T>(String path, {Object? body, bool auth = true}) =>
      _send<T>(() => _dio.delete(path, data: body, options: _opts(auth)));

  Options _opts(bool auth, {Duration? cacheTtl}) =>
      Options(extra: {'skipAuth': !auth, 'cacheTtl': ?cacheTtl});

  /// Drops null-valued query params so we never send `?city=null`.
  Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v != null) out[k] = v;
    });
    return out.isEmpty ? null : out;
  }

  // ------------------------------------------------------------ execution

  Future<T> _send<T>(Future<Response> Function() call, {bool didRetry = false}) async {
    try {
      final response = await call();
      final status = response.statusCode ?? 0;

      if (status == 401 && !didRetry) {
        final refreshed = await _refreshOnce();
        if (refreshed) return _send<T>(call, didRetry: true);
        onSessionExpired?.call();
        throw AuthFailure(_messageOf(response) ?? 'Session expired. Please log in again.');
      }

      if (status >= 200 && status < 300) return _unwrap<T>(response);

      throw _failureFor(status, _messageOf(response), response.data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Unwraps `{ success, message, data }`. Bodies that aren't enveloped
  /// (e.g. `/health`) pass through untouched.
  T _unwrap<T>(Response response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      if (body['success'] == false) {
        throw _failureFor(response.statusCode ?? 0, _messageOf(response), body);
      }
      if (body.containsKey('data')) return body['data'] as T;
    }
    return body as T;
  }

  /// The API is inconsistent about where the human-readable reason lives:
  /// success/auth envelopes use `message`, validation rejections use `error`
  /// (e.g. "OTP must be exactly 4 digits"). Read both or you lose the useful half.
  String? _messageOf(Response response) {
    final body = response.data;
    if (body is! Map) return null;
    for (final key in const ['message', 'error']) {
      final value = body[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  Failure _failureFor(int status, String? message, dynamic body) {
    switch (status) {
      case 400:
      case 422:
        return ValidationFailure(message ?? 'Please check the details and try again.', _fieldErrors(body));
      case 401:
      case 403:
        return AuthFailure(message ?? 'Session expired. Please log in again.');
      case 404:
        return NotFoundFailure(message ?? 'Not found.');
      case 429:
        return RateLimitFailure(message ?? 'Too many attempts. Please wait and try again.');
      default:
        return ServerFailure(message ?? 'Something went wrong. Please try again.', status);
    }
  }

  /// Best-effort extraction of `errors: [{ path/field, msg/message }]`,
  /// which is what express-validator emits.
  Map<String, String> _fieldErrors(dynamic body) {
    if (body is! Map) return const {};
    final errors = body['errors'];
    if (errors is! List) return const {};
    final out = <String, String>{};
    for (final e in errors) {
      if (e is Map) {
        final key = (e['path'] ?? e['param'] ?? e['field'])?.toString();
        final msg = (e['msg'] ?? e['message'])?.toString();
        if (key != null && msg != null) out[key] = msg;
      }
    }
    return out;
  }

  Failure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutFailure();
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badCertificate:
        return const NetworkFailure('Secure connection failed.');
      case DioExceptionType.cancel:
        return const ServerFailure('Request cancelled.');
      case DioExceptionType.badResponse:
        final r = e.response;
        return _failureFor(r?.statusCode ?? 0, _messageOf(r ?? Response(requestOptions: e.requestOptions)), r?.data);
      default:
        return e.error is Failure ? e.error as Failure : const NetworkFailure();
    }
  }

  // -------------------------------------------------------------- refresh

  /// Single-flight refresh: concurrent 401s all await the same call.
  Future<bool> _refreshOnce() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = await _tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _dio.post(
        ApiPaths.refreshToken,
        data: {'refreshToken': refresh},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = res.data is Map ? res.data['data'] : null;
      final access = data is Map ? data['accessToken'] as String? : null;
      final newRefresh = data is Map ? data['refreshToken'] as String? : null;
      if (access == null || access.isEmpty) return false;
      await _tokens.save(accessToken: access, refreshToken: newRefresh ?? refresh);
      _log('token refreshed');
      return true;
    } catch (_) {
      await _tokens.clear();
      return false;
    }
  }
}

/// Caches successful GET responses in memory, backed by [SharedPreferences]
/// so a kill-and-relaunch doesn't lose them (opt in via `cacheTtl` in
/// [ApiClient.get]). Never short-circuits the network — a request always
/// goes out — but offers two ways to fall back on the cached copy:
///  * [peek] — a synchronous read a caller can use to paint a screen
///    immediately, before the live response lands.
///  * [onError] — if the request itself fails (no connection, timeout,
///    server down), resolve with whatever's cached instead of erroring, no
///    matter its age. Something on screen beats a failure toast.
class _CacheInterceptor extends Interceptor {
  static const _prefsKey = 'http_cache_v1';

  final Map<String, _CacheEntry> _cache = {};

  _CacheInterceptor() {
    _hydrate();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      (jsonDecode(raw) as Map<String, dynamic>).forEach((key, value) {
        final entry = value as Map<String, dynamic>;
        _cache[key] = _CacheEntry(entry['data'], DateTime.parse(entry['expiresAt'] as String));
      });
    } catch (_) {
      // Corrupt or old-shape cache — start fresh rather than crash on it.
    }
  }

  /// A still-fresh cached value, or null if nothing usable is cached.
  T? peek<T>(String path, Map<String, dynamic>? query) {
    final hit = _cache[_keyFor(path, query)];
    if (hit == null || hit.expiresAt.isBefore(DateTime.now())) return null;
    return hit.data as T;
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final ttl = response.requestOptions.extra['cacheTtl'] as Duration?;
    final status = response.statusCode ?? 0;
    if (ttl != null && status >= 200 && status < 300) {
      final key = _keyFor(response.requestOptions.path, response.requestOptions.queryParameters);
      _cache[key] = _CacheEntry(response.data, DateTime.now().add(ttl));
      _persist();
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.extra['cacheTtl'] != null) {
      final hit = _cache[_keyFor(err.requestOptions.path, err.requestOptions.queryParameters)];
      if (hit != null) {
        handler.resolve(Response(requestOptions: err.requestOptions, data: hit.data, statusCode: 200));
        return;
      }
    }
    handler.next(err);
  }

  /// Fire-and-forget: writes the whole cache back as one blob. Cheap enough
  /// at this cache's size (a handful of discovery endpoints) to redo in full
  /// on every write rather than track per-key dirtiness.
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _cache.map((k, v) => MapEntry(k, {'data': v.data, 'expiresAt': v.expiresAt.toIso8601String()}));
    await prefs.setString(_prefsKey, jsonEncode(json));
  }

  String _keyFor(String path, Map<String, dynamic>? query) {
    final sorted = (query ?? const {}).entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return '$path?${sorted.map((e) => '${e.key}=${e.value}').join('&')}';
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiresAt;

  _CacheEntry(this.data, this.expiresAt);
}

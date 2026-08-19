import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../storage/token_storage.dart';
import 'api_endpoints.dart';
import 'auth_event_bus.dart';

/// Attaches the bearer access token to authenticated requests and
/// transparently refreshes it once on a 401 before retrying.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenStorage, required this.authEventBus})
    : _refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConstants.baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

  final TokenStorage tokenStorage;
  final AuthEventBus authEventBus;
  final Dio _refreshDio;

  static const _noAuthPaths = <String>[
    ApiEndpoints.requestOtp,
    ApiEndpoints.verifyOtp,
    ApiEndpoints.refreshToken,
    ApiEndpoints.register,
  ];

  Future<String?>? _refreshFuture;

  bool _isNoAuth(String path) =>
      _noAuthPaths.any((p) => path.contains(p)) ||
      path.contains('/check-vehicle/');

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isNoAuth(options.path)) {
      final token = await tokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final requestPath = err.requestOptions.path;

    if (statusCode == 401 && !_isNoAuth(requestPath)) {
      final newAccessToken = await _refreshAccessToken();
      if (newAccessToken != null) {
        try {
          final retryOptions = err.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await _refreshDio.fetch(retryOptions);
          return handler.resolve(retryResponse);
        } on DioException catch (retryError) {
          return handler.next(retryError);
        }
      }
      await tokenStorage.clear();
      authEventBus.emitForceLogout();
    }
    handler.next(err);
  }

  Future<String?> _refreshAccessToken() {
    return _refreshFuture ??= _doRefresh().whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await _refreshDio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      final newAccessToken = data?['accessToken'] as String?;
      final newRefreshToken =
          data?['refreshToken'] as String? ?? refreshToken;
      if (newAccessToken == null) return null;
      await tokenStorage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      return newAccessToken;
    } on DioException {
      return null;
    }
  }
}

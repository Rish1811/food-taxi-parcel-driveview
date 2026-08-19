import 'package:dio/dio.dart';

/// Retries a GET request exactly once on a transient network-level failure
/// (timeout or no connection) — never on responses the server actually sent,
/// so this can't accidentally double-submit a mutating request.
class RetryGetInterceptor extends Interceptor {
  static const _retriedKey = 'retried_after_transient_failure';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isTransient = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError;

    if (options.method == 'GET' &&
        isTransient &&
        options.extra[_retriedKey] != true) {
      options.extra[_retriedKey] = true;
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final response = await Dio().fetch(options);
        return handler.resolve(response);
      } on DioException catch (retryError) {
        return handler.next(retryError);
      }
    }
    handler.next(err);
  }
}

import 'package:superapp_user/core/error/failures.dart';
import 'package:dio/dio.dart';

class TaxiApiException implements Exception {
  final String message;
  final int? statusCode;
  final List<String>? errors;

  /// The typed failure this was converted from, when it came through
  /// [TaxiApiClient]. Lets a call site opt into precise handling
  /// (`if (e.failure is ValidationFailure) …`) without every site being
  /// migrated at once.
  final Failure? failure;

  TaxiApiException(this.message, {this.statusCode, this.errors, this.failure});

  factory TaxiApiException.fromDioError(DioException error) {
    final response = error.response;
    if (response != null && response.data is Map) {
      final data = response.data as Map;
      final message = data['message']?.toString();
      final errorsList = data['errors'];
      return TaxiApiException(
        message ?? _fallbackMessage(error),
        statusCode: response.statusCode,
        errors: errorsList is List
            ? errorsList.map((e) => e.toString()).toList()
            : null,
      );
    }
    return TaxiApiException(_fallbackMessage(error), statusCode: response?.statusCode);
  }

  static String _fallbackMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The connection timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'Unable to reach the server. Check your internet connection.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }

  @override
  String toString() => message;
}

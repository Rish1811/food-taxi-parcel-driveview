import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio);

  final Dio _dio;

  Future<Result<Map<String, dynamic>, AppError>> getInbox({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.notificationsInbox,
        queryParameters: {'page': page, 'limit': limit},
      );
      return Result.success(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<void, AppError>> markRead(String id) async {
    try {
      await _dio.patch(ApiEndpoints.notificationRead(id));
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<void, AppError>> delete(String id) async {
    try {
      await _dio.delete(ApiEndpoints.notificationDelete(id));
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<void, AppError>> deleteAll() async {
    try {
      await _dio.delete(ApiEndpoints.notificationsDeleteAll);
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<Map<String, dynamic>, AppError>> getReferralStats() async {
    try {
      final res = await _dio.get(ApiEndpoints.referralStats);
      return Result.success(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  AppError _mapError(DioException e) {
    final responseData = e.response?.data;
    final message = responseData is Map<String, dynamic>
        ? (responseData['message'] as String? ??
              responseData['error'] as String? ??
              e.message ??
              'Something went wrong')
        : (e.message ?? 'Something went wrong');
    return NetworkError(message);
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.read(dioProvider));
});
